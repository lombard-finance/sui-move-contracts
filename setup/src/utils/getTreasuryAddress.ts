import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
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
            `Error getting the Treasury address from Controlled Treasury`,
            error
        );
        throw error;
    }
}
