import { getFullnodeUrl, SuiClient, CoinBalance } from "@mysten/sui/client";
import {
  MIST_PER_SUI,
  fromHex,
  fromBase64,
  fromBase58,
  toHex,
  SUI_CLOCK_OBJECT_ID,
  SUI_TYPE_ARG,
} from "@mysten/sui/utils";
import { Transaction } from "@mysten/sui/transactions";
import { ethers } from "ethers";
import { bcs, BcsType } from "@mysten/sui/bcs";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  TokenDepositedEvent,
  TokenWithdrawalEvent,
  RewardsClaimedEvent,
} from "../src/types";
import {
  DEPOSIT_EVENT_TYPE,
  WITHDRAWAL_EVENT_TYPE,
  REWARDS_CLAIMED_EVENT_TYPE,
} from "../src/constants";

import dotenv from "dotenv";
dotenv.config();

function encodeCoinTypeName(coinTypeName: string) {
  const names = coinTypeName.split("::");
  return new Uint8Array([
    ...bcs.Address.serialize(names[0]).toBytes(),
    ...Buffer.from(`::${names[1]}::${names[2]}`),
  ]);
}

export async function sendTx(
  tx: Transaction,
  client: SuiClient,
  keypair: Ed25519Keypair,
) {
  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });
  const resp = await client.waitForTransaction({
    digest: result.digest,
    options: { showObjectChanges: true, showEvents: true },
  });
  return resp;
}

function createSignature(
  paymentId: number,
  projectId: number,
  deadline: number,
  coinAmount: number,
  account: string,
  coinTypeName: string,
) {
  const message: Uint8Array = new Uint8Array([
    ...bcs.u64().serialize(paymentId).toBytes(),
    ...bcs.U64.serialize(projectId).toBytes(),
    ...bcs.Address.serialize(account).toBytes(),
    ...encodeCoinTypeName(coinTypeName),
    ...bcs.U64.serialize(coinAmount).toBytes(),
    ...bcs.U64.serialize(deadline).toBytes(),
  ]);
  const signingKey = new ethers.SigningKey(
    process.env.EVM_PRIVATE_KEY as string,
  );
  return fromHex(signingKey.sign(ethers.keccak256(message)).serialized);
}

async function getDeadline(client: SuiClient) {
  const { epochStartTimestampMs, epochDurationMs } =
    await client.getLatestSuiSystemState();
  const deadline =
    parseInt(epochStartTimestampMs) + parseInt(epochDurationMs) + 1000 * 60;
  return deadline;
}

export async function deposit(
  packageId: string,
  rewardVaultId: string,
  client: SuiClient,
  keypair: Ed25519Keypair,
) {
  const paymentId = parseInt(ethers.toQuantity(ethers.randomBytes(8)));
  const projectId = 0;
  const deadline = await getDeadline(client);
  const coinAmount = 100;
  const account = keypair.getPublicKey().toSuiAddress();
  const coinTypeName = SUI_TYPE_ARG;
  const signatures = createSignature(
    paymentId,
    projectId,
    deadline,
    coinAmount,
    account,
    coinTypeName,
  );
  const tx = new Transaction();
  const [coin] = tx.splitCoins(tx.gas, [
    tx.pure(bcs.U64.serialize(coinAmount)),
  ]);
  tx.moveCall({
    target: `${packageId}::reward_vault_sui::deposit`,
    arguments: [
      tx.object(rewardVaultId),
      tx.pure(bcs.U64.serialize(paymentId)),
      tx.pure(bcs.U64.serialize(projectId)),
      coin,
      tx.pure(bcs.U64.serialize(deadline)),
      tx.pure(bcs.vector(bcs.U8).serialize(signatures)),
      tx.object(SUI_CLOCK_OBJECT_ID),
    ],
    typeArguments: [coinTypeName],
  });
  const resp = await sendTx(tx, client, keypair);
  return resp
    .events!.filter((event) => event.type.includes(DEPOSIT_EVENT_TYPE))
    .map((event) => event.parsedJson);
}

export async function claim(
  packageId: string,
  rewardVaultId: string,
  client: SuiClient,
  keypair: Ed25519Keypair,
) {
  const paymentId = parseInt(ethers.toQuantity(ethers.randomBytes(8)));
  const projectId = 0;
  const deadline = await getDeadline(client);
  const coinAmount = 60;
  const recipient = keypair.getPublicKey().toSuiAddress();
  const coinTypeName = SUI_TYPE_ARG;
  const signatures = createSignature(
    paymentId,
    projectId,
    deadline,
    coinAmount,
    recipient,
    coinTypeName,
  );
  const tx = new Transaction();
  tx.moveCall({
    target: `${packageId}::reward_vault_sui::claim`,
    arguments: [
      tx.object(rewardVaultId),
      tx.pure(bcs.U64.serialize(paymentId)),
      tx.pure(bcs.U64.serialize(projectId)),
      tx.pure(bcs.Address.serialize(recipient)),
      tx.pure(bcs.U64.serialize(coinAmount)),
      tx.pure(bcs.U64.serialize(deadline)),
      tx.pure(bcs.vector(bcs.U8).serialize(signatures)),
      tx.object(SUI_CLOCK_OBJECT_ID),
    ],
    typeArguments: [coinTypeName],
  });
  const resp = await sendTx(tx, client, keypair);
  return resp
    .events!.filter((event) => event.type.includes(REWARDS_CLAIMED_EVENT_TYPE))
    .map((event) => event.parsedJson);
}

export async function withdraw(
  packageId: string,
  rewardVaultId: string,
  client: SuiClient,
  keypair: Ed25519Keypair,
) {
  const paymentId = parseInt(ethers.toQuantity(ethers.randomBytes(8)));
  const projectId = 0;
  const deadline = await getDeadline(client);
  const coinAmount = 40;
  const recipient = keypair.getPublicKey().toSuiAddress();
  const coinTypeName = SUI_TYPE_ARG;
  const signatures = createSignature(
    paymentId,
    projectId,
    deadline,
    coinAmount,
    recipient,
    coinTypeName,
  );
  const tx = new Transaction();
  tx.moveCall({
    target: `${packageId}::reward_vault_sui::withdraw`,
    arguments: [
      tx.object(rewardVaultId),
      tx.pure(bcs.U64.serialize(paymentId)),
      tx.pure(bcs.U64.serialize(projectId)),
      tx.pure(bcs.Address.serialize(recipient)),
      tx.pure(bcs.U64.serialize(coinAmount)),
      tx.pure(bcs.U64.serialize(deadline)),
      tx.pure(bcs.vector(bcs.U8).serialize(signatures)),
      tx.object(SUI_CLOCK_OBJECT_ID),
    ],
    typeArguments: [coinTypeName],
  });
  const resp = await sendTx(tx, client, keypair);
  return resp
    .events!.filter((event) => event.type.includes(WITHDRAWAL_EVENT_TYPE))
    .map((event) => event.parsedJson);
}

function getRewardVaultId(objectChanges: any) {
  for (const item of objectChanges) {
    if (item.type == "created") {
      return item.objectId;
    }
  }
}

export async function createRewardVault(
  packageId: string,
  signers: string[],
  client: SuiClient,
  keypair: Ed25519Keypair,
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${packageId}::reward_vault_sui::create_reward_vault`,
    arguments: [
      tx.pure(
        bcs
          .vector(bcs.vector(bcs.U8))
          .serialize(signers.map((signer) => fromHex(signer))),
      ),
    ],
  });

  const resp = await sendTx(tx, client, keypair);
  const rewardVaultId: string = getRewardVaultId(resp.objectChanges!);
  return rewardVaultId;
}

// Convert MIST to Sui
export const balance = (balance: CoinBalance) => {
  return Number.parseInt(balance.totalBalance) / Number(MIST_PER_SUI);
};

function getPackageId(objectChanges: any) {
  for (const item of objectChanges) {
    if (item.type == "published") {
      return item.packageId;
    }
  }
  throw new Error(`some error happened during publish`);
}

export async function publish(client: SuiClient, keypair: Ed25519Keypair) {
  const { execSync } = require("child_process");
  const packagePath = ".";
  const { modules, dependencies } = JSON.parse(
    execSync(
      `\`which sui\` move build --dump-bytecode-as-base64 --path ${packagePath}`,
      {
        encoding: "utf-8",
      },
    ),
  );
  const tx = new Transaction();
  const [upgradeCap] = tx.publish({
    modules,
    dependencies,
  });
  tx.transferObjects([upgradeCap], keypair.toSuiAddress());
  const result = await sendTx(tx, client, keypair);
  return getPackageId(result.objectChanges);
}

export function getClientAndKeypair(url: string = getFullnodeUrl("mainnet")) {
  const client = new SuiClient({ url });
  const keypair = Ed25519Keypair.fromSecretKey(
    process.env.PRIVATE_KEY as string,
  );
  return { client, keypair };
}

async function getEvents(client: SuiClient, tx: string, type: string) {
  const { events } = await client.getTransactionBlock({
    digest: tx,
    options: { showEvents: true },
  });
  return events!
    .filter((event) => event.type.includes(type))
    .map((event) => event.parsedJson);
}

export async function getDepositedEventsFromTx(client: SuiClient, tx: string) {
  const events = (await getEvents(
    client,
    tx,
    DEPOSIT_EVENT_TYPE,
  )) as TokenDepositedEvent[];
  return events;
}

export async function getWithdrawalEventsFromTx(client: SuiClient, tx: string) {
  const events = (await getEvents(
    client,
    tx,
    WITHDRAWAL_EVENT_TYPE,
  )) as TokenDepositedEvent[];
  return events;
}

export async function getRewardVaultState(
  client: SuiClient,
  rewardVaultId: string,
) {
  const { data } = await client.getObject({
    id: rewardVaultId,
    options: { showContent: true, showBcs: true },
  });
  // function VecSet<T extends BcsType<any>>(T: T) {
  // return bcs.struct('VecSet<T>', {
  // contents: bcs.vector(T),
  // })
  // }
  // const UID = bcs.fixedArray(32, bcs.u8()).transform({
  // input: (id: string)=>fromHex(id),
  // output: (id)=>toHex(Uint8Array.from(id))
  // });
  // const RewardVaultStruct = bcs.struct('RewardVaultStruct', {
  // id: UID,
  // owner: bcs.Address,
  // signers: VecSet(bcs.vector(bcs.U8))
  // });
  // if(data!.bcs!.dataType=="moveObject"){
  // return RewardVaultStruct.parse(fromBase64(data!.bcs!.bcsBytes))
  // }
  if (data!.content!.dataType == "moveObject") {
    const rewardVaultState = data!.content!.fields as any;
    return {
      id: rewardVaultState.id.id, // UID
      owner: rewardVaultState.owner,
      signers: "0x" + toHex(rewardVaultState.signers.fields.contents[0]),
    };
  }
}
