module lbtc::lbtc;

use lbtc::treasury;
use sui::coin;
use sui::url;

// === Constants ===

// TODO: Need to get the real values for coin metadata
const SYMBOL: vector<u8> = b"LBTC";
const NAME: vector<u8> = b"LBTC";
const DESCRIPTION: vector<u8> = b"";
const ICON_URL: vector<u8> = b"";
const DECIMALS: u8 = 9;

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
        true,
        ctx,
    );

    // Don't allow future mutations of the coin metadata.
    transfer::public_freeze_object(metadata);

    // Create a `ControlledTreasury` and store the `TreasuryCap` and `DecyCapV2`.
    treasury::new(treasury_cap, deny_cap, ctx.sender(), ctx).share()
}
