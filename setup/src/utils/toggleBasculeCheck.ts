import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { lbtc, treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";

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
 * Toggle the bascule check flag.
 *
 * @param client SuiClient instance for executing transactions.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param signerConfig Signer configuration object, either a simple signer or multisig participants and threshold.
 */
export async function toggleBasculeCheck(
  client: SuiClient,
  treasuryAddress: string,
  signerConfig: SignerConfig
): Promise<any> {
  const tx = new Transaction();

  treasury.builder.toggleBasculeCheck(
    tx,
    [tx.object(treasuryAddress)],
    [lbtc.LBTC.TYPE_QNAME]
  );
  tx.setGasBudget(5000000000);

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