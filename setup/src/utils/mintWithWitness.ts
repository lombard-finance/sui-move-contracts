import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
import { LBTC_COIN_TYPE, TEST_WITNESS_PACKAGE_ID } from "../config";

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
 * Mints and transfers tokens in a single transaction, authenticated by witness type.
 *
 * @param client SuiClient instance for executing transactions.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param amount The amount of tokens to mint.
 * @param recipient The address of the recipient to transfer the minted tokens.
 * @param denylist The address of the denylist global object.
 * @param signerConfig Signer configuration.
 */
export async function mintWithWitness(
  client: SuiClient,
  treasuryAddress: string,
  amount: number,
  recipient: string,
  denylist: string,
  signerConfig: SignerConfig
): Promise<any> {
  const tx = new Transaction();

  const [witness] = tx.moveCall({
    target: `${TEST_WITNESS_PACKAGE_ID}::test_witness::create_witness`,
    arguments: [],
  })

  treasury.builder.mintWithWitness(
      tx,
      [
        witness, // Witness
        tx.object(treasuryAddress), // Controlled Treasury object
        tx.pure.u64(amount), // Amount to mint
        tx.pure.address(recipient), // Recipient address
        tx.object(denylist), // Denylist global object
      ],
      [LBTC_COIN_TYPE, `${TEST_WITNESS_PACKAGE_ID}::test_witness::TestWitness`]
  )

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
}
