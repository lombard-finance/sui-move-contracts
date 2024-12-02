import { Transaction } from "@mysten/sui/transactions";
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Ed25519PublicKey } from "@mysten/sui/keypairs/ed25519";
import { treasury } from "../types/0x6bdf953e819eaa24deab01a2d1c2ac74b530d37c79560d289d71a7fc5394d10d";
import * as fs from 'fs';

const args = process.argv.slice(2);
const packageId = args[0];
const command = args[1];

const tx = new Transaction();
const treasuryAddress = args[2];
const multisigAddress = args[3];

if (command === "addAdmin") {
    const address = args[4];
    const cap = treasury.builder.newAdminCap(tx, []);
    console.log(treasuryAddress);
    treasury.builder.addCapability(
        tx,
        [tx.object(treasuryAddress), tx.pure.address(address), cap],
        [`${packageId}::lbtc::LBTC`, `${packageId}::treasury::AdminCap`]
    );
} else if (command === "addMinter") {
    const address = args[4];
    const limit = parseInt(args[5], 10);
    const cap = treasury.builder.newMinterCap(tx, [tx.pure.u64(BigInt(limit))]);
    treasury.builder.addCapability(
        tx,
        [tx.object(treasuryAddress), tx.pure.address(address), cap],
        [`${packageId}::lbtc::LBTC`, `${packageId}::treasury::MinterCap`]
    );
} else if (command === "addPauser") {
    const address = args[4];
    const cap = treasury.builder.newPauserCap(tx, []);
    treasury.builder.addCapability(
        tx,
        [tx.object(treasuryAddress), tx.pure.address(address), cap],
        [`${packageId}::lbtc::LBTC`, `${packageId}::treasury::PauserCap`]
    );
} else if (command === "disableGlobalPause") {
    const adminFile = args[4];
    const contents = fs.readFileSync('admin_multisig_info','utf8');
    const object = JSON.parse(contents);
    const publicKeys = object.multisig.map((key) => {
        const bytes = Buffer.from(key.publicBase64Key, 'base64');
        return new Ed25519PublicKey(bytes.slice(1)).toSuiBytes();
    });
    const weights = object.multisig.map((key) => {
        return key.weight;
    });
    const threshold = object.threshold;
    treasury.builder.disableGlobalPause(
        tx,
        [
            tx.object(treasuryAddress), // Controlled Treasury object
            tx.object("0x403"), // Denylist global object
            tx.pure.vector("vector<u8>", publicKeys), // Public keys
            tx.pure.vector("u8", weights), // Weights
            tx.pure.u16(threshold), // Threshold
        ],
        [`${packageId}::lbtc::LBTC`]
    );
} else if (command === "enableGlobalPause") {
    const adminFile = args[4];
    const contents = fs.readFileSync('admin_multisig_info','utf8');
    const object = JSON.parse(contents);
    const publicKeys = object.multisig.map((key) => {
        const bytes = Buffer.from(key.publicBase64Key, 'base64');
        return new Ed25519PublicKey(bytes.slice(1)).toSuiBytes();
    });
    const weights = object.multisig.map((key) => {
        return key.weight;
    });
    const threshold = object.threshold;
    treasury.builder.enableGlobalPause(
        tx,
        [
            tx.object(treasuryAddress), // Controlled Treasury object
            tx.object("0x403"), // Denylist global object
            tx.pure.vector("vector<u8>", publicKeys), // Public keys
            tx.pure.vector("u8", weights), // Weights
            tx.pure.u16(threshold), // Threshold
        ],
        [`${packageId}::lbtc::LBTC`]
    );
} else if (command === "mintAndTransfer") {
    const address = args[4];
    const amount = args[5];
    const adminFile = args[6];
    const contents = fs.readFileSync('admin_multisig_info','utf8');
    const object = JSON.parse(contents);
    const publicKeys = object.multisig.map((key) => {
        const bytes = Buffer.from(key.publicBase64Key, 'base64');
        return new Ed25519PublicKey(bytes.slice(1)).toSuiBytes();
    });
    const weights = object.multisig.map((key) => {
        return key.weight;
    });
    const threshold = object.threshold;
    treasury.builder.mintAndTransfer(
        tx,
        [
            tx.object(treasuryAddress), // Controlled Treasury object
            tx.pure.u64(amount), // Amount to mint
            tx.pure.address(address), // Recipient address
            tx.object("0x403"), // Denylist global object
            tx.pure.vector("vector<u8>", publicKeys), // Public keys
            tx.pure.vector("u8", weights), // Weights
            tx.pure.u16(threshold), // Threshold
        ],
        [`${packageId}::lbtc::LBTC`]
    );
} else if (command === "removeMinter") {
    const address = args[4];
    treasury.builder.removeCapability(
        tx,
        [tx.object(treasuryAddress), tx.pure.address(address)],
        [`${packageId}::lbtc::LBTC`, `${packageId}::treasury::MinterCap`]
    );
} else if (command === "removePauser") {
    const address = args[4];
    treasury.builder.removeCapability(
        tx,
        [tx.object(treasuryAddress), tx.pure.address(address)],
        [`${packageId}::lbtc::LBTC`, `${packageId}::treasury::MinterCap`]
    );
}

// use getFullnodeUrl to define Devnet RPC location
const rpcUrl = getFullnodeUrl('testnet');
 
// create a client connected to devnet
const client = new SuiClient({ url: rpcUrl });

tx.setSender(multisigAddress);
tx.setGasBudget(500000000);

tx.build({ client }).then(bytes => {
    const base64String = Buffer.from(bytes).toString('base64');
    console.log(base64String);
    fs.writeFileSync('tx_bytes', base64String);
});
