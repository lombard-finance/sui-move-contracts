import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import {
  lbtc,
  treasury,
} from "../types/0xbe30647d2dbec99adc943e26f52e1a9ece3e507fc45913aa7b53c7bf80c4ed09";
import { DENYLIST, LBTC_COIN_TYPE } from "../config";
import { SuiClient } from "@mysten/sui/client";
import { createMultisigSigner, executeMultisigTransaction, generateMultiSigPublicKey } from "../helpers/multisigHelper";

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

export async function manualClaim(
  client: SuiClient,
  treasuryAddress: string,
  consortiumAddress: string,
  payload: string,
  proof: string,
  signerConfig: SignerConfig
): Promise<any> {
  // Manual claim the LBTC, the payload's `to` must be the same address with the sender of the transaction
  const tx = new Transaction();
  const payloadToBytes = Array.from(Buffer.from(payload, "hex"));
  const proofToBytes = Array.from(Buffer.from(proof, "hex"));
  treasury.builder.mint(
    tx,
    [
      tx.object(treasuryAddress),
      tx.object(consortiumAddress),
      tx.object(DENYLIST),
      // tx.object(SHARED_BASCULE),
      tx.pure.vector("u8", payloadToBytes),
      tx.pure.vector("u8", proofToBytes),
    ],
    [LBTC_COIN_TYPE]
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
