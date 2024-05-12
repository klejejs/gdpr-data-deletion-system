set -e

# Import common variables and functions
source ./common.sh

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
  # Creating Branch1 Identities
  cryptogen generate --config=./docker/crypto-config/crypto-config-branch1.yaml --output=$GENERATED_DATA_DIR/ca

  # Creating Branch2 Identities
  cryptogen generate --config=./docker/crypto-config/crypto-config-branch2.yaml --output=$GENERATED_DATA_DIR/ca

  # Creating Branch3 Identities
  cryptogen generate --config=./docker/crypto-config/crypto-config-branch3.yaml --output=$GENERATED_DATA_DIR/ca

  # Creating Orderer Identities
  cryptogen generate --config=./docker/crypto-config/crypto-config-orderer.yaml --output=$GENERATED_DATA_DIR/ca
fi

echo "Starting the network"
docker compose up -d

# Create channel genesis block
echo "Creating channel genesis block"
setEnvVar 1
configtxgen -profile DefaultChannel -outputBlock $GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block -channelID $CHANNEL_NAME

# Create channel anchor peer update transactions
echo "Creating channel configuration transaction"
setEnvVar 1
configtxgen -profile DefaultChannel -outputAnchorPeersUpdate $GENERATED_DATA_DIR/channel-artifacts/Branch1anchors.tx -channelID $CHANNEL_NAME -asOrg Branch1

setEnvVar 2
configtxgen -profile DefaultChannel -outputAnchorPeersUpdate $GENERATED_DATA_DIR/channel-artifacts/Branch2anchors.tx -channelID $CHANNEL_NAME -asOrg Branch2

setEnvVar 3
configtxgen -profile DefaultChannel -outputAnchorPeersUpdate $GENERATED_DATA_DIR/channel-artifacts/Branch3anchors.tx -channelID $CHANNEL_NAME -asOrg Branch3

# Create channel
echo "Creating channel"
export ORDERER_ADMIN_TLS_SIGN_CERT=$GENERATED_DATA_DIR/ca/ordererOrganizations/lejejs.com/orderers/orderer.lejejs.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$GENERATED_DATA_DIR/ca/ordererOrganizations/lejejs.com/orderers/orderer.lejejs.com/tls/server.key

osnadmin channel join --channelID $CHANNEL_NAME --config-block $GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block -o localhost:7053 --ca-file $ORDERER_CA --client-cert $ORDERER_ADMIN_TLS_SIGN_CERT --client-key $ORDERER_ADMIN_TLS_PRIVATE_KEY

# Sleep for 2 seconds to wait for the channel to be created
sleep 2

# Join all the peers to the channel
echo "Joining branch1 peer to the channel"
setEnvVar 1
peer channel join -b ./$GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block

echo "Joining branch2 peer to the channel"
setEnvVar 2
peer channel join -b $GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block

echo "Joining branch3 peer to the channel"
setEnvVar 3
peer channel join -b $GENERATED_DATA_DIR/channel-artifacts/$CHANNEL_NAME.block
