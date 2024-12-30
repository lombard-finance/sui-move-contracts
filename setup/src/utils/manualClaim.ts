import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import {
  lbtc,
  treasury,
} from "../types/0x93556210467b0c290c342d4e43d8777019cbf78346a1758ae4858e55c9413e41";
import { DENYLIST, LBTC_COIN_TYPE } from "../config";
import { SuiClient } from "@mysten/sui/client";

export async function manualClaim(
  client: SuiClient,
  treasuryAddress: string,
  consortiumAddress: string,
  payload: string,
  proof: string,
  signer: Ed25519Keypair
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

  return await client.signAndExecuteTransaction({
    transaction: tx,
    signer: signer,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
}
