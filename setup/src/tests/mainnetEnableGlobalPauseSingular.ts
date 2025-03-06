import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { suiClient, SHARED_CONSORTIUM, ONE_LBTC, DENYLIST, MULTISIG } from "../config"; 
import { burn } from "../utils/burn";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { Transaction } from "@mysten/sui/transactions";
import { treasury } from "../types/0x818430a456ff977f7320f78650d19801f90758d200a01dd3c2c679472c521357";
import { SuiClient } from "@mysten/sui/client";

async function testBurn() {
  try {
    // Execute
    console.log("pause")
    const result = await enableGlobalPause(
      suiClient,
        "0x1adadbca040f368abd554ac55e7c216ea6df2ff891fc647f037d66669661584a",
      {
        simpleSigner: Ed25519Keypair.fromSecretKey("yourprivkey"),
      }
    );

    console.log("done transaction executed successfully");
  } catch (error) {
    console.error("Error in val:", error);
  }
}


// Define the participant structure for multisig
interface MultisigParticipant {
    keypair: Ed25519Keypair;
    weight: number;
  }

// Adjusted `signerConfig` type
type SignerConfig =
  | { simpleSigner: Ed25519Keypair }
  | {
      multisig: {
        users: MultisigParticipant[];
        threshold: number;
      };
    };

export async function enableGlobalPause(
  client: SuiClient,
  treasuryAddress: string,
  signerConfig: SignerConfig
) {
    const tx = new Transaction();

    treasury.builder.enableGlobalPauseV2(
      tx,
      [
        tx.object(treasuryAddress), // Controlled Treasury object
        tx.object("0x403"), // Denylist global object
      ],
      ["0x3e8e9423d80e1774a7ca128fccd8bf5f1f7753be658c5e645929037f7c819040::lbtc::LBTC"]
    );

  // Determine the signer and execute the transaction
  if ("simpleSigner" in signerConfig) {
    // Simple signer
    return await client.signAndExecuteTransaction({
      transaction: tx,
      signer: signerConfig.simpleSigner,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });
  } else if ("multisig" in signerConfig) {
    // Multisig signer
    const { users, threshold } = signerConfig.multisig;

    const multiSigPublicKey = generateMultiSigPublicKey(
      users.map(({ keypair, weight }) => ({
        publicKey: keypair.getPublicKey(),
        weight,
      })),
      threshold
    );

    const signer = createMultisigSigner(
      multiSigPublicKey,
      users.map(({ keypair }) => keypair)
    );

    return await executeMultisigTransaction(client, tx, signer);
  } else {
    throw new Error(
      "Invalid signer configuration. Provide either `simpleSigner` or `multisig`."
    );
  }
}

testBurn();
