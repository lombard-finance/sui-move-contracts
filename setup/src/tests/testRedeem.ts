import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { suiClient, SHARED_CONTROLLED_TREASURY, LBTC_OBJECT_ID, SCRIPT_PUB_KEY_HEX, ONE_LBTC } from "../config"; 
import { redeem } from "../utils/redeem";

async function testRedeem() {
  try {
    const signerKeypair = Ed25519Keypair.generate();
    const claimResponse = await redeem(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      LBTC_OBJECT_ID,
      SCRIPT_PUB_KEY_HEX,
      signerKeypair
    );

      console.log("Redeem transaction executed successfully:", claimResponse);
    } catch (error) {
      console.error("Error in testRedeem:", error);
    }
}
testRedeem();
