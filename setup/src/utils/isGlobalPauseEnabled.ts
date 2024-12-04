import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x0bf1f46efc094312ecf58f6941263ad6340eff64b5292b21b2591f04c11978ad";
import { LBTC_COIN_TYPE, DENYLIST } from "../config";

/**
 * Checks if the global pause is enabled in the Controlled Treasury.
 *
 * @param client SuiClient instance for querying the blockchain.
 * @returns A boolean indicating whether the global pause is enabled.
 */
export async function isGlobalPauseEnabled(
  client: SuiClient
): Promise<boolean> {
  try {
    // Use the view namespace to check the global pause status
    const result = await treasury.view.isGlobalPauseEnabled(
      client,
      [DENYLIST],
      [LBTC_COIN_TYPE]
    );

    // Extract and return the decoded result
    return result.results_decoded[0];
  } catch (error) {
    console.error(
      `Error checking the global pause status in the Denylist:`,
      error
    );
    throw error;
  }
}
