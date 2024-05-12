source ./common.sh
export ORDERER_CA=../../docker/generated/ca/ordererOrganizations/lejejs.com/tlsca/tlsca.lejejs.com-cert.pem

# Functions to test:
# - InitLedger (invoked already in deploy-chaincode.sh)
# - GetRemoval
# - GetAllRemovals
# - GetAllCompletedRemovals
# - RemovalExists
# - StartNewRemoval
# - SetRemovalAsDoneForBranch
# - DeleteRemoval
# - GetAllRemovalsInProgressForRemovalBranch
# - GetRemovalAuditHistory

# --------------------------------

# Test GetAllRemovals and make sure there is one removal in the result
echo "Testing GetAllRemovals"

result=$(queryChaincodeCommand 1 '{"function":"GetAllRemovals","Args":[]}')
if [ $(echo $result | jq -r '. | length') -ne 1 ]; then
  echo "GetAllRemovals should return 1 removal failed"
  exit 1
fi

removal_id=$(echo $result | jq -r '.[0].id')

# --------------------------------

# Test GetRemoval and make sure the removal exists
echo "Testing GetRemoval"

result=$(queryChaincodeCommand 1 '{"function":"GetRemoval","Args":["'$removal_id'"]}')
if [ $(echo $result | jq -r '.id') != "$removal_id" ]; then
  echo "GetRemoval should return the removal failed"
  exit 1
fi

# --------------------------------

# Test RemovalExists and make sure the removal exists
echo "Testing RemovalExists"

result=$(queryChaincodeCommand 1 '{"function":"RemovalExists","Args":["'$removal_id'"]}')
if [ $(echo $result | jq -r '.') != "true" ]; then
  echo "RemovalExists should exist failed"
  exit 1
fi

result=$(queryChaincodeCommand 1 '{"function":"RemovalExists","Args":["nonexistent"]}')
if [ $(echo $result | jq -r '.') != "false" ]; then
  echo "RemovalExists should not exist failed"
  exit 1
fi

# --------------------------------

# Test StartNewRemoval
echo "Testing StartNewRemoval"

invokeChaincodeCommand 1 '{"function":"StartNewRemoval","Args":["removal","id1,id2,id3"]}'
sleep 1
result=$(queryChaincodeCommand 1 '{"function":"GetAllRemovals","Args":[]}')
if [ $(echo $result | jq -r '. | length') -ne 2 ]; then
  echo "StartNewRemoval should add a new removal failed"
  exit 1
fi

removal_id_2=$(echo $result | jq -r '.[1].id')

invokeChaincodeCommand 2 '{"function":"StartNewRemoval","Args":["removal","id1,id2,id3"]}'
sleep 1
result=$(queryChaincodeCommand 1 '{"function":"GetAllRemovals","Args":[]}')
if [ $(echo $result | jq -r '. | length') -ne 2 ]; then
  echo "StartNewRemoval should not allow creation of a new removal by removal branch failed"
  exit 1
fi

# --------------------------------

# Test SetRemovalAsDoneForBranch
echo "Testing SetRemovalAsDoneForBranch"

invokeChaincodeCommand 2 '{"function":"SetRemovalAsDoneForBranch","Args":["'$removal_id_2'","true","Successful removal"]}'
sleep 1
result=$(queryChaincodeCommand 1 '{"function":"GetRemoval","Args":["'$removal_id_2'"]}')
if [ $(echo $result | jq -r '.branchStatuses.Branch2.status') != "COMPLETED" ]; then
  echo "SetRemovalAsDoneForBranch branch 2 should set the removal as done failed"
  exit 1
fi

invokeChaincodeCommand 3 '{"function":"SetRemovalAsDoneForBranch","Args":["'$removal_id_2'","true","Successful removal"]}'
sleep 1
result=$(queryChaincodeCommand 1 '{"function":"GetRemoval","Args":["'$removal_id_2'"]}')
if [ $(echo $result | jq -r '.branchStatuses.Branch3.status') != "COMPLETED" ]; then
  echo "SetRemovalAsDoneForBranch branch 3 should set the removal as done failed"
  exit 1
fi

if [ $(echo $result | jq -r '.overallStatus') != "COMPLETED" ]; then
  echo "SetRemovalAsDoneForBranch should set the overall removal as done after all branches have removed customer failed"
  exit 1
fi

# --------------------------------

# Test GetAllCompletedRemovals
echo "Testing GetAllCompletedRemovals"
result=$(queryChaincodeCommand 1 '{"function":"GetAllCompletedRemovals","Args":[]}')
if [ $(echo $result | jq -r '. | length') -ne 1 ]; then
  echo "GetAllCompletedRemovals should return 1 removal failed"
  exit 1
fi

# --------------------------------

# Test DeleteRemoval
echo "Testing DeleteRemoval"

invokeChaincodeCommand 2 '{"function":"DeleteRemoval","Args":["'$removal_id_2'"]}'
sleep 1
result=$(queryChaincodeCommand 1 '{"function":"GetAllRemovals","Args":[]}')
echo $result
if [ $(echo $result | jq -r '. | length') -ne 2 ]; then
  echo "DeleteRemoval should not allow deletion of a removal by removal branch failed"
  exit 1
fi

invokeChaincodeCommand 1 '{"function":"DeleteRemoval","Args":["'$removal_id'"]}'
sleep 1
result=$(queryChaincodeCommand 1 '{"function":"GetAllRemovals","Args":[]}')
if [ $(echo $result | jq -r '. | length') -ne 2 ]; then
  echo "DeleteRemoval should not allow deletion of an incomplete removal failed"
  exit 1
fi

invokeChaincodeCommand 1 '{"function":"DeleteRemoval","Args":["'$removal_id_2'"]}'
sleep 1
result=$(queryChaincodeCommand 1 '{"function":"GetAllRemovals","Args":[]}')
if [ $(echo $result | jq -r '. | length') -ne 1 ]; then
  echo "DeleteRemoval should delete the removal failed"
  exit 1
fi

# --------------------------------

# Test GetAllRemovalsInProgressForRemovalBranch
echo "Testing GetAllRemovalsInProgressForRemovalBranch"

result=$(queryChaincodeCommand 2 '{"function":"GetAllRemovalsInProgressForRemovalBranch","Args":[]}')
if [ $(echo $result | jq -r '. | length') -ne 1 ]; then
  echo "GetAllRemovalsInProgressForRemovalBranch should return 1 removal failed"
  exit 1
fi

# --------------------------------

# Test GetRemovalAuditHistory
echo "Testing GetRemovalAuditHistory"

result=$(queryChaincodeCommand 1 '{"function":"GetRemovalAuditHistory","Args":["'$removal_id'"]}')
if [ $(echo $result | jq -r '. | length') -eq 0 ]; then
  echo "GetRemovalAuditHistory should return a list of audit history failed"
  exit 1
fi

result=$(queryChaincodeCommand 1 '{"function":"GetRemovalAuditHistory","Args":["'$removal_id_2'"]}')
if [ $(echo $result | jq -r '. | length') -eq 0 ]; then
  echo "GetRemovalAuditHistory should return a list of audit history for deleted removal failed"
  exit 1
fi

result=$(queryChaincodeCommand 1 '{"function":"GetRemovalAuditHistory","Args":["nonexistent"]}')
if [ $(echo $result | jq -r '. | length') -ne 0 ]; then
  echo "GetRemovalAuditHistory should return an empty list for nonexistent removal failed"
  exit 1
fi

# --------------------------------

echo "All tests passed"
