import { config } from "dotenv";
import { SuiClient } from "@mysten/sui/client";

config({ path: '.env' });

type NetworkEnvironment = "devnet" | "testnet" | "mainnet";

export const SUI_NETWORK = process.env.SUI_NETWORK!;
export const ACTIVE_NETWORK = (process.env.SUI_ENV ??
  "devnet") as NetworkEnvironment;
export const MULTISIG = {
  ADDRESS: process.env.MULTISIG_ADDRESS!,
  THRESHOLD: 2,
  USER_1: {
    SK: process.env.USER_1_SK,
    PK: process.env.USER_1_PK!,
    ADDRESS: process.env.USER_1_ADDRESS!,
    WEIGHT: 1,
  },
  USER_2: {
    SK: process.env.USER_2_SK,
    PK: process.env.USER_2_PK!,
    ADDRESS: process.env.USER_2_ADDRESS!,
    WEIGHT: 1,
  },
};

export const PACKAGE_ID = process.env.PACKAGE_ID!;
export const SHARED_CONSORTIUM = process.env.SHARED_CONSORTIUM!;
export const SHARED_CONTROLLED_TREASURY =
  process.env.SHARED_CONTROLLED_TREASURY!;
export const SHARED_BASCULE = process.env.SHARED_BASCULE!;
export const LBTC_COIN_TYPE = `${PACKAGE_ID}::lbtc::LBTC`;
export const ONE_LBTC = 1 * 10 ** 8;
export const SCRIPT_PUB_KEY_HEX = '5120999d8db965f148662dc38ab5f4ee0c438cadbcc0ab3c946b45159e30b3714948';
export const DENYLIST = "0x403";

export const suiClient = new SuiClient({
  url: SUI_NETWORK,
});

config({ path: '.test-witness.env' });
export const TEST_WITNESS_PACKAGE_ID = process.env.TEST_WITNESS_PACKAGE_ID!;