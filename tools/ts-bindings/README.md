# Starknet TypeScript Bindings Pipeline

Automated pipeline for generating TypeScript bindings from Starknet contracts, with built-in devnet testing.

## Overview

This pipeline takes a Cairo/Scarb contract and:
1. Builds the contract (Sierra + CASM artifacts)
2. Generates typed TypeScript provider classes
3. Creates deployment scripts (declare, deploy, invoke)
4. Generates integration tests
5. Automatically tests everything on a local devnet

## Quick Start

```bash
# Create a new contract with full TypeScript bindings and run tests
./tools/ts-bindings/pipeline.sh ./my_contract ./my_contract_ts --init

# Generate bindings for existing contract
./tools/ts-bindings/pipeline.sh ./existing_contract ./output_ts

# Generate bindings only (skip devnet testing)
./tools/ts-bindings/pipeline.sh ./my_contract ./my_contract_ts --init --no-test
```

## Requirements

- [Bun](https://bun.sh/) runtime
- [Scarb](https://docs.swmansion.com/scarb/) for contract compilation
- [starknet-devnet](https://github.com/0xSpaceShard/starknet-devnet-rs) for local testing
- [starknet.js](https://www.starknetjs.com/) v9+ (installed automatically)

## Pipeline Options

| Option | Description |
|--------|-------------|
| `--init` | Initialize a new Scarb contract project first |
| `--no-test` | Skip automatic devnet testing (just generate bindings) |

## Generated Project Structure

```
my_contract_ts/
├── src/
│   ├── index.ts                    # Re-exports everything
│   ├── HelloStarknetProvider.ts    # Typed contract provider
│   ├── HelloStarknetAbi.ts         # ABI constant
│   └── devnet/
│       └── devnet-data.ts          # Devnet utilities
├── scripts/
│   ├── declare.ts                  # Declare contract class
│   ├── deploy.ts                   # Deploy contract instance
│   └── invoke.ts                   # Example invocations
├── tests/
│   └── contract.test.ts            # Integration tests
├── artifacts/
│   ├── *.contract_class.json       # Sierra artifact
│   └── *.compiled_contract_class.json  # CASM artifact
├── package.json
├── tsconfig.json
├── test-results.log                # Test output (after running)
└── devnet.log                      # Devnet output (after running)
```

## Generated TypeScript API

### Provider Class

The generator creates a typed provider class for each contract:

```typescript
import { HelloStarknetProvider, HelloStarknetAbi } from "./src";
import { Account, RpcProvider } from "starknet";

// For read-only operations (no account needed)
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

### Type Mappings

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

## Devnet Integration

The pipeline uses pre-configured devnet accounts (seed 0):

```typescript
import {
  createTestAccount,
  createTestProvider,
  waitForDevnet,
  DEVNET_CONFIG,
} from "./src/devnet/devnet-data";

// Wait for devnet to be available
await waitForDevnet();

// Create provider and account
const provider = createTestProvider();
const account = createTestAccount(provider);

console.log("RPC URL:", DEVNET_CONFIG.rpcUrl);  // http://127.0.0.1:5050
console.log("Account:", account.address);
```

### Pre-configured Accounts

When devnet is started with `--seed 0 --accounts 5`:

| Role | Address | Use Case |
|------|---------|----------|
| admin | `0x064b48...` | Deployer, admin operations |
| user1 | `0x078662...` | Testing user interactions |
| user2 | `0x049dfb...` | Multi-user scenarios |
| user3 | `0x04f348...` | Additional test user |
| user4 | `0x00d513...` | Additional test user |

## Manual Testing

After generating bindings with `--no-test`, you can test manually:

```bash
cd my_contract_ts

# Start devnet
starknet-devnet --seed 0 --accounts 5

# Declare contract
bun run declare
# Output: CLASS_HASH=0x...

# Deploy contract
CLASS_HASH=0x... bun run deploy
# Output: CONTRACT_ADDRESS=0x...

# Run example invocations
CONTRACT_ADDRESS=0x... bun run invoke

# Run integration tests
CONTRACT_ADDRESS=0x... bun test
```

## Integration Points

### For Pipeline Integration

The pipeline can be integrated into larger workflows:

```bash
# In a CI/CD script or larger pipeline
./tools/ts-bindings/pipeline.sh "$CONTRACT_DIR" "$OUTPUT_DIR" --init

# Check exit code
if [ $? -eq 0 ]; then
  echo "All tests passed"
else
  echo "Tests failed - check $OUTPUT_DIR/test-results.log"
fi
```

### Output Files for Automation

| File | Purpose |
|------|---------|
| `test-results.log` | Full test output, class hash, contract address |
| `devnet.log` | Devnet startup and transaction logs |

### Extracting Results

```bash
# Extract class hash from logs
CLASS_HASH=$(grep "CLASS_HASH=" test-results.log | cut -d= -f2)

# Extract contract address from logs
CONTRACT_ADDRESS=$(grep "CONTRACT_ADDRESS=" test-results.log | cut -d= -f2)
```

## Customizing Generated Tests

The default test file tests basic read/write operations. For custom contracts, you may want to:

1. Edit `tests/contract.test.ts` after generation
2. Add contract-specific test cases
3. Test edge cases and error conditions

Example custom test:

```typescript
test("should reject zero amount", async () => {
  // Contract should revert with "Amount cannot be 0"
  await expect(contract.increase_balance("0")).rejects.toThrow();
});
```

## Troubleshooting

### "ENOENT: no such file or directory"
The contract wasn't built or paths are incorrect. Ensure Scarb.toml has:
```toml
[[target.starknet-contract]]
sierra = true
casm = true

[cairo]
enable-gas = true
```

### "argent/zero-pubkey" or account validation errors
Devnet wasn't started with the correct seed. Restart with:
```bash
starknet-devnet --seed 0 --accounts 5
```

### Test timeout
Blockchain transactions need time. The default timeout is 60 seconds. For slower systems:
```typescript
import { setDefaultTimeout } from "bun:test";
setDefaultTimeout(120_000); // 2 minutes
```

### "Insufficient transaction data" warning
This is a starknet.js fee estimation warning and can be ignored for devnet testing.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Scarb Contract │────▶│  pipeline.sh     │────▶│  TypeScript     │
│  (Cairo)        │     │                  │     │  Project        │
└─────────────────┘     │  1. Build        │     └─────────────────┘
                        │  2. Generate     │              │
                        │  3. Test         │              ▼
                        └──────────────────┘     ┌─────────────────┐
                                │                │  Devnet Tests   │
                                │                │  (automatic)    │
                                ▼                └─────────────────┘
                        ┌──────────────────┐
                        │  generate.ts     │
                        │  - Parse ABI     │
                        │  - Type mapping  │
                        │  - Provider gen  │
                        └──────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `pipeline.sh` | Main orchestration script |
| `generate.ts` | TypeScript binding generator |
| `../starknet-devnet-tools/devnet-data.ts` | Devnet utilities (copied to output) |

## starknet.js v9 Compatibility

This pipeline uses starknet.js v9+ which has different APIs from v6:

```typescript
// Contract constructor (v9 uses options object)
new Contract({ abi, address, providerOrAccount });

// Method calls (v9 calls methods directly)
const { transaction_hash } = await contract.increase_balance(amount);
await provider.waitForTransaction(transaction_hash);

// Account constructor (v9 uses options object)
new Account({ provider, address, signer });
```
