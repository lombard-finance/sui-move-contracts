import { removeCapability } from "../utils/removeCapability";
import { suiClient, SHARED_CONTROLLED_TREASURY, MULTISIG } from "../config";
import { getMultisigConfig } from "../helpers/getMultisigConfig";

async function testRemoveMinter() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getMultisigConfig();

    const result = await removeCapability(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      MULTISIG.ADDRESS, // Address to remove capability from
      "MinterCap", // Capability type to remove
      { multisig: multisigConfig }
    );

    console.log("Capability removed successfully. Result:", result);
  } catch (error) {
    console.error("Error removing capability:", error);
  }
}

testRemoveMinter();
