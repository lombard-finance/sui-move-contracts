import { listCapabilities } from "../utils/listCapabilities";
import { suiClient, SHARED_CONTROLLED_TREASURY, MULTISIG } from "../config";

async function testListCapabilities() {
  try {
    const address = MULTISIG.ADDRESS;

    console.log(`Listing capabilities for address: ${address}...`);

    const capabilities = await listCapabilities(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      address
    );

    console.log(`Capabilities for ${address}:`, capabilities);
  } catch (error) {
    console.error("Error listing capabilities:", error);
  }
}

testListCapabilities();
