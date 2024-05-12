# GDPR Data Deletion System

The GDPR Data Deletion System is a blockchain-based data removal system developed as part of the Master's thesis at the University of Latvia.

## Key Concepts

The system is designed to provide a secure and transparent way to manage data removal requests in compliance with the General Data Protection Regulation (GDPR). The system is built on top of the Hyperledger Fabric blockchain platform and consists of two main components - the Data Controller and the Data Remover. The Data Controller is responsible for creating new data removal requests, while the Data Remover is responsible for marking the removal requests as completed. The system is designed to be used by large organizations that need to manage data removal requests from their customers.

The system consists of 3 branches:
* Branch 1 (Data Controller)
* Branch 2 (Data Remover)
* Branch 3 (Data Remover)

Each branch has its own set of permissions and can only perform certain operations on the blockchain. 

## Installation

To install the system, install the prerequisites and follow the system installation steps below.

### Prerequisites

* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/)
* [Hyperledger Fabric Binaries](https://hyperledger-fabric.readthedocs.io/en/release-2.5/install.html)
* [Node.js v18.x](https://nodejs.org/en/download/)
* [jq](https://stedolan.github.io/jq/download/)

### System Installation Steps

1. Make sure that the prerequisites are installed and Hyperledger Fabric binaries are in the PATH.
2. Run `./deploy-network.sh` to deploy the removal system blockchain network.
3. Run `./deploy-chaincode.sh` to install the chaincode on the network.

## Interaction with the Blockchain

To interact with blockchain, get data from it and update it, Hyperledger Fabric `peer` CLI can be used.
To simplify the process, invocation and query functions can be used that are defined in the `common.sh` script.

Exmaple usage of invocation and query functions:
```
source common.sh

invokeChaincodeCommand 1 '{"function":"InitLedger","Args":[]}'

queryChaincodeCommand 2 '{"function":"GetAllRemovals","Args":[]}'
```

In the invocation, the first argument is the branch id (same is number in the branch name), the second argument is the JSON object with the function and arguments for the chaincode function. Below are the examples of the supported operations.

### Supported Operations by All Branches

* Get specific removal request by ID (query) - `GetRemoval`
```
{
  "function": "GetRemoval",
  "args": ["<removal_id>"]
}
```
* Get all removal requests (query) - `GetAllRemovals`
```
{
  "function": "GetAllRemovals",
  "args": []
}
```
* Get all completed removal requests (query) - `GetAllCompletedRemovals`
```
{
  "function": "GetAllCompletedRemovals",
  "args": []
}
```
* Check if a removal request exists (query) - `RemovalExists`
```
{
  "function": "RemovalExists",
  "args": ["<removal_id>"]
}
```
* Get full history of a removal request (query) - `GetRemovalAuditHistory`
```
{
  "function": "GetRemovalAuditHistory",
  "args": ["<removal_id>"]
}
```


### Supported Operations by Data Controller Branches (Branch 1)

* Initialize the ledger (invoke) - `InitLedger`
```
{
  "function": "InitLedger",
  "args": []
}
```
* Start a new removal request (invoke) - `StartNewRemoval`
```
{
  "function": "StartNewRemoval",
  "args": ["<removal_type (request/>retention)>", "<customer_ids_to_remove (list of strings sepatared by comma)>"]
}
```
* Detete a completed removal request (invoke) - `DeleteRemoval`
```
{
  "function": "DeleteRemoval",
  "args": ["<removal_id>"]
}
```


### Supported Operations by Data Remover Branches (Branch 2, Branch 3)

* Set removal as completed for branch (invoke) - `SetRemovalAsDoneForBranch`
```
{
  "function": "SetRemovalAsDoneForBranch",
  "args": ["<removal_id>", "<is_successful>", <comment>"]
}
```
* Get all removals in progress for branch (query) - `GetAllRemovalsInProgressForRemovalBranch`
```
{
  "function": "GetAllRemovalsInProgressForRemovalBranch",
  "args": []
}
```

## Testing

To test the system, E2E tests have been written in the `tests.sh` script. The tests cover all the supported operations and can be run by executing the script.
