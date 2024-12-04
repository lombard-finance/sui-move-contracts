import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { treasury } from "../types/0x0bf1f46efc094312ecf58f6941263ad6340eff64b5292b21b2591f04c11978ad";
import { LBTC_COIN_TYPE, PACKAGE_ID } from "../config";

// Define supported capabilities with their corresponding types
type CapabilityType = "AdminCap" | "MinterCap" | "PauserCap";

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

/**
 * Removes a capability (AdminCap, MinterCap, PauserCap) from a given address.
 *
 * @template T - The type of capability (e.g., "AdminCap", "MinterCap", "PauserCap").
 * @param client SuiClient instance for executing transactions.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param targetAddress The address from which the capability is being removed.
 * @param capType The capability type name ("AdminCap", "MinterCap", "PauserCap").
 * @param signerConfig Signer configuration object, either a simple signer or multisig participants and threshold.
 */
export async function removeCapability<T>(
  client: SuiClient,
  treasuryAddress: string,
  targetAddress: string,
  capabilityType: CapabilityType,
  signerConfig: SignerConfig
): Promise<any> {
  const tx = new Transaction();

  // Remove the capability from the target address
  treasury.builder.removeCapability(
    tx,
    [tx.object(treasuryAddress), tx.pure.address(targetAddress)],
    [LBTC_COIN_TYPE, `${PACKAGE_ID}::treasury::${capabilityType}`]
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
