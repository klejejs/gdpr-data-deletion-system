set -e

# Import common variables and functions
source ./common.sh
export ORDERER_CA=../../docker/generated/ca/ordererOrganizations/lejejs.com/tlsca/tlsca.lejejs.com-cert.pem

echo "Deleting old files"
rm -rf $CHAINCODE_NAME.tar.gz
rm -rf chaincode/dist
rm -rf chaincode/node_modules

cd chaincode

# build the chaincode
echo "Building chaincode"

npm ci
npm run build

cd ..

# package the chaincode
echo "Packaging chaincode"
peer lifecycle chaincode package $CHAINCODE_NAME.tar.gz --path ./chaincode --lang node --label chaincode_v1.0

PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid $CHAINCODE_NAME.tar.gz)

# install the chaincode
echo "Installing chaincode"

setEnvVar 1
peer lifecycle chaincode install $CHAINCODE_NAME.tar.gz

setEnvVar 2
peer lifecycle chaincode install $CHAINCODE_NAME.tar.gz

setEnvVar 3
peer lifecycle chaincode install $CHAINCODE_NAME.tar.gz


# check if the chaincode is installed on all branches
echo "Checking if the chaincode is installed on all branches"

setEnvVar 1
peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$

setEnvVar 2
peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$

setEnvVar 3
peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$


# approve the chaincode for all branches
echo "Approving chaincode for all branches"

setEnvVar 1
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.lejejs.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version 1.0 --package-id $PACKAGE_ID --sequence 1

setEnvVar 2
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.lejejs.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version 1.0 --package-id $PACKAGE_ID --sequence 1

setEnvVar 3
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.lejejs.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version 1.0 --package-id $PACKAGE_ID --sequence 1


# commit the chaincode
echo "Committing the chaincode"
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.lejejs.com --tls --cafile "$ORDERER_CA" \
  --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version 1.0 --sequence 1 \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_BRANCH1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_BRANCH2_CA" \
  --peerAddresses localhost:11051 --tlsRootCertFiles "$PEER0_BRANCH3_CA"

# check if the chaincode is committed
echo "Checking if the chaincode is committed"

setEnvVar 1
peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name $CHAINCODE_NAME

setEnvVar 2
peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name $CHAINCODE_NAME

setEnvVar 3
peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name $CHAINCODE_NAME

# Initialize the chaincode
echo "Initializing the chaincode"

invokeChaincodeCommand 1 '{"function":"InitLedger","Args":[]}'

# Wait for chaincode to be initialized
sleep 2

# Make a query to check if the chaincode is initialized
echo "Querying all removals in the chaincode"
queryChaincodeCommand 1 '{"Args":["GetAllRemovals"]}'
