import {
  SHARED_CONTROLLED_TREASURY,
  suiClient,
  LBTC_COIN_TYPE,
  DENYLIST,
} from "../config";
import {
  executeMultisigTransaction,
  generateMultiSigPublicKey,
  createMultisigSigner,
} from "../helpers/multisigHelper";
import { Transaction } from "@mysten/sui/transactions";
import { treasury } from "../types/0x70fdf49de5fbc402f1ddb71208abd3c414348638f5b3f3cafb72ca2875efa33f";
import { getMultisigConfig, getTestMultisigConfig } from "../helpers/getMultisigConfig";

async function testEnableGlobalPause() {
  try {
    // Retrieve the multisig configuration
    const multisigConfig = getTestMultisigConfig();

    // Generate MultiSigPublicKey
    const multiSigPublicKey = generateMultiSigPublicKey(
      multisigConfig.users.map(({ keypair, weight }) => ({
        publicKey: keypair.getPublicKey(),
        weight,
      })),
      multisigConfig.threshold
    );

    // Create a MultiSigSigner
    const signer = createMultisigSigner(
      multiSigPublicKey,
      multisigConfig.users.map(({ keypair }) => keypair)
    );

    // Extract public keys and weights for the global pause configuration
    const publicKeys = multisigConfig.users.map(({ keypair }) =>
      Array.from(keypair.getPublicKey().toSuiBytes())
    );
    const weights = multisigConfig.users.map(({ weight }) => weight);
    console.log("Public keys:", publicKeys);
    // Prepare the transaction to enable global pause
    const tx = new Transaction();

    treasury.builder.enableGlobalPause(
      tx,
      [
        tx.object(SHARED_CONTROLLED_TREASURY), // Controlled Treasury object
        tx.object(DENYLIST), // Denylist global object
        tx.pure.vector("vector<u8>", publicKeys), // Public keys
        tx.pure.vector("u8", weights), // Weights
        tx.pure.u16(multisigConfig.threshold), // Threshold
      ],
      [LBTC_COIN_TYPE]
    );

    // Execute the transaction using the multisig signer
    const result = await executeMultisigTransaction(suiClient, tx, signer);

    console.log("Transaction result:", result);
  } catch (error) {
    console.error("Error in testEnableGlobalPause:", error);
  }
}

testEnableGlobalPause();
