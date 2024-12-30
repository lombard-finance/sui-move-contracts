import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { treasury } from "../types/0x93556210467b0c290c342d4e43d8777019cbf78346a1758ae4858e55c9413e41";
import { LBTC_COIN_TYPE, PACKAGE_ID } from "../config";

// Define supported capabilities with their corresponding types
type CapabilityType = "AdminCap" | "MinterCap" | "PauserCap";

// Define the participant structure for multisig
interface MultisigParticipant {
  keypair: Ed25519Keypair;
  weight: number;
}

// Adjusted `signerConfig` type
type SignerConfig =
  | { simpleSigner: Ed25519Keypair }
  | {
      multisig: {
        users: MultisigParticipant[];
        threshold: number;
      };
    };

/**
 * Sets the action bytes
 *
 * @param client SuiClient instance for executing transactions.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param actionBytes The action bytes number.
 * @param signerConfig Signer configuration object, either a simple signer or multisig participants and threshold.
 */
export async function setActionBytes(
  client: SuiClient,
  treasuryAddress: string,
  actionBytes: number,
  signerConfig: SignerConfig
): Promise<any> {
  const tx = new Transaction();

  treasury.builder.setActionBytes(
    tx,
    [
        tx.object(treasuryAddress),
        tx.pure.u32(actionBytes),
    ],
    [LBTC_COIN_TYPE]
  )

  // Determine the signer and execute the transaction
  if ("simpleSigner" in signerConfig) {
    // Simple signer
    return await client.signAndExecuteTransaction({
      transaction: tx,
      signer: signerConfig.simpleSigner,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });
  } else if ("multisig" in signerConfig) {
    // Multisig signer
    const { users, threshold } = signerConfig.multisig;

    const multiSigPublicKey = generateMultiSigPublicKey(
      users.map(({ keypair, weight }) => ({
        publicKey: keypair.getPublicKey(),
        weight,
      })),
      threshold
    );

    const signer = createMultisigSigner(
      multiSigPublicKey,
      users.map(({ keypair }) => keypair)
    );

    return await executeMultisigTransaction(client, tx, signer);
  } else {
    throw new Error(
      "Invalid signer configuration. Provide either `simpleSigner` or `multisig`."
    );
  }
}
