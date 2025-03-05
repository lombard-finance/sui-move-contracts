/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

/* Generated types for 0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3, original address 0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3 */

import { TypeDescriptor, ANY_TYPE } from "@typemove/move";
import { MoveCoder, TypedEventInstance } from "@typemove/sui";

import { defaultMoveCoder } from "@typemove/sui";

import {
  ZERO_ADDRESS,
  TypedDevInspectResults,
  getMoveCoder,
} from "@typemove/sui";
import {
  Transaction,
  TransactionArgument,
  TransactionObjectArgument,
} from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import {
  transactionArgumentOrObject,
  transactionArgumentOrVec,
  transactionArgumentOrPure,
  transactionArgumentOrPureU8,
  transactionArgumentOrPureU16,
  transactionArgumentOrPureU32,
  transactionArgumentOrPureU64,
  transactionArgumentOrPureU128,
  transactionArgumentOrPureU256,
  transactionArgumentOrPureBool,
  transactionArgumentOrPureString,
  transactionArgumentOrPureAddress,
} from "@typemove/sui";

import * as _0x2 from "@typemove/sui/builtin/0x2";

export namespace consortium {
  export interface Consortium {
    id: _0x2.object$.UID;
    epoch: bigint;
    validator_set: _0x2.table.Table<bigint, consortium.ValidatorSet>;
    valset_action: number;
    admins: string[];
  }

  export namespace Consortium {
    export const TYPE_QNAME =
      "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::Consortium";

    const TYPE = new TypeDescriptor<Consortium>(Consortium.TYPE_QNAME);

    export function type(): TypeDescriptor<Consortium> {
      return TYPE.apply();
    }
  }

  export interface ValidatorSet {
    pub_keys: number[][];
    weights: bigint[];
    weight_threshold: bigint;
  }

  export namespace ValidatorSet {
    export const TYPE_QNAME =
      "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::ValidatorSet";

    const TYPE = new TypeDescriptor<ValidatorSet>(ValidatorSet.TYPE_QNAME);

    export function type(): TypeDescriptor<ValidatorSet> {
      return TYPE.apply();
    }
  }

  export namespace builder {
    export function addAdmin(
      tx: Transaction,
      args: [
        string | TransactionObjectArgument | TransactionArgument,
        string | TransactionArgument,
      ],
    ): TransactionArgument & [TransactionArgument, TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));
      _args.push(transactionArgumentOrPureAddress(args[1], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::add_admin",
        arguments: _args,
      });
    }
    export function getEpoch(
      tx: Transaction,
      args: [string | TransactionObjectArgument | TransactionArgument],
    ): TransactionArgument & [TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::get_epoch",
        arguments: _args,
      });
    }
    export function getValidatorSet(
      tx: Transaction,
      args: [
        string | TransactionObjectArgument | TransactionArgument,
        bigint | TransactionArgument,
      ],
    ): TransactionArgument & [TransactionArgument, TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));
      _args.push(transactionArgumentOrPureU256(args[1], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::get_validator_set",
        arguments: _args,
      });
    }
    export function removeAdmin(
      tx: Transaction,
      args: [
        string | TransactionObjectArgument | TransactionArgument,
        string | TransactionArgument,
      ],
    ): TransactionArgument & [TransactionArgument, TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));
      _args.push(transactionArgumentOrPureAddress(args[1], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::remove_admin",
        arguments: _args,
      });
    }
    export function setInitialValidatorSet(
      tx: Transaction,
      args: [
        string | TransactionObjectArgument | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
      ],
    ): TransactionArgument & [TransactionArgument, TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));
      _args.push(transactionArgumentOrVec(args[1], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::set_initial_validator_set",
        arguments: _args,
      });
    }
    export function setNextValidatorSet(
      tx: Transaction,
      args: [
        string | TransactionObjectArgument | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
      ],
    ): TransactionArgument &
      [TransactionArgument, TransactionArgument, TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));
      _args.push(transactionArgumentOrVec(args[1], tx));
      _args.push(transactionArgumentOrVec(args[2], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::set_next_validator_set",
        arguments: _args,
      });
    }
    export function setValsetAction(
      tx: Transaction,
      args: [
        string | TransactionObjectArgument | TransactionArgument,
        number | TransactionArgument,
      ],
    ): TransactionArgument & [TransactionArgument, TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));
      _args.push(transactionArgumentOrPureU32(args[1], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::set_valset_action",
        arguments: _args,
      });
    }
    export function validatePayload(
      tx: Transaction,
      args: [
        string | TransactionObjectArgument | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
      ],
    ): TransactionArgument &
      [TransactionArgument, TransactionArgument, TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrObject(args[0], tx));
      _args.push(transactionArgumentOrVec(args[1], tx));
      _args.push(transactionArgumentOrVec(args[2], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::validate_payload",
        arguments: _args,
      });
    }
    export function validateSignatures(
      tx: Transaction,
      args: [
        (string | TransactionObjectArgument)[] | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
        bigint | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
        (string | TransactionObjectArgument)[] | TransactionArgument,
      ],
    ): TransactionArgument &
      [
        TransactionArgument,
        TransactionArgument,
        TransactionArgument,
        TransactionArgument,
        TransactionArgument,
        TransactionArgument,
      ] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrVec(args[0], tx));
      _args.push(transactionArgumentOrVec(args[1], tx));
      _args.push(transactionArgumentOrVec(args[2], tx));
      _args.push(transactionArgumentOrPureU256(args[3], tx));
      _args.push(transactionArgumentOrVec(args[4], tx));
      _args.push(transactionArgumentOrVec(args[5], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::consortium::validate_signatures",
        arguments: _args,
      });
    }
  }
  export namespace view {
    export async function addAdmin(
      client: SuiClient,
      args: [string, string],
    ): Promise<TypedDevInspectResults<[]>> {
      const tx = new Transaction();
      builder.addAdmin(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[]>(
        inspectRes,
      );
    }
    export async function getEpoch(
      client: SuiClient,
      args: [string],
    ): Promise<TypedDevInspectResults<[bigint]>> {
      const tx = new Transaction();
      builder.getEpoch(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[bigint]>(
        inspectRes,
      );
    }
    export async function getValidatorSet(
      client: SuiClient,
      args: [string, bigint],
    ): Promise<TypedDevInspectResults<[string]>> {
      const tx = new Transaction();
      builder.getValidatorSet(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[string]>(
        inspectRes,
      );
    }
    export async function removeAdmin(
      client: SuiClient,
      args: [string, string],
    ): Promise<TypedDevInspectResults<[]>> {
      const tx = new Transaction();
      builder.removeAdmin(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[]>(
        inspectRes,
      );
    }
    export async function setInitialValidatorSet(
      client: SuiClient,
      args: [string, string[]],
    ): Promise<TypedDevInspectResults<[]>> {
      const tx = new Transaction();
      builder.setInitialValidatorSet(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[]>(
        inspectRes,
      );
    }
    export async function setNextValidatorSet(
      client: SuiClient,
      args: [string, string[], string[]],
    ): Promise<TypedDevInspectResults<[]>> {
      const tx = new Transaction();
      builder.setNextValidatorSet(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[]>(
        inspectRes,
      );
    }
    export async function setValsetAction(
      client: SuiClient,
      args: [string, number],
    ): Promise<TypedDevInspectResults<[]>> {
      const tx = new Transaction();
      builder.setValsetAction(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[]>(
        inspectRes,
      );
    }
    export async function validatePayload(
      client: SuiClient,
      args: [string, string[], string[]],
    ): Promise<TypedDevInspectResults<[]>> {
      const tx = new Transaction();
      builder.validatePayload(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[]>(
        inspectRes,
      );
    }
    export async function validateSignatures(
      client: SuiClient,
      args: [string[], string[], string[], bigint, string[], string[]],
    ): Promise<TypedDevInspectResults<[boolean]>> {
      const tx = new Transaction();
      builder.validateSignatures(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[boolean]>(
        inspectRes,
      );
    }
  }
}

export namespace payload_decoder {
  export namespace builder {
    export function decodeFeePayload(
      tx: Transaction,
      args: [(string | TransactionObjectArgument)[] | TransactionArgument],
    ): TransactionArgument & [TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrVec(args[0], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::payload_decoder::decode_fee_payload",
        arguments: _args,
      });
    }
    export function decodeMintPayload(
      tx: Transaction,
      args: [(string | TransactionObjectArgument)[] | TransactionArgument],
    ): TransactionArgument & [TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrVec(args[0], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::payload_decoder::decode_mint_payload",
        arguments: _args,
      });
    }
    export function decodeSignatures(
      tx: Transaction,
      args: [(string | TransactionObjectArgument)[] | TransactionArgument],
    ): TransactionArgument & [TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrVec(args[0], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::payload_decoder::decode_signatures",
        arguments: _args,
      });
    }
    export function decodeValset(
      tx: Transaction,
      args: [(string | TransactionObjectArgument)[] | TransactionArgument],
    ): TransactionArgument & [TransactionArgument] {
      const _args: any[] = [];
      _args.push(transactionArgumentOrVec(args[0], tx));

      // @ts-ignore
      return tx.moveCall({
        target:
          "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3::payload_decoder::decode_valset",
        arguments: _args,
      });
    }
  }
  export namespace view {
    export async function decodeFeePayload(
      client: SuiClient,
      args: [string[]],
    ): Promise<
      TypedDevInspectResults<[number, bigint, string, bigint, bigint]>
    > {
      const tx = new Transaction();
      builder.decodeFeePayload(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<
        [number, bigint, string, bigint, bigint]
      >(inspectRes);
    }
    export async function decodeMintPayload(
      client: SuiClient,
      args: [string[]],
    ): Promise<
      TypedDevInspectResults<[number, bigint, string, bigint, bigint, bigint]>
    > {
      const tx = new Transaction();
      builder.decodeMintPayload(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<
        [number, bigint, string, bigint, bigint, bigint]
      >(inspectRes);
    }
    export async function decodeSignatures(
      client: SuiClient,
      args: [string[]],
    ): Promise<TypedDevInspectResults<[number[][]]>> {
      const tx = new Transaction();
      builder.decodeSignatures(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<[number[][]]>(
        inspectRes,
      );
    }
    export async function decodeValset(
      client: SuiClient,
      args: [string[]],
    ): Promise<
      TypedDevInspectResults<[number, bigint, number[][], bigint[], bigint]>
    > {
      const tx = new Transaction();
      builder.decodeValset(tx, args);
      const inspectRes = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: ZERO_ADDRESS,
      });

      return (await getMoveCoder(client)).decodeDevInspectResult<
        [number, bigint, number[][], bigint[], bigint]
      >(inspectRes);
    }
  }
}

const MODULES = JSON.parse(
  '{"consortium":{"fileFormatVersion":6,"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","name":"consortium","friends":[],"structs":{"Consortium":{"abilities":{"abilities":["Key"]},"typeParameters":[],"fields":[{"name":"id","type":{"Struct":{"address":"0x2","module":"object","name":"UID","typeArguments":[]}}},{"name":"epoch","type":"U256"},{"name":"validator_set","type":{"Struct":{"address":"0x2","module":"table","name":"Table","typeArguments":["U256",{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"ValidatorSet","typeArguments":[]}}]}}},{"name":"valset_action","type":"U32"},{"name":"admins","type":{"Vector":"Address"}}]},"ValidatorSet":{"abilities":{"abilities":["Store"]},"typeParameters":[],"fields":[{"name":"pub_keys","type":{"Vector":{"Vector":"U8"}}},{"name":"weights","type":{"Vector":"U256"}},{"name":"weight_threshold","type":"U256"}]}},"exposedFunctions":{"add_admin":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"MutableReference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}},"Address",{"MutableReference":{"Struct":{"address":"0x2","module":"tx_context","name":"TxContext","typeArguments":[]}}}],"return":[]},"get_epoch":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"Reference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}}],"return":["U256"]},"get_validator_set":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"Reference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}},"U256"],"return":[{"Reference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"ValidatorSet","typeArguments":[]}}}]},"remove_admin":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"MutableReference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}},"Address",{"MutableReference":{"Struct":{"address":"0x2","module":"tx_context","name":"TxContext","typeArguments":[]}}}],"return":[]},"set_initial_validator_set":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"MutableReference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}},{"Vector":"U8"},{"MutableReference":{"Struct":{"address":"0x2","module":"tx_context","name":"TxContext","typeArguments":[]}}}],"return":[]},"set_next_validator_set":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"MutableReference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}},{"Vector":"U8"},{"Vector":"U8"}],"return":[]},"set_valset_action":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"MutableReference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}},"U32",{"MutableReference":{"Struct":{"address":"0x2","module":"tx_context","name":"TxContext","typeArguments":[]}}}],"return":[]},"validate_payload":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"MutableReference":{"Struct":{"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","module":"consortium","name":"Consortium","typeArguments":[]}}},{"Vector":"U8"},{"Vector":"U8"}],"return":[]},"validate_signatures":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"Vector":{"Vector":"U8"}},{"Vector":{"Vector":"U8"}},{"Vector":"U256"},"U256",{"Vector":"U8"},{"Vector":"U8"}],"return":["Bool"]}}},"payload_decoder":{"fileFormatVersion":6,"address":"0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3","name":"payload_decoder","friends":[],"structs":{},"exposedFunctions":{"decode_fee_payload":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"Vector":"U8"}],"return":["U32","U256","Address","U256","U256"]},"decode_mint_payload":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"Vector":"U8"}],"return":["U32","U256","Address","U256","U256","U256"]},"decode_signatures":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"Vector":"U8"}],"return":[{"Vector":{"Vector":"U8"}}]},"decode_valset":{"visibility":"Public","isEntry":false,"typeParameters":[],"parameters":[{"Vector":"U8"}],"return":["U32","U256",{"Vector":{"Vector":"U8"}},{"Vector":"U256"},"U256"]}}}}',
);

export function loadAllTypes(coder: MoveCoder) {
  _0x2.loadAllTypes(coder);
  for (const m of Object.values(MODULES)) {
    coder.load(
      m as any,
      "0x2af188f9cc293640ced68e89a4c5773ee84702df3f10bcd080ccb894116398c3",
    );
  }
}

loadAllTypes(defaultMoveCoder());
