#!/usr/bin/env sh

# This script publishes a Move contract using multisig functionality.
# It sets up addresses for user1, user2
# creates multisig addresses, requests tokens, and publishes the contract with multisig signatures.

# Set the Move package path (update this to your contract's directory)
MOVE_PACKAGE_PATH="../move/consortium"

# check this is being run from the right location
if [[ "$PWD" != *"/scripts" ]]; then
    echo "Please run this from ./scripts"
    exit 0
fi

# check dependencies are available
for dep in jq curl sui; do
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
*)
    echo "Unknown environment $ENV"
    exit 1
    ;;
esac

# Switch to the selected environment
echo "Switching to environment: {$ENV}"
sui client switch --env $ENV

# Set up multisig addresses
addresses=$(sui client addresses --json)

# Define the roles
vals=("user1" "user2")

# Loop through each role in the vals array
for role in "${vals[@]}"; do
    echo "Checking if $role address is available"
    
    # Check if the address exists
    has_role=$(echo "$addresses" | jq -r --arg role "$role" '.addresses | map(contains([$role])) | any')
    
    # If the address does not exist, create one and request tokens
    if [ "$has_role" = "false" ]; then
        echo "Did not find '$role' in the addresses. Creating one and requesting tokens."
        sui client new-address ed25519 "$role"
    fi
done

# Export keys and addresses for each role
user1=$(sui keytool export --key-identity user1 --json)
user1_pk=$(echo $user1 | jq -r '.key.publicBase64Key')
user1_pk_hex=$(echo $user1_pk | base64 -d | xxd -p | tr -d '\n')
user1_address=$(echo $user1 | jq -r '.key.suiAddress')
user1_sk=$(echo $user1 | jq -r '.exportedPrivateKey')
echo "user1 Address: $user1_address"

user2=$(sui keytool export --key-identity user2 --json)
user2_pk=$(echo $user2 | jq -r '.key.publicBase64Key')
user2_pk_hex=$(echo $user2_pk | base64 -d | xxd -p | tr -d '\n')
user2_address=$(echo $user2 | jq -r '.key.suiAddress')
user2_sk=$(echo $user2 | jq -r '.exportedPrivateKey')
echo "user2 Address: $user2_address"

# Create multisig addresses
admin_multisig_address=$(sui keytool multi-sig-address --pks "$user1_pk" "$user2_pk" --weights 1 1 --threshold 2 --json | jq -r '.multisigAddress')
echo "Admin Multisig Address: $admin_multisig_address"

# Request tokens for multisig address
# sui client faucet --address $admin_multisig_address

# Get a gas coin for the multisig address
gas_coin=$(sui client gas $admin_multisig_address --json | jq -r '.[0].gasCoinId')

# Prepare to publish the Move package
publish_res_bytes=$(sui client publish \
  --skip-fetch-latest-git-deps \
  --with-unpublished-dependencies \
  --skip-dependency-verification \
  --gas $gas_coin \
  --gas-budget 500000000 \
  --serialize-unsigned-transaction \
  $MOVE_PACKAGE_PATH)

# Sign the transaction with the required signatures
user1_sig=$(sui keytool sign --address $user1_address --data $publish_res_bytes --json | jq -r '.suiSignature')
user2_sig=$(sui keytool sign --address $user2_address --data $publish_res_bytes --json | jq -r '.suiSignature')

# Combine the partial signatures into a multisig signature
admin_multi_sig=$(sui keytool multi-sig-combine-partial-sig \
  --pks $user1_pk $user2_pk \
  --weights 1 1 \
  --threshold 2 \
  --sigs $user1_sig $user2_sig \
  --json \
  | jq -r '.multisigSerialized')

# Execute the signed transaction
publish_res=$(sui client execute-signed-tx --tx-bytes $publish_res_bytes --signatures $admin_multi_sig --json)
echo $publish_res > .publish.res.json

# Extract the env variables from the publish result
packageId=$(echo "$publish_res" | jq -r '.effects.created[] | select(.owner == "Immutable" and .reference.version == 1) | .reference.objectId')
createdObjects=$(echo "$publish_res" | jq -r '.objectChanges[] | select(.type == "created")')
sharedConsortium=$(echo "$createdObjects" |  jq -r 'select (.objectType | contains("consortium::Consortium")).objectId')
upgradeCap=$(echo "$createdObjects" | jq -r 'select (.objectType | contains("package::UpgradeCap")).objectId')
txDigest=$(echo "$publish_res" | jq -r '.effects.transactionDigest')

echo "Package ID: $packageId"

# Generate the .env file with the necessary variables
cat >.env<<-ENV
SUI_NETWORK=$FULLNODE_URL
SUI_ENV=$NETWORK
TX_DIGEST=$txDigest
UPGRADE_CAP=$upgradeCap
PACKAGE_ID=$packageId
SHARED_CONSORTIUM=$sharedConsortium
MULTISIG_ADDRESS=$admin_multisig_address
USER_1_ADDRESS=$user1_address
USER_2_ADDRESS=$user2_address
USER_1_PK=$user1_pk
USER_2_PK=$user2_pk
USER_1_SK=$user1_sk
USER_2_SK=$user2_sk
ENV

echo "Environment variables have been set in .env file."
echo "Publishing completed successfully with multisig."

