import { SuiClient } from "@mysten/sui/client";
import { treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
import { LBTC_COIN_TYPE } from "../config";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { createMultisigSigner, executeMultisigTransaction, generateMultiSigPublicKey } from "../helpers/multisigHelper";

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
 * Add a witness mint capability.
 */
export async function addWitnessMintCapability(
  client: SuiClient,
  treasuryAddress: string,
  owner: string,
  mintLimit: bigint,
  signerConfig: SignerConfig
): Promise<any> {
  try {

    const tx = new Transaction();

    const cap = treasury.builder.newMinterCap(tx, [tx.pure.u64(mintLimit)]);    
    await treasury.builder.addWitnessMintCapability(
    tx,
    [
        tx.object(treasuryAddress), 
        tx.pure.string(owner), 
        cap
    ],
    [LBTC_COIN_TYPE]
    );

    tx.setGasBudget(5000000000);

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
  } catch (error) {
    console.error(`Error adding mint capability for ${owner}:`, error);
    throw error;
  }
}
