import { TransactionDataBuilder } from "@mysten/sui/transactions";

const args = process.argv.slice(2);
const base64TxBytes = args[0];

// Decode from Base64
const txBytes = fromBase64(base64TxBytes);

// Parse the tx bytes into a TransactionDataBuilder instance
const transactionData = TransactionDataBuilder.fromBytes(txBytes);

// Access relevant information
console.log("Sender:", transactionData.sender);
console.log("Gas Configuration:", transactionData.gasConfig);
console.log("Inputs:", transactionData.inputs);
console.log("Commands:", transactionData.commands);
console.log("Expiration:", transactionData.expiration);
