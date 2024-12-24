import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { treasury } from "../types/0x2af9ec333d1e5cd46936afcf39562b98e5e70b80fc1c317d2b7118ac7718ea36";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Sets the treasury_address to `newTreasuryAddress`.
 */
export async function setTreasuryAddress(
  client: SuiClient,
  treasuryObjectId: string,
  newTreasuryAddress: string,
  signer: Ed25519Keypair
): Promise<any> {
  const tx = new Transaction();

  // treasury::set_treasury_address<T>
  treasury.builder.setTreasuryAddress(
    tx,
    [
      tx.object(treasuryObjectId),      // &mut ControlledTreasury<T>
      tx.pure.address(newTreasuryAddress),
    ],
    [LBTC_COIN_TYPE]
  );

  return await client.signAndExecuteTransaction({
    transaction: tx,
    signer,
    options: { showEffects: true, showObjectChanges: true },
  });
}
