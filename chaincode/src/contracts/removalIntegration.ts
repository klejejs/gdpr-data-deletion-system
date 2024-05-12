import crypto from 'crypto';
import { Context, Contract, Info, Returns, Transaction } from 'fabric-contract-api';
import stringify from 'json-stringify-deterministic';
import sortKeysRecursive from 'sort-keys-recursive';
import {
  ActiveRemovalBranches,
  ActiveRequestBranches,
  BranchStatus,
  ComplexRemoval,
  RemovalStatus,
  RemovalType,
  toComplexRemoval,
  toSimpleRemoval,
} from '../types/removal';

const getCurrentDate = (ctx: Context): Date => {
  const timestamp = ctx.stub.getTxTimestamp().seconds.low * 1000;
  return new Date(timestamp);
}

const isRemovalFullyCompleted = (removal: ComplexRemoval): boolean =>
  Object.values(removal.branchStatuses).every(({ status }) => status !== RemovalStatus.IN_PROGRESS);

const isRemovalSuccessful = (removal: ComplexRemoval): boolean =>
  Object.values(removal.branchStatuses).every(({ status }) => status === RemovalStatus.COMPLETED);

const getNewDeterministicRemovalId = (ctx: Context, customerIdsToRemove: string[]): string => {
  const transactionTimestamp = ctx.stub.getTxTimestamp();
  const transactionId = ctx.stub.getTxID();
  const transactionCreator = ctx.clientIdentity.getID();
  const customerIds = customerIdsToRemove.sort().join('');

  const data = `${transactionTimestamp.seconds}-${transactionId}-${transactionCreator}-${customerIds}`;

  const hash = crypto.createHash('sha256');
  hash.update(data);
  return hash.digest('hex');
}

const createNewRemoval = (ctx: Context, removalType: RemovalType, customerIdsToRemove: string[]): ComplexRemoval => ({
  id: getNewDeterministicRemovalId(ctx, customerIdsToRemove),
  startDate: getCurrentDate(ctx),
  lastUpdatedDate: getCurrentDate(ctx),
  type: removalType,
  overallStatus: RemovalStatus.IN_PROGRESS,
  customerIds: customerIdsToRemove,
  branchStatuses: Object.keys(ActiveRemovalBranches)
    .reduce((acc, branch) => {
      acc[branch] = {
        status: RemovalStatus.IN_PROGRESS,
        comment: '',
      };
      return acc;
    }, {} as Record<string, BranchStatus>),
});

@Info({ title: 'RemovalIntegration', description: 'Smart contract for managing removals in a removals company' })
export class RemovalIntegrationContract extends Contract {

  // initialize the ledger with some demo removals, should be removed in production
  // in test version, only branches in ActiveRequestBranches can initialize the ledger
  @Transaction()
  public async InitLedger(ctx: Context): Promise<void> {
    // check if the branch is allowed to initialize the ledger
    this.getRequestClientId(ctx);

    const demoRemovals: ComplexRemoval[] = [
      createNewRemoval(ctx, RemovalType.REQUEST, ['customerId1', 'customerId2', 'customerId3']),
    ];

    for (const removal of demoRemovals) {
      await this.putState(ctx, removal);
    }
  }

  @Transaction(false)
  @Returns('object')
  public async GetRemoval(ctx: Context, id: string): Promise<ComplexRemoval> {
    const removalJSON = await ctx.stub.getState(id);
    if (!removalJSON || removalJSON.length === 0) {
      throw new Error(`The removal ${id} does not exist`);
    }
    return toComplexRemoval(JSON.parse(removalJSON.toString()));
  }

  // get all removals
  @Transaction(false)
  @Returns('object[]')
  public async GetAllRemovals(ctx: Context): Promise<ComplexRemoval[]> {
    const allRemovals = [];
    const iterator = await ctx.stub.getStateByRange('', '');
    let result = await iterator.next();
    while (!result.done) {
      const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
      let record;
      try {
        record = JSON.parse(strValue);
      } catch (err) {
        console.log(err);
        record = null;
      }

      if (record) {
        allRemovals.push(toComplexRemoval(record));
      }

      result = await iterator.next();
    }
    return allRemovals;
  }

  // get all completed removals
  @Transaction(false)
  @Returns('object[]')
  public async GetAllCompletedRemovals(ctx: Context): Promise<ComplexRemoval[]> {
    const allCompletedRemovals = [];
    const iterator = await ctx.stub.getStateByRange('', '');
    let result = await iterator.next();
    while (!result.done) {
      const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
      let record;
      try {
        record = JSON.parse(strValue);
      } catch (err) {
        console.log(err);
        record = null;
      }

      if (record) {
        const complexRemoval = toComplexRemoval(record);
        if (complexRemoval.overallStatus === RemovalStatus.COMPLETED) {
          allCompletedRemovals.push(complexRemoval);
        }
      }

      result = await iterator.next();
    }
    return allCompletedRemovals;
  }

  // check if removal exists
  @Transaction(false)
  @Returns('boolean')
  public async RemovalExists(ctx: Context, id: string): Promise<boolean> {
    const removalJSON = await ctx.stub.getState(id);
    return removalJSON && removalJSON.length > 0;
  }

  // start a new removal
  // only branches in ActiveRequestBranches can start a new removal
  @Transaction()
  public async StartNewRemoval(ctx: Context, removalType: RemovalType, customerIdsToRemove: string): Promise<void> {
    // check if the branch is allowed to start a new removal
    this.getRequestClientId(ctx);

    const customerIdsToRemoveArray = customerIdsToRemove.split(',');

    const newRemoval = createNewRemoval(ctx, removalType, customerIdsToRemoveArray);
    await ctx.stub.putState(newRemoval.id, Buffer.from(stringify(sortKeysRecursive(toSimpleRemoval(newRemoval)))));
  }

  // set removal as done for a branch
  // only branches in ActiveRemovalBranches can set a removal as done
  @Transaction()
  public async SetRemovalAsDoneForBranch(
    ctx: Context,
    id: string,
    isSuccess: boolean = true,
    comment: string = '',
  ): Promise<void> {
    const exists = await this.RemovalExists(ctx, id);
    if (!exists) {
      throw new Error(`The removal with ${id} does not exist`);
    }

    const complexRemoval = await this.GetRemoval(ctx, id);

    const clientId = this.getRemovalClientId(ctx);

    if (complexRemoval.branchStatuses[clientId].status !== RemovalStatus.IN_PROGRESS) {
      throw new Error(`The branch ${clientId} has already done the removal with ${id}`);
    }

    if (complexRemoval.overallStatus !== RemovalStatus.IN_PROGRESS) {
      throw new Error(`The removal with ${id} is already done`);
    }

    complexRemoval.branchStatuses[clientId].status = isSuccess ? RemovalStatus.COMPLETED : RemovalStatus.FAILED;
    complexRemoval.branchStatuses[clientId].comment = comment;
    complexRemoval.lastUpdatedDate = getCurrentDate(ctx);

    if (isRemovalFullyCompleted(complexRemoval)) {
      complexRemoval.overallStatus =
        isRemovalSuccessful(complexRemoval)
          ? RemovalStatus.COMPLETED
          : RemovalStatus.FAILED;
    }

    await this.putState(ctx, complexRemoval);
  }

  // delete a removal if it is fully completed
  // only branches in ActiveRequestBranches can delete a removal
  @Transaction()
  public async DeleteRemoval(ctx: Context, id: string): Promise<void> {
    // check if the branch is allowed to delete a removal
    this.getRequestClientId(ctx);

    const exists = await this.RemovalExists(ctx, id);
    if (!exists) {
      throw new Error(`The removal with ${id} does not exist`);
    }

    const complexRemoval = await this.GetRemoval(ctx, id);
    if (complexRemoval.overallStatus === RemovalStatus.IN_PROGRESS) {
      throw new Error(`The removal with ${id} is not fully completed`);
    }

    await ctx.stub.deleteState(id);
  }

  // get all removals that are in progress for a branch
  // only branches in ActiveRemovalBranches can get removals in progress
  @Transaction(false)
  @Returns('string[]')
  public async GetAllRemovalsInProgressForRemovalBranch(ctx: Context): Promise<string[]> {
    const branchId = this.getRemovalClientId(ctx);

    const incompleteRemovalIds = [];
    const iterator = await ctx.stub.getStateByRange('', '');
    let result = await iterator.next();
    while (!result.done) {
      const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
      let record: ComplexRemoval;
      try {
        record = toComplexRemoval(JSON.parse(strValue));
      } catch (err) {
        console.log(err);
        record = null;
      }

      if (record && record.branchStatuses[branchId].status === RemovalStatus.IN_PROGRESS) {
        incompleteRemovalIds.push(record.id);
      }

      result = await iterator.next();
    }

    return incompleteRemovalIds;
  }

  // get audit history for a removal
  @Transaction(false)
  @Returns('string[]')
  public async GetRemovalAuditHistory(ctx: Context, id: string): Promise<ComplexRemoval[]> {
    const historyIterator = await ctx.stub.getHistoryForKey(id);
    const history = [];

    let result = await historyIterator.next();
    while (!result.done) {
      const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
      let record;
      try {
        record = toComplexRemoval(JSON.parse(strValue));
      } catch (err) {
        console.log(err);
        record = null;
      }

      if (record) {
        history.push(record);
      }

      result = await historyIterator.next();
    }

    // return the history in reverse order, so that the earliest state is first
    return history.reverse();
  }

  private getRequestClientId(ctx: Context): ActiveRequestBranches {
    const clientId = ctx.clientIdentity.getMSPID().replace('MSP', '');
    if (ActiveRequestBranches[clientId] === undefined) {
      throw new Error(`The branch ${clientId} is not allowed to perform this operation`);
    }
    return clientId as ActiveRequestBranches;
  }

  private getRemovalClientId(ctx: Context): ActiveRemovalBranches {
    const clientId = ctx.clientIdentity.getMSPID().replace('MSP', '');
    if (ActiveRemovalBranches[clientId] === undefined) {
      throw new Error(`The branch ${clientId} is not allowed to perform this operation`);
    }
    return clientId as ActiveRemovalBranches;
  }

  private async putState(ctx: Context, removal: ComplexRemoval): Promise<void> {
    const simpleRemoval = toSimpleRemoval(removal);
    await ctx.stub.putState(simpleRemoval.id, Buffer.from(stringify(sortKeysRecursive(simpleRemoval))));
    console.info(`Removal ${simpleRemoval.id} updated`);
  }
}
