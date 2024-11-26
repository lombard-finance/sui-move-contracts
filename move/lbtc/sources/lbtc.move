
module lbtc::lbtc;

use sui::{coin::{Self, DenyCapV2}, deny_list::DenyList};

// === Constants ===
const SYMBOL: vector<u8> = b"LBTC";
const NAME: vector<u8> = b"LBTC";
const DESCRIPTION: vector<u8> = b"";

public struct LBTC has drop {}

fun init(otw: LBTC, ctx: &mut TxContext) {
    let (treasury, deny_cap, metadata) = coin::create_regulated_currency_v2(
        otw,
        6,
        SYMBOL,
        NAME,
        DESCRIPTION,
        option::none(),
        true,
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_transfer(deny_cap, ctx.sender())
}

public fun enable_global_pause(
    denylist: &mut DenyList,
    denycap: &mut DenyCapV2<LBTC>,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_enable_global_pause(denylist, denycap, ctx);
}

public fun disable_global_pause(
    denylist: &mut DenyList,
    denycap: &mut DenyCapV2<LBTC>,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_disable_global_pause(denylist, denycap, ctx);
}

public fun is_global_pause_enabled_current_epoch(
    denylist: &DenyList,
    ctx: &TxContext,
): bool {
    coin::deny_list_v2_is_global_pause_enabled_current_epoch<LBTC>(denylist, ctx)
}

