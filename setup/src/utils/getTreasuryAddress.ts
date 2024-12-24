import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x2af9ec333d1e5cd46936afcf39562b98e5e70b80fc1c317d2b7118ac7718ea36";
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
