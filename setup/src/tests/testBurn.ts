import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { suiClient, SHARED_CONTROLLED_TREASURY, ONE_LBTC, DENYLIST } from "../config"; 
import { burn } from "../utils/burn";
import { mintAndTransfer } from "../utils/mintAndTransfer";
import { getTestMultisigConfig } from "../helpers/getMultisigConfig";

const DUMMY_TXID = new TextEncoder().encode("abcd");
const DUMMY_IDX: number = 0;

async function testBurn() {
  try {

    const signerKeypair = Ed25519Keypair.generate();
        // Retrieve our default multisig configuration
        const multisigConfig = getTestMultisigConfig();
    
        // Execute the mint and transfer logic
        const result = await mintAndTransfer(
          suiClient,
          SHARED_CONTROLLED_TREASURY, // Controlled Treasury object
          ONE_LBTC, // Amount to mint
          signerKeypair.toSuiAddress(), // Recipient address
          DENYLIST, // Denylist global object
          DUMMY_TXID, // Placeholder BTC deposit transaction ID
          DUMMY_IDX, // Placeholder BTC deposit index
          multisigConfig // Multisig configuration
        );
    const coinId = result.effects.created[0].reference.objectId;

    const burnResponse = await burn(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      coinId,
      signerKeypair
    );

    console.log("Burn transaction executed successfully:", burnResponse);
  } catch (error) {
    console.error("Error in testBurn:", error);
  }
}
testBurn();