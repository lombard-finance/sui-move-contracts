import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Get remaining mint limit for a witness Minter.
 */
export async function getWitnessMinterCapLeft(
  client: SuiClient,
  treasuryAddress: string,
  owner: string
): Promise<bigint> {
  try {
    const result = await treasury.view.getWitnessMinterCapLeft(
      client,
      [treasuryAddress, owner],
      [LBTC_COIN_TYPE]
    );
    return result.results_decoded[0];
  } catch (error) {
    console.error(`Error fetching mint cap left for ${owner}:`, error);
    throw error;
  }
}
