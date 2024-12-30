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
  "f2e73f7c0000000000000000000000000000000000000000000000000000000000aa36a70000000000000000000000000f90793a54e809bf708bd0fbcc63d311e3bb1be100000000000000000000000000000000000000000000000000000000000059d85a7c1a028fe68c29a449a6d8c329b9bdd39d8b925ba0f8abbde9fe398430fac40000000000000000000000000000000000000000000000000000000000000000";
const signatures =
  "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000040486dbc2308c3722c280a96a421e48d8c984bca9f48868e280ce1c8b1b08238cd671de8b18dd200053aef1727a80e83171805da0013c1b6d1ff28c5abfd73d7950000000000000000000000000000000000000000000000000000000000000040ae04a516c2a64625d865cf5cc9134aad909f20bed93ddf7ea8a440b6ea4bf9ae5b40bce9a00cfd157985ac61bbb56833e61b8e81018c5e1b52172f110e23e3fa0000000000000000000000000000000000000000000000000000000000000040e474e99a95f80a6f84fd659bcf5d158e027f06eed692f90a92c5b0154aec14c91a9555d2b3162125118e8b264c2b43e041f8cc9091ce45cc35d2fd8acf3fc295";
const hashHex = "f5638b4d4846c87bc4d9647a13af858401ac6b30469c61dd894eb05344ef8c6b";
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
      multisigConfig.users[0].keypair,
    );

    console.log("Transaction executed successfully:", claimResponse);
  } catch (error) {
    console.error("Error in testManualClaim:", error);
  }
}

testManualClaim(payloadHex, signatures);
