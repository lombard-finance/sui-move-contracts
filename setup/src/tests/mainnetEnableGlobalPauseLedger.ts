import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { SHARED_CONSORTIUM, ONE_LBTC, DENYLIST, MULTISIG } from "../config"; 
import { burn } from "../utils/burn";
import { enableGlobalPause } from "../utils/enableGlobalPause";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";
import TransportNodeHid from "@ledgerhq/hw-transport-node-hid";
import Sui from "@mysten/ledgerjs-hw-app-sui";
import { treasury } from "../types/0x2721ad6e939baca77b36f415ab91edb1c91b256cbc8614f8f6c84bf06faf74af";
import { Transaction } from "@mysten/sui/transactions";
import { blake2b } from "@noble/hashes/blake2b";

async function testBurn() {
  try {
    // Establish connection to Ledger device
    const devices = await TransportNodeHid.list();
    if (devices.length === 0) {
      throw new Error("No Ledger devices found");
    }

    const transport = await TransportNodeHid.open(devices[0].path);
    const sui = new Sui(transport);
    const suiClient = new SuiClient({ url: "https://fullnode.mainnet.sui.io:443" });

    // Fetch public key for verification later
    const bip32Path = "m/44'/784'/0'/0'/0'";
    const { publicKey, address } = await sui.getPublicKey(bip32Path, true);

    // Execute the mint and transfer logic
    console.log("pause")
    const tx = new Transaction();

    treasury.builder.enableGlobalPauseV2(
      tx,
      [
        tx.object("0x1adadbca040f368abd554ac55e7c216ea6df2ff891fc647f037d66669661584a"), // Controlled Treasury object
        tx.object("0x403"), // Denylist global object
      ],
      ["0x3e8e9423d80e1774a7ca128fccd8bf5f1f7753be658c5e645929037f7c819040::lbtc::LBTC"]
    );

    tx.setSender(Buffer.from(address).toString('hex'));
    tx.setGasBudget(500000000);

    const bytes = await tx.build({ client: suiClient });
    // Add the intent message to the payload
    const intentMessage = messageWithIntent("TransactionData", bytes);

    // Generate the digest to be signed
    const digest = blake2b(intentMessage, { dkLen: 32 });
    console.log("Digest:", digest);
    const { signature } = await sui.signTransaction(bip32Path, digest);
    console.log("Signature:", signature);
    const flag = Buffer.from([0]);
    const sig = Buffer.concat([flag, signature, publicKey]);

    await suiClient.executeTransactionBlock({ signature: Buffer.from(sig).toString('base64'), transactionBlock: bytes });
    console.log("done transaction executed successfully");
  } catch (error) {
    console.error("Error in val:", error);
  }
}

testBurn();
