#!/usr/bin/env sh

# Set the Move package path (update this to your contract's directory)
MOVE_PACKAGE_PATH="../move/lbtc"

# check this is being run from the right location
if [[ "$PWD" != *"/multisig-scripts" ]]; then
    echo "Please run this from ./multisig-scripts"
    exit 0
fi

# check dependencies are available
for dep in sui; do
    if !command -V ${i} 2>/dev/null; then
        echo "Please install lib ${dep}"
        exit 1
    fi
done

# Process command-line arguments
ENV=

while [ $# -gt 0 ]; do
    case "$1" in
    --env=*)
        ENV="${1#*=}"
        case ${ENV} in
        "testnet") ;;
        "devnet") ;;
        "local") ;;
        *) echo "unknown env {$ENV}"
            exit 1
        esac #end inner case
        ;;
    *)
        echo "Unknown arg $1"
        exit 1
    esac #end case
    shift
done

# Set up network variables
NETWORK=
FULLNODE_URL=

case "$ENV" in
"testnet")
    NETWORK="testnet"
    FULLNODE_URL="https://fullnode.testnet.sui.io:443"
    ;;
"mainnet")
    NETWORK="mainnet"
    FULLNODE_URL="https://fullnode.mainnet.sui.io:443"
    ;;
*)
esac

# Switch to the selected environment
echo "Switching to environment: {$ENV}"
sui client switch --env $ENV

admin_multisig_address=$(cat admin_multisig_info | jq -r '.multisigAddress')

# Request tokens for multisig address
sui client faucet --address $admin_multisig_address

sleep 10

# Get a gas coin for the multisig address
gas_coin=$(sui client gas $admin_multisig_address --json | jq -r '.[0].gasCoinId')

upgrade_cap=$(cat upgrade_cap)

# Prepare to publish the Move package
publish_res_bytes=$(sui client upgrade \
  --skip-fetch-latest-git-deps \
  --with-unpublished-dependencies \
  --skip-dependency-verification \
  --gas $gas_coin \
  --gas-budget 500000000 \
  --upgrade-capability $upgrade_cap \
  --serialize-unsigned-transaction \
  $MOVE_PACKAGE_PATH)
echo $publish_res_bytes > tx_bytes
