import {
  SHARED_CONTROLLED_TREASURY,
  suiClient,
  MULTISIG,
  ONE_LBTC,
  DENYLIST,
} from "../config";
import { mintAndTransfer } from "../utils/mintAndTransfer";
import { getMultisigConfig, getTestMultisigConfig } from "../helpers/getMultisigConfig";

const DUMMY_TXID = new TextEncoder().encode("abcd");
const DUMMY_IDX: number = 0;

async function testMintAndTransfer() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    // Execute the mint and transfer logic
    const result = await mintAndTransfer(
      suiClient,
      SHARED_CONTROLLED_TREASURY, // Controlled Treasury object
      ONE_LBTC, // Amount to mint
      MULTISIG.ADDRESS, // Recipient address
      DENYLIST, // Denylist global object
      DUMMY_TXID, // Placeholder BTC deposit transaction ID
      DUMMY_IDX, // Placeholder BTC deposit index
      multisigConfig // Multisig configuration
    );

    console.log("Transaction executed successfully:", result);
  } catch (error) {
    console.error("Error in testMintAndTransfer:", error);
  }
}

testMintAndTransfer();
