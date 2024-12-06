import TransportNodeHid from "@ledgerhq/hw-transport-node-hid";
import Sui from "@mysten/ledgerjs-hw-app-sui";
import { blake2b } from "@noble/hashes/blake2b";
import { messageWithIntent } from "@mysten/sui/cryptography";

async function signAndVerifyMessage() {
  try {
    // Establish connection to Ledger device
    const devices = await TransportNodeHid.list();
    if (devices.length === 0) {
      throw new Error("No Ledger devices found");
    }

    const transport = await TransportNodeHid.open(devices[0].path);
    const sui = new Sui(transport);

    // Fetch public key for verification later
    const bip32Path = "m/44'/784'/0'/0'/0'";
    const { publicKey } = await sui.getPublicKey(bip32Path, true);

    // Define the message to sign
    const message = new TextEncoder().encode("Spok");

    // Add the intent message to the payload
    const intentMessage = messageWithIntent("PersonalMessage", message);

    // Generate the digest to be signed
    const digest = blake2b(intentMessage, { dkLen: 32 });
    console.log("Digest:", digest);

    // Sign the transaction using the Ledger device
    const { signature } = await sui.signTransaction(bip32Path, digest);
    console.log("Signature:", signature);

    // Close the transport
    await transport.close();
    return { publicKey, message, signature };
  } catch (error) {
    console.error("Error during signing:", error);
  }
}

signAndVerifyMessage();
