import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import {
  lbtc,
  treasury,
} from "../types/0x4d7b29503d6089a77be130aa79db32ce77fd0160fd9982be9827725496970825";
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
