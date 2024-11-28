import { PublicKey } from "@mysten/sui/cryptography";
import { MultiSigPublicKey } from "@mysten/sui/multisig";
import { MultiSigSigner } from "@mysten/sui/multisig";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";

/**
 * Generate a MultiSigPublicKey based on public keys and threshold.
 * @param publicKeys Array of public keys and their weights
 * @param threshold Threshold required for the multisig
 * @returns MultiSigPublicKey instance
 */
export function generateMultiSigPublicKey(
  publicKeys: { publicKey: PublicKey; weight: number }[],
  threshold: number
): MultiSigPublicKey {
  return MultiSigPublicKey.fromPublicKeys({
    threshold,
    publicKeys,
  });
}

/**
 * Create a MultiSigSigner using the provided multisig public key and signers.
 * @param multiSigPublicKey The multisig public key
 * @param signers Array of keypairs to use as signers
 * @returns MultiSigSigner instance
 */
export function createMultisigSigner(
  multiSigPublicKey: MultiSigPublicKey,
  signers: Ed25519Keypair[]
): MultiSigSigner {
  if (signers.length === 0) {
    throw new Error(
      "At least one signer is required to create a MultiSigSigner."
    );
  }
  return new MultiSigSigner(multiSigPublicKey, [...signers]);
}

/**
 * Execute a transaction with a multisig signer.
 * @param suiClient Sui client instance
 * @param tx Transaction to be executed
 * @param signer MultiSigSigner instance
 * @returns Transaction execution result
 */
export async function executeMultisigTransaction(
  suiClient: SuiClient,
  tx: Transaction,
  signer: MultiSigSigner
) {
  try {
    console.log("Executing transaction...");
    const result = await suiClient.signAndExecuteTransaction({
      transaction: tx,
      signer,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });

    return result;
  } catch (error) {
    console.error("Transaction execution failed:", error);
    throw error;
  }
}
