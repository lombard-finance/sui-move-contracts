import { SHARED_CONTROLLED_TREASURY, suiClient } from "../config";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { isBasculeCheckEnabled } from "../utils/isBasculeCheckEnabled";
import { toggleBasculeCheck } from "../utils/toggleBasculeCheck";

async function testBasculeCheck() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    // Toggle bascule check, if not set it will be initialized to true
    let toggleRes = await toggleBasculeCheck(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        { multisig: multisigConfig }
    )

    console.log("Transaction executed successfully:", toggleRes);
    await suiClient.waitForTransaction({ digest: toggleRes.digest });
    
    let basculeFlag = await isBasculeCheckEnabled(
        suiClient,
        SHARED_CONTROLLED_TREASURY
    )
    console.log("Bascule check enabled:", basculeFlag);

    // Toggle bascule check again
    toggleRes = await toggleBasculeCheck(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        { multisig: multisigConfig }
    )

    console.log("Transaction executed successfully:", toggleRes);
    await suiClient.waitForTransaction({ digest: toggleRes.digest });
    
    basculeFlag = await isBasculeCheckEnabled(
        suiClient,
        SHARED_CONTROLLED_TREASURY
    )
    console.log("Bascule check enabled:", basculeFlag);
  } catch (error) {
    console.error("Error in testBasculeCheck", error);
  }
}

testBasculeCheck();