import { SHARED_CONTROLLED_TREASURY, suiClient } from "../config";
import { addCapability } from "../utils/addCapability";
import { getMultisigConfig } from "../helpers/getMultisigConfig";

async function testAddAdmin() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getMultisigConfig();

    let result = await addCapability(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      "0xc9c807f80bfe5fc4471e255b3202b7f5c4b55c505e23517d53a8d8a53461e012", // Address to authorize
      "AdminCap",
      [],
      {
        multisig: multisigConfig,
      }
    );

    console.log("Transaction executed successfully:", result);
  } catch (error) {
    console.error("Error in testAssignMinter:", error);
  }
}

testAddAdmin();
