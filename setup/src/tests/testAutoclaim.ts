import {
    MULTISIG,
  SHARED_CONSORTIUM,
  SHARED_CONTROLLED_TREASURY,
  suiClient,
} from "../config";
import { getMintActionBytes } from "../utils/getMintActionBytes";
import { setMintActionBytes } from "../utils/setMintActionBytes";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { isPayloadUsed } from "../utils/isPayloadUsed";
import { isBasculeCheckEnabled } from "../utils/isBasculeCheckEnabled";
import { toggleBasculeCheck } from "../utils/toggleBasculeCheck";
import { listCapabilities } from "../utils/listCapabilities";
import { addCapability } from "../utils/addCapability";
import { addInitialValidatorSet } from "../utils/addInitialValidatorSet";
import { getChainId } from "../utils/getChainId";
import { setChainId } from "../utils/setChainId";
import { setFeeActionBytes } from "../utils/setFeeActionBytes";
import { getFeeActionBytes } from "../utils/getFeeActionBytes";
import { autoClaim } from "../utils/autoClaim";
import { getMintFee } from "../utils/getMintFee";
import { setMintFee } from "../utils/setMintFee";

const initValsetPayload =
  "4aab1d6f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004104ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0d67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
const payloadHex =
  "f2e73f7c0100000000000000000000000000000000000000000000000000000035834a8a0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
const signatures =
  "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000405b1e71e6cea98724038d2a7a63152c8b423b61908647fd7f4c803380b4fc653c5530ccca1c165dd6877d290a3ca90e30ee9048344fcb63ad52cd4b9bcfa41698";
const hashHex = "9eef84fdedfb470e333f1db71694b72686d6e7a5fab508384c68c176b7ee46f0";
const feePayload = "8175ca940000000000000000000000000000000000000000000000000000000005f5e0ff00000000000000000000000000000000000000000000000000000000ffffffff";
const userSignature = "5f4b94373b8e7eba20cb61584b14bab251ec354470a83541e39e18ccb6853c1279a9c206bf23fcb0bf49d10f8d0888ab678599c2da1bf48ec9bb565d7be3703e1c";
const userPubkey = "049d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f0464b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb";

const mintActionBytes = 4075241340;
const feeActionBytes = 2171980436;
const chainId = "452312848583266388373324160190187140051835877600158453279131187531808459402";

async function testAutoclaim(
  payload: string,
  proof: string,
) {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    const address = MULTISIG.ADDRESS;
    
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

    // Check if the address has the OperatorCap capability to set the mint_fee
    // And the ClaimerCap to claim LBTC on behalf of the user
    const capabilities = await listCapabilities(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        address
    );
    
    console.log(`Capabilities for ${address}:`, capabilities);

    if (!capabilities.includes("OperatorCap")) {
        // Use the helper function to assign the OperatorCap capability
        const addCapRes = await addCapability(
            suiClient,
            SHARED_CONTROLLED_TREASURY,
            address, // Multisig address to authorize as pauser
            "OperatorCap",
            [], // No additional arguments are needed for PauserCap
            { multisig: multisigConfig }
        );

        console.log("Transaction executed successfully:", addCapRes);
        await suiClient.waitForTransaction({ digest: addCapRes.digest });
    }

    if (!capabilities.includes("ClaimerCap")) {
      // Use the helper function to assign the OperatorCap capability
      const addCapRes = await addCapability(
          suiClient,
          SHARED_CONTROLLED_TREASURY,
          address, // Multisig address to authorize as pauser
          "ClaimerCap",
          [], // No additional arguments are needed for PauserCap
          { multisig: multisigConfig }
      );

      console.log("Transaction executed successfully:", addCapRes);
      await suiClient.waitForTransaction({ digest: addCapRes.digest });
    }

    // Set the mint_fee to 1000
    const mintFeeRes = await getMintFee(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
    );

    console.log("Mint Fee:", mintFeeRes);

    if (mintFeeRes === undefined) {
      const setMintFeeResponse = await setMintFee(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        1000,
        { multisig: multisigConfig },
      )

      console.log("Transaction executed successfully:", setMintFeeResponse);
      await suiClient.waitForTransaction({ digest: setMintFeeResponse.digest });
    }

    // Check if the fee action bytes are set
    const feeActionBytesRes = await getFeeActionBytes(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
    );

    console.log("Fee Action bytes:", feeActionBytesRes);

    if (feeActionBytesRes === undefined) {
      const setFeeActionBytesResponse = await setFeeActionBytes(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        feeActionBytes,
        { multisig: multisigConfig },
      )

      console.log("Transaction executed successfully:", setFeeActionBytesResponse);
      await suiClient.waitForTransaction({ digest: setFeeActionBytesResponse.digest });
    }

    // Check if the mint action bytes are set
    const actionBytesRes = await getMintActionBytes(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
    );

    console.log("Mint Action bytes:", actionBytesRes);

    if (actionBytesRes === undefined) {
      const setActionBytesResponse = await setMintActionBytes(
        suiClient,
        SHARED_CONTROLLED_TREASURY,
        mintActionBytes,
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

    // Check if the bascule check is enabled
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

    // Claim the LBTC for behalf of the user with the mint_with_fee
    console.log("Claiming the LBTC for the user...");
    const claimResponse = await autoClaim(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      SHARED_CONSORTIUM,
      payload,
      proof,
      feePayload,
      userSignature,
      userPubkey,
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
    console.error("Error in testAutoClaim:", error);
  }
}

testAutoclaim(payloadHex, signatures);
