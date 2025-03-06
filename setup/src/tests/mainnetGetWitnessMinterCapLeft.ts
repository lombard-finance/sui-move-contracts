import { getWitnessMinterCapLeft } from "../utils/getWitnessMinterCapLeft";
import { SuiClient } from "@mysten/sui/client";

async function testSetChainId() {
  try {
    const suiClient = new SuiClient({ url: "https://fullnode.mainnet.sui.io:443" });
    let result = await getWitnessMinterCapLeft(
      suiClient,
      "0x1adadbca040f368abd554ac55e7c216ea6df2ff891fc647f037d66669661584a", "a1ae9afcd3ee1f7b082580c100cb3dbcba03713112638f86d8b5a5026b025253::bridge_vault::BridgeWitness",
    );

    console.log("Transaction executed successfully:", result);
  } catch (error) {
    console.error("Error in testAssignMinter:", error);
  }
}

testSetChainId();
