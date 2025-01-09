import { SuiClient } from "@mysten/sui/client";
import { treasury, lbtc } from "../types/0xbe30647d2dbec99adc943e26f52e1a9ece3e507fc45913aa7b53c7bf80c4ed09";

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