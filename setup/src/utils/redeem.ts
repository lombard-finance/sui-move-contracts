import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { LBTC_COIN_TYPE } from "../config";

import {
  treasury,
} from "../types/0x70fdf49de5fbc402f1ddb71208abd3c414348638f5b3f3cafb72ca2875efa33f";

/**
 * Redeem tokens from the ControlledTreasury<T>.
 * 
 * @param client SuiClient instance for submitting transactions
 * @param treasuryAddress The Object ID of the &mut ControlledTreasury<T>
 * @param coinObjectId The Object ID of the Coin<T> to redeem
 * @param scriptPubkeyHex A hex string representing the scriptPubkey
 * @param signer The Ed25519Keypair used for signing
 * @returns Transaction execution result
 */
export async function redeem(
  client: SuiClient,
  treasuryAddress: string,
  coinObjectId: string,
  scriptPubkeyHex: string,
  signer: Ed25519Keypair
): Promise<any> {

    const tx = new Transaction();
    const scriptPubkeyBytes = Array.from(Buffer.from(scriptPubkeyHex, "hex"));

    treasury.builder.redeem(
        tx,
        [
        tx.object(treasuryAddress),                    // &mut ControlledTreasury<T>
        tx.object(coinObjectId),                       // Coin<T>
        tx.pure.vector("u8", scriptPubkeyBytes),       // vector<u8>
        ],
        [LBTC_COIN_TYPE] // <T>
    );

    return await client.signAndExecuteTransaction({
        transaction: tx,
        signer,
        options: {
        showEffects: true,
        showObjectChanges: true,
        },
    });
}
