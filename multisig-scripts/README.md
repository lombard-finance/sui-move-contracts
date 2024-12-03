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

**NOTE:** Signatures need to be ordered in the same way as the public keys in the keyfile!

This script will then combine all signatures with the current `tx_bytes` file and generate a complete transaction, and proceed to broadcast it. It will also save the returned package ID and shared controlled treasury UID, which are needed to make changes on the contracts.

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

### Upgrading a contract

This works exactly like the contract [deployment step](Deploying-the-contract), but instead of passing `--deployment`, you should pass `--upgrade`, and the initial bytes are generated with `create_upgrade_bytes.sh`. Another thing to keep in mind is that the `Move.toml` file will need to include a `published-at` field in the `package` section, pointing towards the address of the previously deployed contract.

## Tools

### Transaction deobfuscation

In case you are sent a Base64 string of a transaction and want to check out what it really is doing, you can use the `deobfuscate_bytes.sh` script. You can simply call it like suchs:

`./deobfuscate_bytes.sh <tx_bytes>`

This will give you all the information of the proposed state update.
