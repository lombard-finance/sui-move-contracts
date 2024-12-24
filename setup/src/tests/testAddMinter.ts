import { SHARED_CONTROLLED_TREASURY, suiClient, MULTISIG } from "../config";
import { addCapability } from "../utils/addCapability";
import { getMultisigConfig, getTestMultisigConfig } from "../helpers/getMultisigConfig";

async function testAddMinter() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    // Define the mint limit
    const mintLimit = BigInt(1_000_000_000_000); // Adjust the mint limit as needed

    // Use the helper function to assign the MinterCap capability
    const result = await addCapability(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      MULTISIG.ADDRESS, // We authorize the publisher multisig as a minter
      "MinterCap",
      [mintLimit],
      { multisig: multisigConfig }
    );

    console.log("Transaction executed successfully:", result);
  } catch (error) {
    console.error("Error in testAddMinter:", error);
  }
}

testAddMinter();
