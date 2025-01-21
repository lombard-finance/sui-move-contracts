import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  SHARED_CONSORTIUM,
  SHARED_CONTROLLED_TREASURY,
  suiClient,
} from "../config";
import { manualClaim } from "../utils/manualClaim";
import { getActionBytes } from "../utils/getActionBytes";
import { setActionBytes } from "../utils/setActionBytes";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { isPayloadUsed } from "../utils/isPayloadUsed";

const payloadHex =
  "f2e73f7c000000000000000000000000000000000000000000000000000000000000000953ac220c4c7f0e8ac4266b54779f8a5e772705390a43f4ea2a59cd7c10305e4d0000000000000000000000000000000000000000000000000000000005f5e1008d3427b7fa9f07adb76208188930d49341246cef989a20b45a4619fd2ba6810a0000000000000000000000000000000000000000000000000000000000000000";
const signatures =
  "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000405ac3b079f374485585c941449e67e4fd33217c4a5579dc61f9d7b2704a00820c29d588f2981f7a2a429cf2df97ed1ead40f37d1c4fc45257ee37592861b4957000000000000000000000000000000000000000000000000000000000000000404588a44b8309f6602515e4aa5e6868b4b8131bea1a3d7e137049113b31c2ea384a3cea2e1ce7ecdd30cf6caabd22282dc65324de0c14e857c4850c981935a0260000000000000000000000000000000000000000000000000000000000000040b31e60fd4802a7d476dc9a75b280182c718ffd8a0ddf4630b4a91b4450a2c3ca5f9f34229c2c9da7a86881fefe7f41ffcafd96b6157da2729f59c4856e2d437a";
const hashHex = "89cf3b8247cc333fcf84109cee811a81d2ed1c14af1701b7716cbb0611e51979";
const actionBytes = 4075241340;

async function testManualClaim(
  payload: string,
  proof: string,
) {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    const actionBytesRes = await getActionBytes(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
    );

    console.log("Action bytes:", actionBytesRes);

    if (actionBytesRes === undefined) {
      const setActionBytesResponse = await setActionBytes(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        actionBytes,
        { multisig: multisigConfig },
      )

      console.log("Transaction executed successfully:", setActionBytesResponse);
      await suiClient.waitForTransaction({ digest: setActionBytesResponse.digest });
    }

    const isPayloadUsedFlag = await isPayloadUsed(
      suiClient,
      SHARED_CONSORTIUM,
      hashHex,
      multisigConfig.users[0].keypair.toSuiAddress(),
    )
    console.log("Is payload used:", isPayloadUsedFlag);

    if (isPayloadUsedFlag) {
      throw new Error("Payload already used");
    }

    // Manual claim the LBTC, the payload's `to` must be the same address with the sender of the transaction
    const claimResponse = await manualClaim(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      SHARED_CONSORTIUM,
      payload,
      proof,
      { multisig: multisigConfig },
    );

    console.log("Transaction executed successfully:", claimResponse);
    await suiClient.waitForTransaction({ digest: claimResponse.digest });

    const isPayloadUsedFlag2 = await isPayloadUsed(
      suiClient,
      SHARED_CONSORTIUM,
      hashHex,
      multisigConfig.users[0].keypair.toSuiAddress(),
    )
    console.log("Is payload used:", isPayloadUsedFlag2);

  } catch (error) {
    console.error("Error in testManualClaim:", error);
  }
}

testManualClaim(payloadHex, signatures);
