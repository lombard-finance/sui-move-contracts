import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import {
  lbtc,
  treasury,
} from "../types/0xd920ccead3087ee15d049fd618062c7fabc12cb65fe7f7b5acd942c7835b2ee4";
import { DENYLIST } from "../config";
import { SuiClient } from "@mysten/sui/client";

export async function manualClaim(
  client: SuiClient,
  treasuryAddress: string,
  consortiumAddress: string,
  payload: string,
  proof: string,
  recipient: Ed25519Keypair
): Promise<any> {
  // Manual claim the LBTC, the payload's `to` must be the same address with the sender of the transaction
  const tx = new Transaction();
  const payloadToBytes = Array.from(Buffer.from(payload, "hex"));
  const proofToBytes = Array.from(Buffer.from(proof, "hex"));
  treasury.builder.claim(
    tx,
    [
      tx.object(treasuryAddress),
      tx.object(consortiumAddress),
      tx.object(DENYLIST),
      // tx.object(SHARED_BASCULE),
      tx.pure.vector("u8", payloadToBytes),
      tx.pure.vector("u8", proofToBytes),
    ],
    [lbtc.LBTC.TYPE_QNAME]
  );

  return await client.signAndExecuteTransaction({
    transaction: tx,
    signer: recipient,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
}
