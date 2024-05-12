import { Object, Property } from 'fabric-contract-api';

export enum ActiveRequestBranches {
  Branch1 = 'Branch1',
}
export enum ActiveRemovalBranches {
  Branch2 = 'Branch2',
  Branch3 = 'Branch3',
}

export enum RemovalType {
  REQUEST = 'REQUEST',
  RETENTION = 'RETENTION',
}
export enum RemovalStatus {
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
}
export type BranchStatus = {
  status: RemovalStatus;
  comment: string;
}

export type ComplexRemoval = {
  id: string;
  startDate: Date;
  lastUpdatedDate: Date;
  type: RemovalType;
  overallStatus: RemovalStatus;
  customerIds: string[];
  branchStatuses: Record<ActiveRemovalBranches, BranchStatus>;
}

@Object()
export class SimpleRemoval {

  // primary key
  @Property()
  public id: string;

  @Property()
  public startDate: string;

  @Property()
  public lastUpdatedDate: string;

  @Property()
  public type: string;

  @Property()
  public overallStatus: string;

  @Property()
  public customerIds: string;

  @Property()
  public branchStatuses: string;
}

export const toComplexRemoval = (simpleRemoval: SimpleRemoval): ComplexRemoval => ({
  id: simpleRemoval.id,
  startDate: new Date(simpleRemoval.startDate),
  lastUpdatedDate: new Date(simpleRemoval.lastUpdatedDate),
  type: simpleRemoval.type as RemovalType,
  overallStatus: simpleRemoval.overallStatus as RemovalStatus,
  customerIds: JSON.parse(simpleRemoval.customerIds),
  branchStatuses: JSON.parse(simpleRemoval.branchStatuses),
});

export const toSimpleRemoval = (complexRemoval: ComplexRemoval): SimpleRemoval => ({
  id: complexRemoval.id,
  startDate: complexRemoval.startDate.toISOString(),
  lastUpdatedDate: complexRemoval.lastUpdatedDate.toISOString(),
  type: complexRemoval.type,
  overallStatus: complexRemoval.overallStatus,
  customerIds: JSON.stringify(complexRemoval.customerIds),
  branchStatuses: JSON.stringify(complexRemoval.branchStatuses),
});
