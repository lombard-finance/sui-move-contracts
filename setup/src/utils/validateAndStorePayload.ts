import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { consortium } from "../types/0x5e54957685afb18cd462339844cc9804bd4d4f0a00f23a0ce2ec04366c38a55a";

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

export async function validateAndStorePayload(
  client: SuiClient,
  consortiumAddresss: string,
  payload: number[],
  proof: number[],
  signerConfig: SignerConfig
): Promise<any> {
  const tx = new Transaction();

  let validateProof = consortium.builder.validatePayload(tx, [
    tx.object(consortiumAddresss),
    tx.pure.vector("u8", payload),
    tx.pure.vector("u8", proof),
  ]);

  consortium.builder.resolveProof(tx, [
    tx.object(consortiumAddresss),
    validateProof,
  ]);

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
