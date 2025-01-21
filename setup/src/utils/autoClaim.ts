import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import {
  lbtc,
  treasury,
} from "../types/0x4ef85dbd178109cb92f709d4f3429a8c3bf28f4a04642a74c674670698fc1c60";
import { DENYLIST, LBTC_COIN_TYPE, SHARED_BASCULE } from "../config";
import { SuiClient } from "@mysten/sui/client";
import { createMultisigSigner, executeMultisigTransaction, generateMultiSigPublicKey } from "../helpers/multisigHelper";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

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

export async function autoClaim(
  client: SuiClient,
  treasuryAddress: string,
  consortiumAddress: string,
  payload: string,
  proof: string,
  feePayload: string,
  signature: string,
  public_key: string,
  signerConfig: SignerConfig
): Promise<any> {
  // Claim the LBTC on behalf of the user
  const tx = new Transaction();
  const payloadToBytes = Array.from(Buffer.from(payload, "hex"));
  const proofToBytes = Array.from(Buffer.from(proof, "hex"));
  const feePayloadToBytes = Array.from(Buffer.from(feePayload, "hex"));
  const signatureToBytes = Array.from(Buffer.from(signature, "hex"));
  const public_keyToBytes = Array.from(Buffer.from(public_key, "hex"));

  treasury.builder.mintWithFee(
    tx,
    [
      tx.object(treasuryAddress),
      tx.object(consortiumAddress),
      tx.object(DENYLIST),
      tx.object(SHARED_BASCULE),
      tx.pure.vector("u8", payloadToBytes),
      tx.pure.vector("u8", proofToBytes),
      tx.pure.vector("u8", feePayloadToBytes),
      tx.pure.vector("u8", signatureToBytes),
      tx.pure.vector("u8", public_keyToBytes),
      tx.object(SUI_CLOCK_OBJECT_ID),
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
