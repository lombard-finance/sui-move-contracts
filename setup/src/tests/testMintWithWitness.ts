import {
    DENYLIST,
    MULTISIG,
  SHARED_CONTROLLED_TREASURY,
  suiClient,
  TEST_WITNESS_PACKAGE_ID,
} from "../config";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { addWitnessMintCapability } from "../utils/addWitnessMintCapability";
import { mintWithWitness } from "../utils/mintWithWitness";

async function testMintWithWitness(
) {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();
    
    //IMPORTANT: remove 0x from type name
    const witnessType = `${TEST_WITNESS_PACKAGE_ID}::test_witness::TestWitness`.substring(2);

    const capabilityResponse = await addWitnessMintCapability(suiClient, SHARED_CONTROLLED_TREASURY, witnessType, BigInt(1000), { multisig: multisigConfig });
    console.log("Transaction executed successfully:", capabilityResponse);

    await suiClient.waitForTransaction({ digest: capabilityResponse.digest });

    // Mint LBTC
    const mintResponse = await mintWithWitness(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      1000,
      MULTISIG.ADDRESS,
      DENYLIST,
      { multisig: multisigConfig },
    );

    console.log("Transaction executed successfully:", mintResponse);
    await suiClient.waitForTransaction({ digest: mintResponse.digest });

  } catch (error) {
    console.error("Error in testMintWithWitness:", error);
  }
}

testMintWithWitness();
