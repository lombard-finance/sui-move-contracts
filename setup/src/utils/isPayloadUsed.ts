import { SuiClient } from "@mysten/sui/client";
import { consortium } from "../types/0x190fce1b032302dea757432f9d5271e3905956430f86805d0766098ecb9956e2";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";

/**
 * Checks if the payload is stored in the Consortium
 *
 * @param client SuiClient instance for querying the blockchain.
 * @returns A boolean indicating whether the payload is used
 */
export async function isPayloadUsed(
  client: SuiClient,
  consortiumAddress: string,
  payloadHash: string,
  sender: string
): Promise<boolean> {
  try {
    // Use devInspect to check if the payload is used
    const tx = new Transaction();
    
    consortium.builder.isPayloadUsed(
        tx,
        [
            tx.object(consortiumAddress),
            tx.pure.vector("u8", Array.from(Buffer.from(payloadHash, "hex"))),
        ]
    )

    const result = await client.devInspectTransactionBlock({
        sender: sender,
        transactionBlock: tx
    })

    // Extract and return the decoded result
    return bcs.bool().parse(new Uint8Array(result.results[0].returnValues[0][0]));
  } catch (error) {
    console.error(
      `Error checking the payload in the Consortium`,
      error
    );
    throw error;
  }
}
