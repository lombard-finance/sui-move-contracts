#!/usr/bin/env sh

# check this is being run from the right location
if [[ "$PWD" != *"/multisig-scripts" ]]; then
    echo "Please run this from ./multisig-scripts"
    exit 0
fi

# check dependencies are available
for dep in jq sui; do
    if !command -V ${i} 2>/dev/null; then
        echo "Please install lib ${dep}"
        exit 1
    fi
done

# Process command-line arguments
ENV=
SIGNATURES=
DEPLOYMENT=

while [ $# -gt 0 ]; do
    case "$1" in
    --env=*)
        ENV="${1#*=}"
        case ${ENV} in
        "mainnet") ;;
        "testnet") ;;
        *) echo "unknown env {$ENV}"
            exit 1
        esac #end inner case
        ;;
    --signatures=*)
        SIGNATURES="${1#*=}"
        ;;
    --deployment)
        DEPLOYMENT="1"
        ;;
    *)
        echo "Unknown arg $1"
        exit 1
    esac #end case
    shift
done

TX_BYTES=$(cat tx_bytes)

if [ -z "$SIGNATURES" ] || [ -z "$TX_BYTES" ]; then
    echo "Error: missing arguments! Need signatures and tx bytes."
    exit 1
fi

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
    echo "Unknown environment $ENV"
    exit 1
    ;;
*)
esac

# Switch to the selected environment
echo "Switching to environment: {$ENV}"
sui client switch --env $ENV

# Take public keys and weights from selected file
pks=($(jq -r '.multisig[].publicBase64Key' admin_multisig_info))
weights=($(jq -r '.multisig[].weight' admin_multisig_info))

# Take signatures from selected file
signatures=()

while IFS= read -r line; do
    # Append to arrays
    signatures+=("$line")
done < $SIGNATURES

THRESHOLD=$(jq -r '.threshold' admin_multisig_info)

# Combine the partial signatures into a multisig signature
admin_multi_sig=$(sui keytool multi-sig-combine-partial-sig \
  --pks ${pks[@]} \
  --weights ${weights[@]} \
  --threshold $THRESHOLD \
  --sigs ${signatures[@]} \
  --json \
  | jq -r '.multisigSerialized')

# Execute the signed transaction
publish_res=$(sui client execute-signed-tx --tx-bytes $TX_BYTES --signatures $admin_multi_sig --json)
echo "$publish_res"

if [ $DEPLOYMENT ]; then
    # Extract the env variables from the publish result
    packageId=$(echo "$publish_res" | jq -r '.effects.created[] | select(.owner == "Immutable" and .reference.version == 1) | .reference.objectId')
    createdObjects=$(echo "$publish_res" | jq -r '.objectChanges[] | select(.type == "created")')
    sharedControlledTreasury=$(echo "$createdObjects" |  jq -r 'select (.objectType | contains("treasury::ControlledTreasury")).objectId')
    upgradeCap=$(echo "$createdObjects" | jq -r 'select (.objectType | contains("package::UpgradeCap")).objectId')
    txDigest=$(echo "$publish_res" | jq -r '.effects.transactionDigest')

    echo $packageId > package_id
    echo $sharedControlledTreasury > shared_controlled_treasury
    echo $upgradeCap > upgrade_cap

    echo "Return values saved!"
    echo "Please consult the README on how to update the ABIs for transaction building."
fi
