import {
  SHARED_CONSORTIUM,
  suiClient,
} from "../config";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { addValidatorSet } from "../utils/addValidatorSet";
import { validateAndStorePayload } from "../utils/validateAndStorePayload";
import { isPayloadUsed } from "../utils/isPayloadUsed";

const signers = [
  "027378e006183e9a5de1537b788aa9d107c67189cd358efc1d53a5642dc0a37311",
  "03ac2fec1927f210f2056d13c9ba0706666f333ed821d2032672d71acf47677eae",
  "02b56056d0cb993765f963aeb530f7687c44d875bd34e38edc719bb117227901c5",
];

const payloadHex = "f2e73f7c0000000000000000000000000000000000000000000000000000000000aa36a70000000000000000000000000f90793a54e809bf708bd0fbcc63d311e3bb1be100000000000000000000000000000000000000000000000000000000000059d85a7c1a028fe68c29a449a6d8c329b9bdd39d8b925ba0f8abbde9fe398430fac40000000000000000000000000000000000000000000000000000000000000000";
const signatures = "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000040486dbc2308c3722c280a96a421e48d8c984bca9f48868e280ce1c8b1b08238cd671de8b18dd200053aef1727a80e83171805da0013c1b6d1ff28c5abfd73d7950000000000000000000000000000000000000000000000000000000000000040ae04a516c2a64625d865cf5cc9134aad909f20bed93ddf7ea8a440b6ea4bf9ae5b40bce9a00cfd157985ac61bbb56833e61b8e81018c5e1b52172f110e23e3fa0000000000000000000000000000000000000000000000000000000000000040e474e99a95f80a6f84fd659bcf5d158e027f06eed692f90a92c5b0154aec14c91a9555d2b3162125118e8b264c2b43e041f8cc9091ce45cc35d2fd8acf3fc295";
const hashHex = "f5638b4d4846c87bc4d9647a13af858401ac6b30469c61dd894eb05344ef8c6b";


async function e2eValidateAndStorePayload() {
  const multisigConfig = getTestMultisigConfig();

  try {

    // Step1: Set the initial validator set
    console.log("Setting the next validator set...");
    const validatorPks = signers.map((signer) => {
      return Array.from(Buffer.from(signer, "hex"));
    });

    const addValidatorSetResult = await addValidatorSet(
      suiClient,
      SHARED_CONSORTIUM, // Consortium object
      validatorPks,
      { multisig: multisigConfig }
    );

    console.log("Validators set successfully:", addValidatorSetResult);

    await suiClient.waitForTransaction({ digest: addValidatorSetResult.digest });

    // Step2: Validate and store the payload
    // In a real case scenario, this step will get executed by the smart contract in the claim function.
    // For testing purposes we are executing this flow from client.
    console.log("Validating and storing the payload...");
    
    const payload = Array.from(Buffer.from(payloadHex, "hex"));
    const proof = Array.from(Buffer.from(signatures, "hex"));

    const validateAndStorePayloadResult = await validateAndStorePayload(
      suiClient,
      SHARED_CONSORTIUM, // Consortium object
      payload,
      proof,
      { multisig: multisigConfig }
    );

    console.log("Payload validated and stored successfully:", validateAndStorePayloadResult);
    await suiClient.waitForTransaction({ digest: validateAndStorePayloadResult.digest });

    // Step3: Check if the payload is stored
    console.log("Checking if the payload is stored...");
    const isPayloadUsedResult = await isPayloadUsed(
      suiClient,
      SHARED_CONSORTIUM, // Consortium object
      hashHex,
      // can be anyone
      multisigConfig.users[0].keypair.toSuiAddress()
    );

    console.log("Payload stored:", isPayloadUsedResult);
  } catch (error) {
    console.error(
      "Error in E2E Test: Validate and Store Payoload Flow:",
      error
    );
  }
}

e2eValidateAndStorePayload();