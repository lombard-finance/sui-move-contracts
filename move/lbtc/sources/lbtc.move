// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module creates the `LBTC` regulated coin and initializes its treasury management
/// system using `ControlledTreasury`.
module lbtc::lbtc;

use lbtc::treasury;
use sui::coin;
use sui::url;

// === Constants ===

const ALLOW_GLOBAL_PAUSE: bool = true;

// TODO: Need to get the real values for coin metadata
const SYMBOL: vector<u8> = b"LBTC";
const NAME: vector<u8> = b"Lombard Staked BTC";
const DESCRIPTION: vector<u8> = b"Lombard connects Bitcoin to DeFi through LBTC, the Universal Liquid Bitcoin Standard. Backed 1:1 by BTC, LBTC is yield-bearing, cross-chain, and enables BTC holders to earn Babylon staking yields, trade, borrow, lend, and yield farm.";
const ICON_URL: vector<u8> = b"https://www.lombard.finance/lbtc/LBTC.png";
const DECIMALS: u8 = 8;

// Name of the coin.
public struct LBTC has drop {}

/// The publishing of the contract should happen through a multi-sig address so we also
/// assign the multisig as the owner of the `ControlledTreasury`.
fun init(otw: LBTC, ctx: &mut TxContext) {
    let (treasury_cap, deny_cap, metadata) = coin::create_regulated_currency_v2(
        otw,
        DECIMALS,
        SYMBOL,
        NAME,
        DESCRIPTION,
        option::some(url::new_unsafe(ICON_URL.to_ascii_string())),
        ALLOW_GLOBAL_PAUSE,
        ctx,
    );

    // Don't allow future mutations of the coin metadata.
    transfer::public_freeze_object(metadata);

    // Create a `ControlledTreasury` and store the `TreasuryCap` and `DecyCapV2`.
    treasury::new(treasury_cap, deny_cap, ctx.sender(), ctx).share()
}
