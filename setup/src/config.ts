import { config } from "dotenv";
import { SuiClient } from "@mysten/sui/client";

config({});

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
export const SHARED_CONTROLLED_TREASURY =
  process.env.SHARED_CONTROLLED_TREASURY!;
export const LBTC_COIN_TYPE = `${PACKAGE_ID}::lbtc::LBTC`;
export const ONE_LBTC = 1 * 10 ** 8;
export const LBTC_OBJECT_ID =
  process.env.LBTC_OBJECT_ID!;
export const SCRIPT_PUB_KEY_HEX = '0x512000000000000000000000000000000000000000000000000000000000000000000001';
export const DENYLIST = "0x403";

export const suiClient = new SuiClient({
  url: SUI_NETWORK,
});
