import { SuiClient } from "@mysten/sui/client";
import { treasury, lbtc } from "../types/0x93556210467b0c290c342d4e43d8777019cbf78346a1758ae4858e55c9413e41";

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