import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x0bf1f46efc094312ecf58f6941263ad6340eff64b5292b21b2591f04c11978ad";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Lists all capabilities assigned to a given address in the Controlled Treasury.
 *
 * @param client SuiClient instance for querying the blockchain.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param targetAddress The address to list capabilities for.
 * @returns A list of capabilities (e.g., "AdminCap", "MinterCap", "PauserCap") assigned to the address.
 */
export async function listCapabilities(
  client: SuiClient,
  treasuryAddress: string,
  targetAddress: string
): Promise<string[]> {
  try {
    // Use the view namespace to fetch roles for the given address
    const result = await treasury.view.listRoles(
      client,
      [treasuryAddress, targetAddress],
      [LBTC_COIN_TYPE] // Specify the coin type
    );

    // Extract and return the decoded result
    return result.results_decoded[0]; // Access the first element of results_decoded
  } catch (error) {
    console.error(
      `Error listing capabilities for address ${targetAddress}:`,
      error
    );
    throw error;
  }
}
