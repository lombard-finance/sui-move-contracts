import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x4ef85dbd178109cb92f709d4f3429a8c3bf28f4a04642a74c674670698fc1c60";
import { LBTC_COIN_TYPE, PACKAGE_ID } from "../config";

/**
 * Capability types supported in the Controlled Treasury.
 */
type CapabilityType = "AdminCap" | "MinterCap" | "PauserCap";

/**
 * Checks if the given address has a specific capability (AdminCap, MinterCap, or PauserCap).
 *
 * @param client SuiClient instance for querying the blockchain.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param targetAddress The address to check for the capability.
 * @param capType The type of capability to check ("AdminCap", "MinterCap", or "PauserCap").
 * @returns A boolean indicating whether the address has the specified capability.
 */
export async function hasCap(
  client: SuiClient,
  treasuryAddress: string,
  targetAddress: string,
  capType: CapabilityType
): Promise<boolean> {
  try {
    // Use the view namespace to inspect the capability
    const result = await treasury.view.hasCap(
      client,
      [treasuryAddress, targetAddress],
      [LBTC_COIN_TYPE, `${PACKAGE_ID}::treasury::${capType}`]
    );

    // Extract and return the decoded result
    return result.results_decoded[0]; // Access the first element of results_decoded
  } catch (error) {
    console.error(
      `Error checking ${capType} for address ${targetAddress}:`,
      error
    );
    throw error;
  }
}
