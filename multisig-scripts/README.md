# Multisig coordinator scripts for Sui contracts

This folder contains a set of convenient scripts used for the Sui contract lifecycle as a multisig coordinator.

## Workflow

### Creation

To start off, each participant needs to provide their Sui format public key to a single person; we can denote this single person as the 'multisig coordinator'. When collected, this coordinator should run the `create_multisig_address.sh` script, with the following arguments:

- `--keyfile=<keyfile>`, which should be a file containing each participant's public key and their weight, separated by a comma. Each party should have its own line in the file (e.g. `<public_key>,<weight>\n`)
- `--threshold=<n>` the threshold at which the multisig should be able to do transactions.

This will create a file called `admin_multisig_info` containing all the public keys, their associated weights and the threshold of the multisig wallet.

### Generating deployment bytes

Next up, we should create the transaction bytes to deploy whatever contract we wish to deploy. For the LBTC Sui contracts, there is the `create_deployment_bytes.sh` script, which should be run by the coordinator. It takes one argument:

- `--env=<testnet|mainnet>`, to denote what network we will deploy on. This is also needed to ensure that the multisig wallet will have enough money to pay for gas in case of a testnet deployment.

It will return the transaction bytes in a file called `tx_bytes`.

### Deploying the contract

Then, when all signers have given their signatures, the coordinator can publish the contracts with the `execute_tx.sh` script. The arguments it takes are as follows:

- `--env=<testnet|mainnet>`, to denote where we will broadcast this transaction. In case of `testnet`, we also make a call to the Sui testnet faucet.
- `--signatures=<file>`, passes the name of the file containing all signatures needed to complete the transaction, with each signature separated by a newline.
- `--deployment`, which tells the script that this is a contract deployment.

This script will then combine all signatures with the current `tx_bytes` file and generate a complete transaction, and proceed to broadcast it. It will also save the returned package ID and shared controlled treasury UID, which are needed to make changes on the contracts.

**NOTE:** This does not update the contract types which are used for transaction building - this is a bit tricky to do but an easy way to circumvent this is by using this bash command (do this inside the `setup` folder only!):

`grep -l 0xbe707cb2ed4703f8a6764a656c0adb7a7a0ed709739e63d56ccfc986e1259e6c | xargs gsed -i "s:0xbe707cb2ed4703f8a6764a656c0adb7a7a0ed709739e63d56ccfc986e1259e6c:<PACKAGE_ID>:g"`

Or, if you're on Linux:

`grep -l 0xbe707cb2ed4703f8a6764a656c0adb7a7a0ed709739e63d56ccfc986e1259e6c | xargs sed -i "s:0xbe707cb2ed4703f8a6764a656c0adb7a7a0ed709739e63d56ccfc986e1259e6c:<PACKAGE_ID>:g"`

### Generating any kind of transaction bytes

The coordinator can now build all types of transactions for the contract with the `build_bytes.sh` script. This takes one argument:

- `--command=<command>`, which lets the script know which transaction type to build bytes for. Possible choices are:
    - `addAdmin`, which takes an address
    - `addMinter`, which takes an address and a mint limit
    - `addPauser`, which takes an address
    - `disableGlobalPause`
    - `enableGlobalPause`
    - `mintAndTransfer`, which takes an address and an amount in satoshis
    - `removeMinter`, which takes an address
    - `removePauser`, which takes an address

The argument are supposed to be passed after the command. The script will then build the transaction bytes and pipe them into `tx_bytes` for signing.

### Executing the transaction

This step works just like the contract deployment phase - except that the --deployment argument should not be passed. After having collected all signatures, the coordinator can run `execute_tx.sh` with the same arguments:

- `--env=<testnet|mainnet>`, to denote where we will broadcast this transaction. In case of `testnet`, we also make a call to the Sui testnet faucet.
- `--signatures=<file>`, passes the name of the file containing all signatures needed to complete the transaction, with each signature separated by a newline.
