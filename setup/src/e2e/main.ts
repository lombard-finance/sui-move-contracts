/**
 * E2E Test: Mint and Transfer Flow
 *
 * This end-to-end test simulates the following real-world scenario:
 * 1. Lombard uses a multisig account (configured with two keypairs) to publish the smart contract.
 *    - This step creates a ControlledTreasury, and the multisig address is granted an AdminCap.
 * 2. Lombard, using the multisig AdminCap address, assigns the Minter role to itself.
 * 3. A user sends BTC to Lombard for verification (off-chain).
 * 4. Lombard verifies the user's BTC transfer manually (off-chain).
 * 5. If verified, Lombard mints the equivalent number of tokens and transfers them to the user's Sui address.
 *
 * This test uses helper functions (`addCapability` and `mintAndTransfer`) to encapsulate logic for assigning roles
 * and minting tokens.
 */

import {
  SHARED_CONTROLLED_TREASURY,
  suiClient,
  MULTISIG,
  ONE_LBTC,
  DENYLIST,
} from "../config";
import { addCapability } from "../utils/addCapability";
import { mintAndTransfer } from "../utils/mintAndTransfer";
import { hasCap } from "../utils/hasCap";
import { isGlobalPauseEnabled } from "../utils/isGlobalPauseEnabled";
import { getMultisigConfig } from "../helpers/getMultisigConfig";

const DUMMY_TXID = new TextEncoder().encode("abcd");
const DUMMY_IDX: number = 0;

async function e2eMintAndTransferTest() {
  try {
    /**
     * Step 1: Lombard uses a multisig account to publish the contract
     *
     * Documentation:
     * - Lombard's multisig account is configured with two keypairs (USER_1 and USER_2) from our configuration.
     * - Publishing the contract creates a ControlledTreasury object.
     * - The multisig address used for publishing automatically receives the AdminCap in the ControlledTreasury.
     */
    console.log("Step 1: Lombard publishes the smart contract...");

    // Retrieve our default multisig configuration
    const multisigConfig = getMultisigConfig();

    console.log(
      "Lombard multisig address:",
      MULTISIG.ADDRESS // Multisig address from configuration
    );

    /**
     * Step 2: Verify and Assign the Minter Role
     *
     * Documentation:
     * - Ensure the AdminCap is assigned to the multisig address.
     * - Assign the MinterCap if not already assigned.
     */

    console.log(`Checking AdminCap for ${MULTISIG.ADDRESS}...`);
    let hasAdminCap = await hasCap(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      MULTISIG.ADDRESS,
      "AdminCap"
    );

    if (!hasAdminCap) {
      throw new Error(
        "Multisig address does not have AdminCap. Cannot proceed."
      );
    }
    console.log("AdminCap verified.");

    console.log(`Checking MinterCap for ${MULTISIG.ADDRESS}...`);
    let hasMinterCap = await hasCap(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      MULTISIG.ADDRESS,
      "MinterCap"
    );

    if (!hasMinterCap) {
      console.log("MinterCap is missing. Assigning MinterCap...");

      const mintLimit = BigInt(1_000_000_000_000); // Define a mint limit for testing purposes

      const addMinterResult = await addCapability(
        suiClient,
        SHARED_CONTROLLED_TREASURY, // Controlled Treasury object
        MULTISIG.ADDRESS, // Lombard's multisig address
        "MinterCap",
        [mintLimit],
        { multisig: multisigConfig }
      );

      console.log("Minter role assigned successfully:", addMinterResult);
    } else {
      console.log("MinterCap already assigned.");
    }

    /**
     * Step 3: User sends BTC
     *
     * Documentation:
     * - A user sends BTC to Lombard for verification.
     * - This step is represented by the BTC amount and the user's Sui address.
     */
    console.log("Step 3: User sends BTC for verification...");
    const userAddress =
      "0xc9c807f80bfe5fc4471e255b3202b7f5c4b55c505e23517d53a8d8a53461e012";
    const BTC_AMOUNT = 1; // Mocking the BTC amount sent by the user

    /**
     * Step 4: Lombard checks and verifies the BTC transaction
     *
     * Documentation:
     * - Lombard manually verifies the BTC transfer off-chain.
     * - Verification includes checking the validity of the BTC transaction details.
     */
    console.log("Step 4: Lombard checks and verifies the BTC transaction...");
    const isVerified = true; // Mocking the verification as successful for the test.

    if (!isVerified) {
      throw new Error(
        "Verification failed. Cannot proceed with mint and transfer."
      );
    }

    console.log("BTC transaction verified successfully.");

    /**
     * Step 5: Check Global Pause Status
     *
     * Documentation:
     * - Before minting tokens, Lombard checks if the global pause is enabled in the Denylist.
     * - If the pause is enabled, the process stops with a message.
     * - If the pause is disabled, the process proceeds to mint and transfer tokens.
     */
    console.log("Step 5: Checking global pause status...");
    const isPaused = await isGlobalPauseEnabled(suiClient);

    if (isPaused) {
      console.log(
        "Global pause is enabled. Minting and transfer operation aborted."
      );
      return;
    }

    console.log(
      "Global pause is disabled. Proceeding to mint and transfer tokens..."
    );

    /**
     * Step 6: Mint and Transfer
     *
     * Documentation:
     * - After successful verification and confirmation of no global pause, Lombard mints LBTC tokens.
     * - Uses the `mintAndTransfer` helper function to handle the operation.
     */
    console.log("Step 6: Lombard mints and transfers LBTC tokens...");

    const mintTransferResult = await mintAndTransfer(
      suiClient,
      SHARED_CONTROLLED_TREASURY, // Controlled Treasury object
      ONE_LBTC * BTC_AMOUNT, // Amount to mint (1 LBTC per BTC in this case)
      userAddress, // User's Sui address
      DENYLIST, // Denylist global object
      DUMMY_TXID, // Placeholder BTC deposit transaction ID
      DUMMY_IDX, // Placeholder BTC deposit index
      multisigConfig // Multisig configuration
    );

    console.log(
      "Transaction executed successfully. Result:",
      mintTransferResult
    );

    /**
     * Final Step: Log successful execution
     */
    console.log("E2E Test: Mint and Transfer Flow completed successfully.");
  } catch (error) {
    console.error("Error in E2E Test: Mint and Transfer Flow:", error);
  }
}

e2eMintAndTransferTest();
