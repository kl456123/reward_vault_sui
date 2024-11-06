import { getFullnodeUrl, SuiClient, CoinBalance } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

import {
  createRewardVault,
  deposit,
  claim,
  withdraw,
  getClientAndKeypair,
  getRewardVaultState,
  publish,
} from "../src/utils";

async function main() {
  const { client, keypair } = await getClientAndKeypair();
  const evmAddress = "0xbd11861d13cafa8ad6e143da7034f8a907cd47a8";

  // const packageId =
  // "0xd94252d8e5f5561ada000d29bb6437d2f45d94811099d3d230ce87ee56a89cab";
  const packageId = await publish(client, keypair);

  // ////////// create reward vault ////////////////
  // 0xd94252d8e5f5561ada000d29bb6437d2f45d94811099d3d230ce87ee56a89cab::reward_vault_sui::RewardVault
  // const objectId = '0x26cb86f2b72973774b10c5e25871194c74c5c2770b6812327a36d3fe20b58c66'
  const objectId = await createRewardVault(
    packageId,
    [evmAddress],
    client,
    keypair,
  );

  await deposit(packageId, objectId, client, keypair);
  await claim(packageId, objectId, client, keypair);
  await withdraw(packageId, objectId, client, keypair);

  const rewardVaultState = await getRewardVaultState(client, objectId);

  console.log(rewardVaultState);
}

main();
