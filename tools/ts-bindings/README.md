# Starknet TypeScript Bindings Generator

Automatically generates TypeScript types and provider classes from Starknet contract ABIs.

## Overview

This tool takes a compiled Starknet contract and generates:
- TypeScript interface matching the contract ABI
- Provider class with typed methods for all contract functions
- ABI export for use with starknet.js
- Deployment scripts (declare, deploy, invoke)

## Quick Start

### Generate bindings for an existing contract

```bash
# Build your contract first
cd my_contract && scarb build

# Generate TypeScript bindings
./tools/ts-bindings/pipeline.sh ./my_contract ./my_contract_ts
```

### Create a new contract with bindings

```bash
# Initialize new Scarb contract and generate bindings
./tools/ts-bindings/pipeline.sh ./new_project ./new_project_ts --init
```

## Generated Project Structure

```
my_contract_ts/
├── src/
│   ├── index.ts                    # Re-exports everything
│   ├── HelloStarknetProvider.ts    # Typed contract provider
│   └── HelloStarknetAbi.ts         # ABI constant
├── scripts/
│   ├── declare.ts                  # Declare contract class
│   ├── deploy.ts                   # Deploy contract instance
│   └── invoke.ts                   # Example invocations
├── artifacts/
│   └── *.contract_class.json       # Contract artifacts
├── package.json
├── tsconfig.json
└── .env.example
```

## Usage

### 1. Configure environment

```bash
cp .env.example .env
# Edit .env with your credentials
```

### 2. Declare contract

```bash
bun run declare
# Copy the CLASS_HASH to .env
```

### 3. Deploy contract

```bash
bun run deploy
# Copy the CONTRACT_ADDRESS to .env
```

### 4. Interact with contract

```bash
bun run invoke
```

### Using the provider in your code

```typescript
import { HelloStarknetProvider, HelloStarknetAbi } from "./src";
import { Account, RpcProvider } from "starknet";

// For read-only operations
const provider = HelloStarknetProvider.fromAddress(
  contractAddress,
  HelloStarknetAbi,
  "http://localhost:5050"
);

const balance = await provider.get_balance();

// For write operations (needs account)
const rpc = new RpcProvider({ nodeUrl: "http://localhost:5050" });
const account = new Account(rpc, accountAddress, privateKey);

const contract = HelloStarknetProvider.withAccount(
  contractAddress,
  HelloStarknetAbi,
  account
);

await contract.increase_balance("42");
```

## Standalone Generator

You can also use the generator directly:

```bash
bun run tools/ts-bindings/generate.ts <contract_class.json> [output_dir]
```

## Type Mappings

| Cairo Type | TypeScript Type |
|------------|-----------------|
| `felt252` | `string` |
| `u8`, `u16`, `u32` | `number` |
| `u64`, `u128`, `u256` | `bigint` |
| `i8`, `i16`, `i32` | `number` |
| `i64`, `i128` | `bigint` |
| `bool` | `boolean` |
| `ContractAddress` | `string` |
| `ClassHash` | `string` |
| `Array<T>` | `T[]` |
| `Option<T>` | `T \| undefined` |

## Requirements

- [Bun](https://bun.sh/) runtime
- [Scarb](https://docs.swmansion.com/scarb/) for contract compilation
- [starknet.js](https://www.starknetjs.com/) (installed automatically)
