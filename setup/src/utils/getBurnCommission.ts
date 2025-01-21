import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x70fdf49de5fbc402f1ddb71208abd3c414348638f5b3f3cafb72ca2875efa33f";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Reads the current burn_commission via devInspect (read-only).
 */
export async function getBurnCommission(
  client: SuiClient,
  treasuryObjectId: string
): Promise<bigint> {
    try {

        const result = await treasury.view.getBurnCommission(
            client,
            [treasuryObjectId],
            [LBTC_COIN_TYPE]
        );

        return result.results_decoded[0];
    } catch (error) {
        console.error(
            `Error checking the global pause status in the Denylist:`,
            error
        );
        throw error;
    }
}
