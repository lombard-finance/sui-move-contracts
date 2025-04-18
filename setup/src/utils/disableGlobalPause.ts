import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  SHARED_CONTROLLED_TREASURY,
  suiClient,
  LBTC_COIN_TYPE,
  DENYLIST,
} from "../config";
import {
  executeMultisigTransaction,
  generateMultiSigPublicKey,
  createMultisigSigner,
} from "../helpers/multisigHelper";
import { Transaction } from "@mysten/sui/transactions";
import { treasury } from "../types/0x2721ad6e939baca77b36f415ab91edb1c91b256cbc8614f8f6c84bf06faf74af";

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

export async function disableGlobalPause(
  client: SuiClient,
  treasuryAddress: string,
  signerConfig: SignerConfig
) {
    const tx = new Transaction();

    treasury.builder.disableGlobalPauseV2(
      tx,
      [
        tx.object(treasuryAddress), // Controlled Treasury object
        tx.object("0x403"), // Denylist global object
      ],
      ["0x2d66430a27565b912f21be970e5ae1e8c0359f0b518c3235b751c75976791ce0::lbtc::LBTC"]
    );

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
