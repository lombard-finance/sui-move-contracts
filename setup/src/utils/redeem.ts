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
 * Redeem tokens from the ControlledTreasury<T>.
 * 
 * @param client SuiClient instance for submitting transactions
 * @param treasuryAddress The Object ID of the &mut ControlledTreasury<T>
 * @param coinObjectId The Object ID of the Coin<T> to redeem
 * @param scriptPubkeyHex A hex string representing the scriptPubkey
 * @param signer The Ed25519Keypair used for signing
 * @returns Transaction execution result
 */
export async function redeem(
  client: SuiClient,
  treasuryAddress: string,
  coinObjectId: string,
  scriptPubkeyHex: string,
  multisigConfig: MultisigConfig
): Promise<any> {

    const tx = new Transaction();
    const scriptPubkeyBytes = Array.from(Buffer.from(scriptPubkeyHex, "hex"));

      const { users, threshold } = multisigConfig;
    
      // Generate MultiSigPublicKey
      const multiSigPublicKey = generateMultiSigPublicKey(
        users.map(({ keypair, weight }) => ({
          publicKey: keypair.getPublicKey(),
          weight,
        })),
        threshold
      );
      tx.setGasBudget(5000000000);

    treasury.builder.redeem(
        tx,
        [
        tx.object(treasuryAddress),                    // &mut ControlledTreasury<T>
        tx.object(coinObjectId),                       // Coin<T>
        tx.pure.vector("u8", scriptPubkeyBytes),       // vector<u8>
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
