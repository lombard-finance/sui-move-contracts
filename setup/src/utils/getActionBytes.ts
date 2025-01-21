import { SuiClient } from "@mysten/sui/client";
import { treasury, lbtc } from "../types/0x190fce1b032302dea757432f9d5271e3905956430f86805d0766098ecb9956e2";

/**
 * Get the action bytes in the Controlled Treasury.
 *
 * @param client SuiClient instance for querying the blockchain.
 * @returns The action bytes number.
 */
export async function getActionBytes(
  client: SuiClient,
  treasuryAddress: string
): Promise<number> {
  try {
    // Use the view namespace to check the global pause status
    const result = await treasury.view.getActionBytes(
      client,
      [treasuryAddress],
      [lbtc.LBTC.TYPE_QNAME]
    );

    // Extract and return the decoded result
    return result.results_decoded[0];
  } catch (error) {
    console.error(
      `Error checking the bascule check flag in the Controlled Treasury`,
      error
    );
    throw error;
  }
}