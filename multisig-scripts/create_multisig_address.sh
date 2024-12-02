#!/usr/bin/env sh

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
KEYFILE=
THRESHOLD=

while [ $# -gt 0 ]; do
    case "$1" in
    --keyfile=*)
        KEYFILE="${1#*=}"
        ;;
    --threshold=*)
        THRESHOLD="${1#*=}"
        ;;
    *)
        echo "Unknown arg $1"
        exit 1
    esac #end case
    shift
done

if [ -z "$KEYFILE" ] || [ -z "$THRESHOLD" ]; then
    echo "Error: missing arguments! Need keyfile and threshold."
    exit 1
fi

# Take public keys and weights from selected file
pks=()
weights=()

while IFS=',' read -r first second; do
    # Append to arrays
    pks+=("$first")
    weights+=("$second")
done < $KEYFILE

admin_multisig_info=$(sui keytool multi-sig-address --pks ${pks[@]} --weights ${weights[@]} --threshold $THRESHOLD --json)
echo "Multisig address: $(echo $admin_multisig_info | jq -r '.multisigAddress')"
echo $admin_multisig_info > admin_multisig_info

# Add threshold information
jq --arg key "threshold" --arg value "$THRESHOLD" '. + {($key): ($value | tonumber)}' admin_multisig_info > updated_info
mv updated_info admin_multisig_info
