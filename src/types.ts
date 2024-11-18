export interface TokenDepositedEvent {
  amount: string;
  deadline: string;
  payment_id: string;
  project_id: string;
  token: string;
}

export interface TokenWithdrawalEvent {
  payment_id: string;
  project_id: string;
  token: string;
  amount: string;
  recipient: string;
  deadline: string;
}

export interface RewardsClaimedEvent {
  payment_id: string;
  project_id: string;
  token: string;
  amount: string;
  recipient: string;
  deadline: string;
}

export interface RewardVaultState {
  id: string;
  owner: string;
  signers: string[];
}

export enum ActionType {
  Deposit,
  Withdraw,
  Claim,
}
