import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { suiClient, SHARED_CONTROLLED_TREASURY, SCRIPT_PUB_KEY_HEX, ONE_LBTC, MULTISIG, DENYLIST } from "../config"; 
import { redeem } from "../utils/redeem";
import { getMultisigConfig, getTestMultisigConfig } from "../helpers/getMultisigConfig";
import { mintAndTransfer } from "../utils/mintAndTransfer";
import { setBurnCommission } from "../utils/setBurnCommission";
import { setDustFeeRate } from "../utils/setDustFeeRate";
import { toggleWithdrawal } from "../utils/toggleWithdrawal";
import { setTreasuryAddress } from "../utils/setTreasuryAddress";
import { getFaucetHost, requestSuiFromFaucetV1 } from '@mysten/sui/faucet';
import { isWithdrawalEnabled } from "../utils/isWithdrawalEnabled";

const DUMMY_TXID = new TextEncoder().encode("abcd");
const DUMMY_IDX: number = 0;

async function testRedeem() {
  try {
    // Retrieve our default multisig configuration
    const multisigConfig = getTestMultisigConfig();

    // Execute the mint and transfer logic
    console.log("Mint and transfer lbtc")
    const result = await mintAndTransfer(
      suiClient,
      SHARED_CONTROLLED_TREASURY, // Controlled Treasury object
      ONE_LBTC, // Amount to mint
      MULTISIG.ADDRESS, // Recipient address
      DENYLIST, // Denylist global object
      DUMMY_TXID, // Placeholder BTC deposit transaction ID
      DUMMY_IDX, // Placeholder BTC deposit index
      multisigConfig // Multisig configuration
    );
    //set dynamic fields
    const withdrawalEnabled = await isWithdrawalEnabled(suiClient, SHARED_CONTROLLED_TREASURY);
    console.log("isWithdrawalEnabled: ", withdrawalEnabled);
    if (!withdrawalEnabled) {
      console.log("Toggle withdrawal");
      await toggleWithdrawal(suiClient, SHARED_CONTROLLED_TREASURY, { multisig: multisigConfig });
    }
    console.log("Set Treasury Address");
    await setTreasuryAddress(suiClient, SHARED_CONTROLLED_TREASURY, MULTISIG.ADDRESS , { multisig: multisigConfig })
    console.log("Set Dust Fee Rate");
    await setDustFeeRate(suiClient, SHARED_CONTROLLED_TREASURY, 10, { multisig: multisigConfig })
    console.log("Set Burn Commission");
    await setBurnCommission(suiClient, SHARED_CONTROLLED_TREASURY, 100, { multisig: multisigConfig })

    const coinId = result.effects.created[0].reference.objectId;

    console.log("Redeem lbtc")
    const claimResponse = await redeem(
      suiClient,
      SHARED_CONTROLLED_TREASURY,
      coinId,
      SCRIPT_PUB_KEY_HEX,
      multisigConfig
    );

      console.log("Redeem transaction executed successfully:", claimResponse);
    } catch (error) {
      console.error("Error in testRedeem:", error);
    }
}
testRedeem();
