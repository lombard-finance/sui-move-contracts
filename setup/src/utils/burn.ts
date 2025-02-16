import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { LBTC_COIN_TYPE } from "../config";

import {
  treasury,
} from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
import { createMultisigSigner, executeMultisigTransaction, generateMultiSigPublicKey } from "../helpers/multisigHelper";


// Define the participant structure for multisig
interface MultisigParticipant {
  keypair: Ed25519Keypair;
  weight: number;
}

// Define the multisig configuration type
interface MultisigConfig {
  users: MultisigParticipant[];
  threshold: number;
}

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
  multisigConfig: MultisigConfig
): Promise<any> {
  const tx = new Transaction();
  const { users, threshold } = multisigConfig;

   // Generate MultiSigPublicKey
        const multiSigPublicKey = generateMultiSigPublicKey(
          users.map(({ keypair, weight }) => ({
            publicKey: keypair.getPublicKey(),
            weight,
          })),
          threshold
        );
        
  treasury.builder.burn(
    tx,
    [
      tx.object(treasuryObjectId), // &mut ControlledTreasury<T>
      tx.object(coinObjectId),     // Coin<T>
    ],
    [LBTC_COIN_TYPE] // <T>
  );

  // Create a MultiSigSigner
  const signer = createMultisigSigner(
    multiSigPublicKey,
    users.map(({ keypair }) => keypair)
  );

  // Execute the transaction
  return await executeMultisigTransaction(client, tx, signer);
}
