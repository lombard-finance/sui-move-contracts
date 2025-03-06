import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x818430a456ff977f7320f78650d19801f90758d200a01dd3c2c679472c521357";
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
      ["0x3e8e9423d80e1774a7ca128fccd8bf5f1f7753be658c5e645929037f7c819040::lbtc::LBTC"]
    );
    return result.results_decoded[0];
  } catch (error) {
    console.error(`Error fetching mint cap left for ${owner}:`, error);
    throw error;
  }
}
