import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { treasury } from "../types/0x10a062a4f7b580600ccdaf5c993c0bdc9b0f114510331a14a962aebb4c53ef22";
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
 * Adds a capability (AdminCap, MinterCap, PauserCap) to a given address.
 *
 * @template T - The type of capability (e.g., "AdminCap", "MinterCap", "PauserCap").
 * @param client SuiClient instance for executing transactions.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param targetAddress The address to which the capability is being assigned.
 * @param capType The capability type name.
 * @param additionalArgs Additional arguments required for the capability (e.g., mint limit for MinterCap).
 * @param signerConfig Signer configuration object, either a simple signer or multisig participants and threshold.
 */
export async function addCapability<T>(
  client: SuiClient,
  treasuryAddress: string,
  targetAddress: string,
  capabilityType: CapabilityType,
  args: any[],
  signerConfig: SignerConfig
): Promise<any> {
  const tx = new Transaction();

  // Determine the type and build the corresponding capability
  let cap;
  if (capabilityType === "MinterCap") {
    const mintLimit = args[0] as bigint;
    cap = treasury.builder.newMinterCap(tx, [tx.pure.u64(mintLimit)]);
  } else if (capabilityType === "PauserCap") {
    cap = treasury.builder.newPauserCap(tx, []);
  } else if (capabilityType === "AdminCap") {
    cap = treasury.builder.newAdminCap(tx, []);
  } else {
    throw new Error(`Unsupported capability type: ${capabilityType}`);
  }

  treasury.builder.addCapability(
    tx,
    [tx.object(treasuryAddress), tx.pure.address(targetAddress), cap],
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
