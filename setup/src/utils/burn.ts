import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { LBTC_COIN_TYPE } from "../config";

import {
  treasury,
} from "../types/0x2af9ec333d1e5cd46936afcf39562b98e5e70b80fc1c317d2b7118ac7718ea36";

/**
 * Burn coins from the ControlledTreasury<T>.
 * 
 * @param client SuiClient instance for submitting transactions
 * @param treasuryObjectId The Object ID of the &mut ControlledTreasury<T>
 * @param coinObjectId The Object ID of the Coin<T> to burn
 * @param signer The Ed25519Keypair (or RawSigner) used for signing
 * @returns Transaction execution result
 */
export async function burn(
  client: SuiClient,
  treasuryObjectId: string,
  coinObjectId: string,
  signer: Ed25519Keypair
): Promise<any> {
  const tx = new Transaction();

  treasury.builder.burn(
    tx,
    [
      tx.object(treasuryObjectId), // &mut ControlledTreasury<T>
      tx.object(coinObjectId),     // Coin<T>
    ],
    [LBTC_COIN_TYPE] // <T>
  );

  return await client.signAndExecuteTransaction({
    transaction: tx,
    signer,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
}
