import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { suiClient, SHARED_CONSORTIUM, ONE_LBTC, DENYLIST, MULTISIG } from "../config"; 
import { burn } from "../utils/burn";
import { disableGlobalPause } from "../utils/disableGlobalPause";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";

async function testBurn() {
  try {
    // Retrieve our default multisig configuration
    //const signerConfig = getTestMultisigConfig();

    // Execute the mint and transfer logic
    console.log("pause")
    const result = await disableGlobalPause(
        "0xf9621182bf6af94142e81f5c268d1a959991df2766a5b0755c528b70e5b33531",
      {
        simpleSigner: Ed25519Keypair.fromSecretKey("yourprivkey"),
      }
    );

    console.log("done transaction executed successfully");
  } catch (error) {
    console.error("Error in val:", error);
  }
}

testBurn();
