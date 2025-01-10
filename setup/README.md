## Smart Contract Integration Code

This folder contains TypeScript code designed for smart contract integration. Follow the steps below to set up and use the project.

### Instructions

1. ****Set up dependencies:****
   ```bash
   cd setup
   pnpm install
   ```

2. ****Navigate to the** `scripts` **folder and prepare the script:****
   ```bash
   cd ../scripts
   chmod +x ./publish.sh
   ```

3. ****Publish to the testnet:****
   ```bash
   ./publish.sh --env=testnet
   ```

4. ****Move configuration files:****
   - Move the `.env` file from `scripts` folder to the `setup` folder.

5. ****Update package IDs:****
   - Copy the `PACKAGE_ID` from the .env and replace the `package_id` in `package.json`.
   - Copy the `SHARED_CONSORTIUM` from the .env and replace the `consortium_package_id` in `package.json`.

6. ****Handle TypeMove bug:****
   - Comment out the following block of code:
     ```typescript
     _// export namespace bitcoin_utils {_
     _//   ..._
     _// }_
     ```
     __Reason: TypeMove currently does not support the export of enums.__

7. ****Update imports:****
   - Modify all imports in `tests` and `utils` to reflect the new `types` file structure.

### Recommended Starting Point

- Begin with the `testMinter` script to grant your address minter capabilities.