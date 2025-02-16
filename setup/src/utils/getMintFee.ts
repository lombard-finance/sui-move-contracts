import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Reads the current dust_fee_rate via devInspect.
 */
export async function getMintFee(
  client: SuiClient,
  treasuryObjectId: string
): Promise<bigint> {
    try {

        const result = await treasury.view.getMintFee(
            client,
            [treasuryObjectId],
            [LBTC_COIN_TYPE]
        );

        return result.results_decoded[0];
    } catch (error) {
        console.error(
            `Error checking the mint fee in Controlled Treasury`,
            error
        );
        throw error;
    }
}