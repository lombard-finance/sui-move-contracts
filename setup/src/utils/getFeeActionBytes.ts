import { SuiClient } from "@mysten/sui/client";
import { treasury, lbtc } from "../types/0x4ef85dbd178109cb92f709d4f3429a8c3bf28f4a04642a74c674670698fc1c60";

/**
 * Get the action bytes in the Controlled Treasury.
 *
 * @param client SuiClient instance for querying the blockchain.
 * @returns The action bytes number.
 */
export async function getFeeActionBytes(
  client: SuiClient,
  treasuryAddress: string
): Promise<number> {
  try {
    // Use the view namespace to check the global pause status
    const result = await treasury.view.getFeeActionBytes(
      client,
      [treasuryAddress],
      [lbtc.LBTC.TYPE_QNAME]
    );

    // Extract and return the decoded result
    return result.results_decoded[0];
  } catch (error) {
    console.error(
      `Error checking the fee action bytes in the Controlled Treasury`,
      error
    );
    throw error;
  }
}