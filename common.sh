export CHANNEL_NAME=removalchannel
export CHAINCODE_NAME=chaincode

export GENERATED_DATA_DIR=docker/generated
export FABRIC_CFG_PATH=docker/channel-config

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=$GENERATED_DATA_DIR/ca/ordererOrganizations/lejejs.com/tlsca/tlsca.lejejs.com-cert.pem

export PEER0_BRANCH1_CA=$GENERATED_DATA_DIR/ca/peerOrganizations/branch1.lejejs.com/tlsca/tlsca.branch1.lejejs.com-cert.pem
export PEER0_BRANCH2_CA=$GENERATED_DATA_DIR/ca/peerOrganizations/branch2.lejejs.com/tlsca/tlsca.branch2.lejejs.com-cert.pem
export PEER0_BRANCH3_CA=$GENERATED_DATA_DIR/ca/peerOrganizations/branch3.lejejs.com/tlsca/tlsca.branch3.lejejs.com-cert.pem

# Set environment variables for the peer org
setEnvVar() {
  if [ $1 -eq 1 ]; then
    export CORE_PEER_LOCALMSPID=Branch1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=../../$PEER0_BRANCH1_CA
    export CORE_PEER_MSPCONFIGPATH=../../docker/generated/ca/peerOrganizations/branch1.lejejs.com/users/Admin@branch1.lejejs.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
  elif [ $1 -eq 2 ]; then
    export CORE_PEER_LOCALMSPID=Branch2MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=../../$PEER0_BRANCH2_CA
    export CORE_PEER_MSPCONFIGPATH=../../docker/generated/ca/peerOrganizations/branch2.lejejs.com/users/Admin@branch2.lejejs.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
  elif [ $1 -eq 3 ]; then
    export CORE_PEER_LOCALMSPID=Branch3MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=../../$PEER0_BRANCH3_CA
    export CORE_PEER_MSPCONFIGPATH=../../docker/generated/ca/peerOrganizations/branch3.lejejs.com/users/Admin@branch3.lejejs.com/msp
    export CORE_PEER_ADDRESS=localhost:11051
  else
    echo "Branch Unknown"
    exit 1
  fi
}

invokeChaincodeCommand() {
  setEnvVar $1
  peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.lejejs.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --waitForEvent \
    --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_BRANCH1_CA" \
    --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_BRANCH2_CA" \
    --peerAddresses localhost:11051 --tlsRootCertFiles "$PEER0_BRANCH3_CA" \
    -c "$2"
}

queryChaincodeCommand() {
  setEnvVar $1
  peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c "$2"
}

# add bin to PATH
export PATH=${PWD}/bin:$PATH
