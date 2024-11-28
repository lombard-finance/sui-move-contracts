import {
  SHARED_CONTROLLED_TREASURY,
  suiClient,
  MULTISIG,
  ONE_LBTC,
  DENYLIST,
} from "../config";
import { mintAndTransfer } from "../utils/mintAndTransfer";
import { getMultisigConfig } from "../helpers/getMultisigConfig";

async function testMintAndTransfer() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getMultisigConfig();

    // Execute the mint and transfer logic
    const result = await mintAndTransfer(
      suiClient,
      SHARED_CONTROLLED_TREASURY, // Controlled Treasury object
      ONE_LBTC, // Amount to mint
      MULTISIG.ADDRESS, // Recipient address
      DENYLIST, // Denylist global object
      multisigConfig // Multisig configuration
    );

    console.log("Transaction executed successfully:", result);
  } catch (error) {
    console.error("Error in testMintAndTransfer:", error);
  }
}

testMintAndTransfer();
