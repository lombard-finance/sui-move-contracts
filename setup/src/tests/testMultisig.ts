import { suiClient, MULTISIG } from "../config";
import { Transaction } from "@mysten/sui/transactions";
import { _0x1 } from "@typemove/sui/builtin";
import { getSignerKeypair } from "../helpers/getSigner";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";

async function main() {
  try {
    // Initialize keypairs from the MULTISIG configuration
    const keypair1 = getSignerKeypair(MULTISIG.USER_1.SK);
    const keypair2 = getSignerKeypair(MULTISIG.USER_2.SK);

    // Prepare the multisig configuration
    const users = [
      { keypair: keypair1, weight: MULTISIG.USER_1.WEIGHT },
      { keypair: keypair2, weight: MULTISIG.USER_2.WEIGHT },
    ];

    // Generate multisig public key
    const multiSigPublicKey = generateMultiSigPublicKey(
      users.map(({ keypair, weight }) => ({
        publicKey: keypair.getPublicKey(),
        weight,
      })),
      MULTISIG.THRESHOLD
    );

    console.log(
      "Generated multisig address:",
      multiSigPublicKey.toSuiAddress()
    );

    // Create a MultiSigSigner
    const signer = createMultisigSigner(
      multiSigPublicKey,
      users.map(({ keypair }) => keypair)
    );

    // Build and execute a transaction
    const tx = new Transaction();
    _0x1.string$.builder.utf8(tx, [tx.pure.string("Hello, world!")]);

    const result = await executeMultisigTransaction(suiClient, tx, signer);

    console.log("Transaction result:", result);
    return result;
  } catch (error) {
    console.error("Error: ", error);
  }
}

main();
