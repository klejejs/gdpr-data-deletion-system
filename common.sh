export CHANNEL_NAME=mychannel
export GENERATED_DATA_DIR=base-data/generated
export FABRIC_CFG_PATH=base-data/channel-config

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=$GENERATED_DATA_DIR/ca/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

export PEER0_ORG1_CA=$GENERATED_DATA_DIR/ca/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export PEER0_ORG2_CA=$GENERATED_DATA_DIR/ca/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem

# Set environment variables for the peer org
setEnvVar() {
  if [ $1 -eq 1 ]; then
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=../../$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=../../base-data/generated/ca/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
  elif [ $1 -eq 2 ]; then
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=../../$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=../../base-data/generated/ca/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
  else
    echo "ORG Unknown"
    exit 1
  fi
}

# add bin to PATH
export PATH=${PWD}/bin:$PATH
