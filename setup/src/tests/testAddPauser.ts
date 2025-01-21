import { SHARED_CONTROLLED_TREASURY, suiClient, MULTISIG } from "../config";
import { addCapability } from "../utils/addCapability";
import { getMultisigConfig, getTestMultisigConfig } from "../helpers/getMultisigConfig";

async function testAddPauser() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    // Use the helper function to assign the PauserCap capability
    const result = await addCapability(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      MULTISIG.ADDRESS, // Multisig address to authorize as pauser
      "PauserCap",
      [], // No additional arguments are needed for PauserCap
      { multisig: multisigConfig }
    );

    console.log("Transaction executed successfully:", result);
  } catch (error) {
    console.error("Error in testAddPauser:", error);
  }
}

testAddPauser();
