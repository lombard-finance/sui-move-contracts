import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Check if an address has a minter capability.
 */
export async function witnessHasMinterCap(
  client: SuiClient,
  treasuryAddress: string,
  owner: string
): Promise<boolean> {
  try {
    const result = await treasury.view.witnessHasMinterCap(
      client,
      [treasuryAddress, owner],
      [LBTC_COIN_TYPE]
    );
    return result.results_decoded[0];
  } catch (error) {
    console.error(`Error checking minter cap for ${owner}:`, error);
    throw error;
  }
}
