import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import {
  generateMultiSigPublicKey,
  createMultisigSigner,
  executeMultisigTransaction,
} from "../helpers/multisigHelper";
import { treasury } from "../types/0x3048a09b0fe21d9e4c2a861b7cf453e34ef0689af08508b8a354591efa850c64";
import { LBTC_COIN_TYPE } from "../config";

// Define the participant structure for multisig
interface MultisigParticipant {
  keypair: Ed25519Keypair;
  weight: number;
}

// Define the multisig configuration type
interface MultisigConfig {
  users: MultisigParticipant[];
  threshold: number;
}

/**
 * Mints and transfers tokens in a single transaction using a multisig signer.
 *
 * @param client SuiClient instance for executing transactions.
 * @param treasuryAddress The shared Controlled Treasury object.
 * @param amount The amount of tokens to mint.
 * @param recipient The address of the recipient to transfer the minted tokens.
 * @param denylist The address of the denylist global object.
 * @param multisigConfig Multisig configuration containing participants and threshold.
 */
export async function mintAndTransfer(
  client: SuiClient,
  treasuryAddress: string,
  amount: number,
  recipient: string,
  denylist: string,
  txid: Uint8Array,
  idx: number,
  multisigConfig: MultisigConfig
): Promise<any> {
  const tx = new Transaction();

  const { users, threshold } = multisigConfig;

  // Generate MultiSigPublicKey
  const multiSigPublicKey = generateMultiSigPublicKey(
    users.map(({ keypair, weight }) => ({
      publicKey: keypair.getPublicKey(),
      weight,
    })),
    threshold
  );

  // Extract public keys and weights for the multisig configuration
  const publicKeys = users.map(({ keypair }) =>
    Array.from(keypair.getPublicKey().toSuiBytes())
  );
  const weights = users.map(({ weight }) => weight);
  tx.setGasBudget(5000000000);

  // Build the mint and transfer transaction
  treasury.builder.mintAndTransfer(
    tx,
    [
      tx.object(treasuryAddress), // Controlled Treasury object
      tx.pure.u64(amount), // Amount to mint
      tx.pure.address(recipient), // Recipient address
      tx.object(denylist), // Denylist global object
      tx.pure.vector("vector<u8>", publicKeys), // Public keys
      tx.pure.vector("u8", weights), // Weights
      tx.pure.u16(threshold), // Threshold
      tx.pure.vector("u8", Array.from(txid)), // Placeholder BTC deposit transaction ID
      tx.pure.u32(idx), // Placeholder BTC deposit index
    ],
    [LBTC_COIN_TYPE]
  );

  // Create a MultiSigSigner
  const signer = createMultisigSigner(
    multiSigPublicKey,
    users.map(({ keypair }) => keypair)
  );

  // Execute the transaction
  return await executeMultisigTransaction(client, tx, signer);
}
