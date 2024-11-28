import { hasCap } from "../utils/hasCap";
import { suiClient, SHARED_CONTROLLED_TREASURY, MULTISIG } from "../config";

async function testCapabilities() {
  try {
    const address = MULTISIG.ADDRESS;

    console.log(`Checking AdminCap for ${address}...`);
    const hasAdminCap = await hasCap(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      address,
      "AdminCap"
    );
    console.log(`AdminCap: ${hasAdminCap}`);

    console.log(`Checking MinterCap for ${address}...`);
    const hasMinterCap = await hasCap(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      address,
      "MinterCap"
    );
    console.log(`MinterCap: ${hasMinterCap}`);

    console.log(`Checking PauserCap for ${address}...`);
    const hasPauserCap = await hasCap(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      address,
      "PauserCap"
    );
    console.log(`PauserCap: ${hasPauserCap}`);
  } catch (error) {
    console.error("Error checking capabilities:", error);
  }
}

testCapabilities();
