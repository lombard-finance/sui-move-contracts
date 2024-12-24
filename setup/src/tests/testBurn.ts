import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { suiClient, SHARED_CONTROLLED_TREASURY, LBTC_OBJECT_ID } from "../config"; 
import { burn } from "../utils/burn";

async function testBurn() {
  try {
    const signerKeypair = Ed25519Keypair.generate();
    const burnResponse = await burn(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      LBTC_OBJECT_ID,
      signerKeypair
    );

    console.log("Burn transaction executed successfully:", burnResponse);
  } catch (error) {
    console.error("Error in testBurn:", error);
  }
}
testBurn();