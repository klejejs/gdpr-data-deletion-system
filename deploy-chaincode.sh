# Import common variables and functions
source ./common.sh
export ORDERER_CA=../../base-data/generated/ca/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

echo "Deleting old files"
rm -rf chaincode.tar.gz
rm -rf chaincode/dist
rm -rf chaincode/node_modules

cd chaincode

# build the chaincode
echo "Building chaincode"

npm install
npm run build

cd ..

# package the chaincode
echo "Packaging chaincode"
peer lifecycle chaincode package chaincode.tar.gz --path ./chaincode --lang node --label chaincode_v1.0

PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid chaincode.tar.gz)

# install the chaincode
echo "Installing chaincode"

setEnvVar 1
peer lifecycle chaincode install chaincode.tar.gz

setEnvVar 2
peer lifecycle chaincode install chaincode.tar.gz

# check if the chaincode is installed on both peers
echo "Checking if the chaincode is installed on both peers"

setEnvVar 1
peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$

setEnvVar 2
peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$

# approve the chaincode for both orgs
echo "Approving chaincode for both orgs"

setEnvVar 1
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name chaincode --version 1.0 --init-required --package-id $PACKAGE_ID --sequence 1

setEnvVar 2
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name chaincode --version 1.0 --init-required --package-id $PACKAGE_ID --sequence 1


# commit the chaincode
echo "Committing the chaincode"
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name chaincode --version 1.0 --sequence 1 --init-required --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_ORG1_CA" --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_ORG2_CA"

# check if the chaincode is committed
echo "Checking if the chaincode is committed"

setEnvVar 1
peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name chaincode

setEnvVar 2
peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name chaincode
