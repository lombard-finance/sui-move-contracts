import {
  SHARED_CONSORTIUM,
  SHARED_CONTROLLED_TREASURY,
  suiClient,
} from "../config";
import { manualClaim } from "../utils/manualClaim";
import { getMintActionBytes } from "../utils/getMintActionBytes";
import { setMintActionBytes } from "../utils/setMintActionBytes";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { isPayloadUsed } from "../utils/isPayloadUsed";
import { isBasculeCheckEnabled } from "../utils/isBasculeCheckEnabled";
import { toggleBasculeCheck } from "../utils/toggleBasculeCheck";
import { addInitialValidatorSet } from "../utils/addInitialValidatorSet";
import { getChainId } from "../utils/getChainId";
import { setChainId } from "../utils/setChainId";

const initValsetPayload =
  "4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
const payloadHex =
  "f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
const signatures =
  "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa41698";
const hashHex = "9eef84fdedfb470e333f1db71694b72686d6e7a5fab508384c68c176b7ee46f0";
const actionBytes = 4075241340;
const chainId = "452312848583266388373324160190187140051835877600158453279131187531808459402";

async function testManualClaim(
  payload: string,
  proof: string,
) {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    // Set the initial validator set for the consortium
    console.log("Setting the first validator set...");
    const valsetPayload = Array.from(Buffer.from(initValsetPayload, "hex"));

    const addValidatorSetResult = await addInitialValidatorSet(
      suiClient,
      SHARED_CONSORTIUM, // Consortium object
      valsetPayload,
      { multisig: multisigConfig }
    );

    console.log("Validators set successfully:", addValidatorSetResult);

    await suiClient.waitForTransaction({ digest: addValidatorSetResult.digest });

    // Check if the mint action bytes are set
    const actionBytesRes = await getMintActionBytes(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
    );

    console.log("Action bytes:", actionBytesRes);

    if (actionBytesRes === undefined) {
      const setActionBytesResponse = await setMintActionBytes(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        actionBytes,
        { multisig: multisigConfig },
      )

      console.log("Transaction executed successfully:", setActionBytesResponse);
      await suiClient.waitForTransaction({ digest: setActionBytesResponse.digest });
    }

    // Check if chain_id is set
    const chainIdRes = await getChainId(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
    )

    console.log("Chain ID:", chainIdRes);
    
    if (chainIdRes != chainId) {
      const setChainIdRes = await setChainId(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        chainId,
        { multisig: multisigConfig },
      )

      console.log("Transaction executed successfully:", setChainIdRes);
      await suiClient.waitForTransaction({ digest: setChainIdRes.digest });
    }

    // Set bascule check and disable it for the tests to go through
    const basculeCheckEnabled = await isBasculeCheckEnabled(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
    );

    if (basculeCheckEnabled == undefined) {
      // set bascule check
      const basculeCheckRes = await toggleBasculeCheck(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        { multisig: multisigConfig },
      )
      await suiClient.waitForTransaction({ digest: basculeCheckRes.digest });

      // toggle bascule check to become false
      const basculeCheckDisableRes = await toggleBasculeCheck(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        { multisig: multisigConfig },
      )
      await suiClient.waitForTransaction({ digest: basculeCheckDisableRes.digest });
    } else if (basculeCheckEnabled) {
      const basculeCheckRes = await toggleBasculeCheck(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        { multisig: multisigConfig },
      )

      console.log("Transaction executed successfully:", basculeCheckRes);
      await suiClient.waitForTransaction({ digest: basculeCheckRes.digest });
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

    // Manual claim the LBTC
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
