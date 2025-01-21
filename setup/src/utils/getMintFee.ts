import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x4ef85dbd178109cb92f709d4f3429a8c3bf28f4a04642a74c674670698fc1c60";
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