import { getFullnodeUrl, SuiClient, CoinBalance } from "@mysten/sui/client";
import {
  MIST_PER_SUI,
  fromHex,
  toHex,
  SUI_CLOCK_OBJECT_ID,
  SUI_TYPE_ARG,
} from "@mysten/sui/utils";
import { Transaction } from "@mysten/sui/transactions";
import { ethers } from "ethers";
import { bcs } from "@mysten/sui/bcs";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import dotenv from "dotenv";
dotenv.config();

const packageId =
  "0xd94252d8e5f5561ada000d29bb6437d2f45d94811099d3d230ce87ee56a89cab";

// Convert MIST to Sui
const balance = (balance: CoinBalance) => {
  return Number.parseInt(balance.totalBalance) / Number(MIST_PER_SUI);
};

function getPackageId(objectChanges: any) {
  for (const item of objectChanges) {
    if (item.type == "published") {
      return item.packageId;
    }
  }
}

function getRewardVaultId(objectChanges: any) {
  for (const item of objectChanges) {
    if (item.type == "created") {
      return item.objectId;
    }
  }
}

async function sendTx(
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
    options: { showObjectChanges: true },
  });
  return resp;
}

async function getDeadline(client: SuiClient) {
  const { epochStartTimestampMs, epochDurationMs } =
    await client.getLatestSuiSystemState();
  const deadline =
    parseInt(epochStartTimestampMs) + parseInt(epochDurationMs) + 1000 * 60;
  return deadline;
}

async function publish(client: SuiClient, keypair: Ed25519Keypair) {
  const tx = new Transaction();
  // tx.publish();
}

async function createRewardVault(
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

function encodeCoinTypeName(coinTypeName: string) {
  const names = coinTypeName.split("::");
  return new Uint8Array([
    ...bcs.Address.serialize(names[0]).toBytes(),
    ...Buffer.from(`::${names[1]}::${names[2]}`),
  ]);
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
  const wallet = new ethers.Wallet(process.env.EVM_PRIVATE_KEY as string);
  return fromHex(wallet.signingKey.sign(ethers.keccak256(message)).serialized);
}

async function deposit(
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
  return sendTx(tx, client, keypair);
}

async function claim(
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
  return sendTx(tx, client, keypair);
}

async function withdraw(
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
  return sendTx(tx, client, keypair);
}

async function main() {
  const url = getFullnodeUrl("mainnet");
  const client = new SuiClient({ url });
  const keypair = Ed25519Keypair.fromSecretKey(
    process.env.PRIVATE_KEY as string,
  );
  const suiAddress = keypair.getPublicKey().toSuiAddress();
  const evmAddress = "0xbd11861d13cafa8ad6e143da7034f8a907cd47a8";

  ////////// create reward vault ////////////////
  const objectId = await createRewardVault([evmAddress], client, keypair);

  // 0xd94252d8e5f5561ada000d29bb6437d2f45d94811099d3d230ce87ee56a89cab::reward_vault_sui::RewardVault
  // 0x26cb86f2b72973774b10c5e25871194c74c5c2770b6812327a36d3fe20b58c66'
  await deposit(objectId, client, keypair);
  await claim(objectId, client, keypair);
  await withdraw(objectId, client, keypair);
}

main();
