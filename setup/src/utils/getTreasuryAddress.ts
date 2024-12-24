import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x70fdf49de5fbc402f1ddb71208abd3c414348638f5b3f3cafb72ca2875efa33f";
import { LBTC_COIN_TYPE } from "../config";

/**
 * Reads the treasury_address field via devInspect.
 */
export async function getTreasuryAddress(
  client: SuiClient,
  treasuryObjectId: string
): Promise<string> {
    try {

        const result = await treasury.view.getTreasuryAddress(
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
