import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { treasury } from "../types/0x2af9ec333d1e5cd46936afcf39562b98e5e70b80fc1c317d2b7118ac7718ea36";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Toggles (enable/disable) the `withdrawal_enabled` bool.
 */
export async function toggleWithdrawal(
  client: SuiClient,
  treasuryObjectId: string,
  signer: Ed25519Keypair
): Promise<any> {
  const tx = new Transaction();

  // treasury::toggle_withdrawal<T>
  treasury.builder.toggleWithdrawal(
    tx,
    [
      tx.object(treasuryObjectId),
    ],
    [LBTC_COIN_TYPE]
  );

  return await client.signAndExecuteTransaction({
    transaction: tx,
    signer,
    options: { showEffects: true, showObjectChanges: true },
  });
}
