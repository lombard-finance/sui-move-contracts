import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { consortium } from "../types/0xac86fa9a99e321c574dcd5a8f146101db92f6712d5540140961360e1aff75eac";

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

export async function addValidatorSet(
  client: SuiClient,
  consortiumAddresss: string,
  validatorPks: number[][],
  signerConfig: SignerConfig
): Promise<any> {
    const tx = new Transaction();

    consortium.builder.setNextValidatorSet(
        tx,
        [
            tx.object(consortiumAddresss),
            tx.pure.vector('vector<u8>', validatorPks),
        ]
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