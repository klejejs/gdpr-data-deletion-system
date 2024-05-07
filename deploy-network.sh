# Import common variables and functions
source ./common.sh

function one_line_pem {
  echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
  local PP=$(one_line_pem $4)
  local CP=$(one_line_pem $5)
  sed -e "s/\${ORG}/$1/" \
      -e "s/\${P0PORT}/$2/" \
      -e "s/\${CAPORT}/$3/" \
      -e "s#\${PEERPEM}#$PP#" \
      -e "s#\${CAPEM}#$CP#" \
      base-data/ccp-template.json
}

function generare_cpp {
  ORG=1
  P0PORT=7051
  CAPORT=7054
  PEERPEM=$GENERATED_DATA_DIR/ca/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
  CAPEM=$GENERATED_DATA_DIR/ca/peerOrganizations/org1.example.com/ca/ca.org1.example.com-cert.pem

  echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > $GENERATED_DATA_DIR/ca/peerOrganizations/org1.example.com/connection-org1.json

  ORG=2
  P0PORT=9051
  CAPORT=8054
  PEERPEM=$GENERATED_DATA_DIR/ca/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem
  CAPEM=$GENERATED_DATA_DIR/ca/peerOrganizations/org2.example.com/ca/ca.org2.example.com-cert.pem

  echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > $GENERATED_DATA_DIR/ca/peerOrganizations/org2.example.com/connection-org2.json
}

echo "Removing previous containers"
docker compose down

# Remove previous crypto material and config transactions
# rm -rf docker-data

# delete crypto data if it exists
if [ -d "$GENERATED_DATA_DIR/ca" ]; then
  echo "Removing previous crypto data"
  rm -Rf $GENERATED_DATA_DIR/ca
fi

# delete channel artifacts if it exists
if [ -d "$GENERATED_DATA_DIR/channel-artifacts" ]; then
  echo "Removing previous channel artifacts"
  rm -Rf $GENERATED_DATA_DIR/channel-artifacts
fi

# generate crypto data if it does not exist
if [ ! -d "$GENERATED_DATA_DIR/ca/peerOrganizations" ]; then
  echo "Generating crypto data"

  # Generating certificates using cryptogen tool
  # Creating Org1 Identities
  cryptogen generate --config=./base-data/crypto-config/crypto-config-org1.yaml --output=$GENERATED_DATA_DIR/ca

  # Creating Org2 Identities
  cryptogen generate --config=./base-data/crypto-config/crypto-config-org2.yaml --output=$GENERATED_DATA_DIR/ca

  # Creating Orderer Org Identities
  cryptogen generate --config=./base-data/crypto-config/crypto-config-orderer.yaml --output=$GENERATED_DATA_DIR/ca

  # Generating CCP files for Org1 and Org2
  generare_cpp
fi

echo "Starting the network"
docker compose up -d

# Create channel genesis block
echo "Creating channel genesis block"
setEnvVar 1
configtxgen -profile ChannelUsingRaft -outputBlock $GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block -channelID $CHANNEL_NAME

# Create channel anchor peer update transactions
echo "Creating channel configuration transaction"
setEnvVar 1
configtxgen -profile ChannelUsingRaft -outputAnchorPeersUpdate $GENERATED_DATA_DIR/channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

setEnvVar 2
configtxgen -profile ChannelUsingRaft -outputAnchorPeersUpdate $GENERATED_DATA_DIR/channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP

# Create channel
echo "Creating channel"
export ORDERER_ADMIN_TLS_SIGN_CERT=$GENERATED_DATA_DIR/ca/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$GENERATED_DATA_DIR/ca/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

osnadmin channel join --channelID $CHANNEL_NAME --config-block $GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block -o localhost:7053 --ca-file $ORDERER_CA --client-cert $ORDERER_ADMIN_TLS_SIGN_CERT --client-key $ORDERER_ADMIN_TLS_PRIVATE_KEY

sleep 2

# Join all the peers to the channel
echo "Joining org1 peer to the channel"
setEnvVar 1
peer channel join -b ./$GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block

echo "Joining org2 peer to the channel"
setEnvVar 2
peer channel join -b $GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block

export ORDERER_CA=../generated/ca/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

# # Set the anchor peers for each org in the channel
# echo "Setting org1 anchor peers"
# setEnvVar 1
# peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f $GENERATED_DATA_DIR/channel-artifacts/Org1MSPanchors.tx --tls --cafile $ORDERER_CA

# echo "Setting org2 anchor peers"
# setEnvVar 2
# peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f $GENERATED_DATA_DIR/channel-artifacts/Org2MSPanchors.tx --tls --cafile $ORDERER_CA
