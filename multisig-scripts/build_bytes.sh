#!/usr/bin/env sh

# check this is being run from the right location
if [[ "$PWD" != *"/multisig-scripts" ]]; then
    echo "Please run this from ./multisig-scripts"
    exit 0
fi

# check dependencies are available
for dep in ts-node; do
    if !command -V ${i} 2>/dev/null; then
        echo "Please install lib ${dep}"
        exit 1
    fi
done

PACKAGE_ID=$(cat package_id)
TREASURY_ADDRESS=$(cat shared_controlled_treasury)
ADMIN_MULTISIG_FILE="admin_multisig_info"
ADMIN_MULTISIG_ADDRESS=$(cat $ADMIN_MULTISIG_FILE | jq -r '.multisigAddress')

# Process command-line arguments
COMMAND=

case "$1" in
--command=*)
    COMMAND="${1#*=}"
    case ${COMMAND} in
    "addAdmin") 
        if [ -z "$2" ]; then
            echo "Error: missing arguments! Need address."
            exit 1
        fi
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $2
        ;;
    "addMinter") 
        if [ -z "$2" ]; then
            echo "Error: missing arguments! Need address."
            exit 1
        fi
        if [ -z "$3" ]; then
            echo "Error: missing arguments! Need mint limit."
            exit 1
        fi
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $2 $3
        ;;
    "addPauser") 
        if [ -z "$2" ]; then
            echo "Error: missing arguments! Need address."
            exit 1
        fi
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $2
        ;;
    "disableGlobalPause") 
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $ADMIN_MULTISIG_FILE
        ;;
    "enableGlobalPause") 
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $ADMIN_MULTISIG_FILE
        ;;
    "mintAndTransfer") 
        if [ -z "$2" ]; then
            echo "Error: missing arguments! Need address."
            exit 1
        fi
        if [ -z "$3" ]; then
            echo "Error: missing arguments! Need amount."
            exit 1
        fi
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $2 $3 $ADMIN_MULTISIG_FILE
        ;;
    "removeMinter") 
        if [ -z "$2" ]; then
            echo "Error: missing arguments! Need address."
            exit 1
        fi
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $2
        ;;
    "removePauser") 
        if [ -z "$2" ]; then
            echo "Error: missing arguments! Need address."
            exit 1
        fi
        ts-node ../setup/src/utils/commandCall.ts $PACKAGE_ID $COMMAND $TREASURY_ADDRESS $ADMIN_MULTISIG_ADDRESS $2
        ;;
    *) echo "unknown command {$COMMAND}"
        exit 1
    esac #end inner case
    ;;
*)
    echo "Unknown arg $1"
    exit 1
esac #end case

