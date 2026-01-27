#!/usr/bin/env bash
#
# Starknet Contract TypeScript Pipeline
#
# Creates a complete TypeScript project with bindings for a Starknet contract.
# Automatically starts devnet, declares, deploys, and tests the contract.
#
# Usage:
#   ./pipeline.sh <contract_dir> <output_dir> [options]
#
# Options:
#   --init      Initialize a new Scarb contract project first
#   --no-test   Skip automatic devnet testing (just generate bindings)
#
# Example:
#   ./pipeline.sh ./my_contract ./my_contract_ts
#   ./pipeline.sh ./new_project ./new_project_ts --init
#   ./pipeline.sh ./my_contract ./my_contract_ts --no-test
#
# The pipeline will:
#   1. Build contract and generate TypeScript bindings
#   2. Start starknet-devnet (seed 0, 5 accounts)
#   3. Declare, deploy, and invoke the contract
#   4. Stop devnet and dump logs (success or failure)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVNET_TOOLS_DIR="$(cd "$SCRIPT_DIR/../starknet-devnet-tools" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
  echo -e "${BOLD}Starknet Contract TypeScript Pipeline${NC}"
  echo ""
  echo "Usage: $0 <contract_dir> <output_dir> [options]"
  echo ""
  echo "Arguments:"
  echo "  contract_dir   Path to Scarb contract project"
  echo "  output_dir     Path for TypeScript output project"
  echo ""
  echo "Options:"
  echo "  --init         Initialize a new Scarb contract project first"
  echo "  --no-test      Skip automatic devnet testing (just generate bindings)"
  echo ""
  echo "By default, the pipeline will:"
  echo "  1. Build the contract and generate TypeScript bindings"
  echo "  2. Start a local starknet-devnet instance"
  echo "  3. Declare, deploy, and invoke the contract"
  echo "  4. Stop devnet and report results"
  echo ""
  echo "Examples:"
  echo "  $0 ./my_contract ./my_contract_ts"
  echo "  $0 ./new_project ./new_project_ts --init"
  echo "  $0 ./my_contract ./my_contract_ts --no-test"
}

# Parse arguments
if [[ $# -lt 2 ]]; then
  show_usage
  exit 1
fi

CONTRACT_DIR="$1"
OUTPUT_DIR="$2"
INIT_PROJECT=0
RUN_TEST=1  # Run test by default
SKIP_TEST=0
DEVNET_PID=""
LOG_FILE=""
ORIGINAL_DIR="$(pwd)"

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --init) INIT_PROJECT=1; shift ;;
    --no-test) SKIP_TEST=1; shift ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
done

# Convert paths to absolute (handle non-existent dirs for --init)
if [[ "$CONTRACT_DIR" != /* ]]; then
  CONTRACT_DIR="$ORIGINAL_DIR/$CONTRACT_DIR"
fi
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$ORIGINAL_DIR/$OUTPUT_DIR"
fi

# Cleanup function for devnet
cleanup_devnet() {
  if [[ -n "$DEVNET_PID" ]] && kill -0 "$DEVNET_PID" 2>/dev/null; then
    log_info "Stopping devnet (PID: $DEVNET_PID)..."
    kill "$DEVNET_PID" 2>/dev/null || true
    wait "$DEVNET_PID" 2>/dev/null || true
    log_success "Devnet stopped"
  fi
}

# Trap to ensure cleanup on exit
trap cleanup_devnet EXIT

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     Starknet Contract TypeScript Pipeline                     ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Initialize contract if requested
if [[ $INIT_PROJECT -eq 1 ]]; then
  log_info "Initializing new Scarb contract project..."
  PROJECT_NAME=$(basename "$CONTRACT_DIR")
  PARENT_DIR=$(dirname "$CONTRACT_DIR")
  mkdir -p "$PARENT_DIR"
  cd "$PARENT_DIR"
  scarb new "$PROJECT_NAME" --test-runner starknet-foundry

  # Ensure Scarb.toml has both sierra and casm enabled for artifacts
  SCARB_TOML="$CONTRACT_DIR/Scarb.toml"
  if grep -q "^\[\[target\.starknet-contract\]\]" "$SCARB_TOML"; then
    # Add casm = true if not present
    if ! grep -q "^casm = true" "$SCARB_TOML"; then
      sed -i '' '/^\[\[target\.starknet-contract\]\]/a\
casm = true
' "$SCARB_TOML"
      log_info "Added casm = true to Scarb.toml"
    fi
  fi

  # Add [cairo] enable-gas = true if not present
  if ! grep -q "^\[cairo\]" "$SCARB_TOML"; then
    echo -e "\n[cairo]\nenable-gas = true" >> "$SCARB_TOML"
    log_info "Added [cairo] enable-gas = true to Scarb.toml"
  fi

  log_success "Created Scarb project: $CONTRACT_DIR"
fi

# Validate contract directory
if [[ ! -d "$CONTRACT_DIR" ]]; then
  log_error "Contract directory not found: $CONTRACT_DIR"
  exit 1
fi

if [[ ! -f "$CONTRACT_DIR/Scarb.toml" ]]; then
  log_error "Not a Scarb project: $CONTRACT_DIR (missing Scarb.toml)"
  exit 1
fi

# Step 2: Build contract
log_info "Building contract..."
cd "$CONTRACT_DIR"
scarb build
log_success "Contract built successfully"

# Step 3: Find contract class JSON
# Find contract class JSON (exclude test contracts like *_tests.contract_class.json)
CONTRACT_CLASS=$(find target/dev -name "*.contract_class.json" -not -name "*_tests.contract_class.json" | head -1)
if [[ -z "$CONTRACT_CLASS" ]]; then
  log_error "No contract class JSON found in target/dev/"
  exit 1
fi
log_info "Found contract class: $CONTRACT_CLASS"

# Extract contract name
FILENAME=$(basename "$CONTRACT_CLASS" .contract_class.json)
CONTRACT_NAME=$(echo "$FILENAME" | rev | cut -d'_' -f1 | rev)
PACKAGE_NAME=$(basename "$CONTRACT_DIR")

log_info "Contract name: $CONTRACT_NAME"
log_info "Package name: $PACKAGE_NAME"

# Step 4: Create TypeScript project
log_info "Creating TypeScript project..."
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Initialize bun project if needed
if [[ ! -f "package.json" ]]; then
  cat > package.json << EOF
{
  "name": "${PACKAGE_NAME}-bindings",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "bun build ./src/index.ts --outdir ./dist",
    "declare": "bun run ./scripts/declare.ts",
    "deploy": "bun run ./scripts/deploy.ts",
    "invoke": "bun run ./scripts/invoke.ts",
    "test": "bun test"
  },
  "dependencies": {
    "starknet": "^9.2.1"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.0.0"
  }
}
EOF
  log_success "Created package.json"
fi

# Create tsconfig
if [[ ! -f "tsconfig.json" ]]; then
  cat > tsconfig.json << EOF
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*", "scripts/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF
  log_success "Created tsconfig.json"
fi

# Create .env.example (not needed for devnet with --seed 0, but useful for other networks)
cat > .env.example << EOF
# For devnet: just run 'starknet-devnet --seed 0 --accounts 5'
# The devnet utilities will use pre-configured accounts automatically.

# For testnet/mainnet, set these:
# RPC_URL=https://starknet-sepolia.public.blastapi.io
# ACCOUNT_ADDRESS=0x...
# PRIVATE_KEY=0x...

# After declaration:
# CLASS_HASH=0x...

# After deployment:
# CONTRACT_ADDRESS=0x...
EOF
log_success "Created .env.example"

# Step 5: Generate TypeScript bindings
log_info "Generating TypeScript bindings..."
mkdir -p src
bun run "$SCRIPT_DIR/generate.ts" "$CONTRACT_DIR/$CONTRACT_CLASS" ./src

# Copy contract artifacts
mkdir -p artifacts
cp "$CONTRACT_DIR/$CONTRACT_CLASS" "./artifacts/"
COMPILED_CLASS=$(echo "$CONTRACT_CLASS" | sed 's/contract_class/compiled_contract_class/')
if [[ -f "$CONTRACT_DIR/$COMPILED_CLASS" ]]; then
  cp "$CONTRACT_DIR/$COMPILED_CLASS" "./artifacts/"
fi
log_success "Copied contract artifacts"

# Copy devnet utilities
log_info "Adding devnet utilities..."
mkdir -p src/devnet
if [[ -f "$DEVNET_TOOLS_DIR/devnet-data.ts" ]]; then
  cp "$DEVNET_TOOLS_DIR/devnet-data.ts" "./src/devnet/"
  log_success "Copied devnet utilities"
else
  log_warn "Devnet utilities not found at $DEVNET_TOOLS_DIR/devnet-data.ts"
fi

# Step 6: Create deployment scripts
mkdir -p scripts

# Declare script
cat > scripts/declare.ts << 'SCRIPT_EOF'
/**
 * Declare the contract class on Starknet devnet
 *
 * Prerequisites:
 *   starknet-devnet --seed 0 --accounts 5
 */
import { json } from "starknet";
import { readFileSync } from "fs";
import {
  createTestAccount,
  createTestProvider,
  waitForDevnet,
  DEVNET_CONFIG,
} from "../src/devnet/devnet-data";

async function main() {
  console.log("╔════════════════════════════════════════╗");
  console.log("║     Declaring Contract on Devnet       ║");
  console.log("╚════════════════════════════════════════╝\n");

  // Wait for devnet
  await waitForDevnet();

  const provider = createTestProvider();
  const account = createTestAccount(provider);

  console.log("Account:", account.address);
  console.log("RPC URL:", DEVNET_CONFIG.rpcUrl);

  // Read contract class (Sierra) and compiled class (CASM)
SCRIPT_EOF
cat >> scripts/declare.ts << EOF
  const contractClass = json.parse(
    readFileSync("./artifacts/${FILENAME}.contract_class.json", "utf-8")
  );
  const compiledClass = json.parse(
    readFileSync("./artifacts/${FILENAME}.compiled_contract_class.json", "utf-8")
  );

  console.log("\\nDeclaring ${CONTRACT_NAME}...");
EOF
cat >> scripts/declare.ts << 'SCRIPT_EOF'

  // Declare with both Sierra and CASM
  const declareResponse = await account.declare({
    contract: contractClass,
    casm: compiledClass,
  });

  console.log("Transaction:", declareResponse.transaction_hash);
  await provider.waitForTransaction(declareResponse.transaction_hash);

  console.log("\n✓ Declaration successful!");
  console.log("Class hash:", declareResponse.class_hash);

  // Write to .env-like format for easy copy
  console.log("\n┌─────────────────────────────────────────┐");
  console.log("│ Add to scripts or copy:                 │");
  console.log("└─────────────────────────────────────────┘");
  console.log(`export CLASS_HASH="${declareResponse.class_hash}"`);
}

main().catch((err) => {
  console.error("Error:", err.message || err);
  process.exit(1);
});
SCRIPT_EOF

# Deploy script
cat > scripts/deploy.ts << 'SCRIPT_EOF'
/**
 * Deploy the contract to Starknet devnet
 *
 * Prerequisites:
 *   1. starknet-devnet --seed 0 --accounts 5
 *   2. Run declare.ts first to get CLASS_HASH
 */
import { CallData } from "starknet";
import {
  createTestAccount,
  createTestProvider,
  waitForDevnet,
  DEVNET_CONFIG,
} from "../src/devnet/devnet-data";

// Get CLASS_HASH from environment or command line
const CLASS_HASH = process.env.CLASS_HASH || process.argv[2];

async function main() {
  if (!CLASS_HASH) {
    console.error("Usage: bun run deploy <CLASS_HASH>");
    console.error("   or: CLASS_HASH=0x... bun run deploy");
    process.exit(1);
  }

  console.log("╔════════════════════════════════════════╗");
  console.log("║     Deploying Contract on Devnet       ║");
  console.log("╚════════════════════════════════════════╝\n");

  // Wait for devnet
  await waitForDevnet();

  const provider = createTestProvider();
  const account = createTestAccount(provider);

  console.log("Account:", account.address);
  console.log("Class hash:", CLASS_HASH);
SCRIPT_EOF
cat >> scripts/deploy.ts << EOF

  console.log("\\nDeploying ${CONTRACT_NAME}...");
EOF
cat >> scripts/deploy.ts << 'SCRIPT_EOF'

  // Deploy with empty constructor args
  const deployResponse = await account.deployContract({
    classHash: CLASS_HASH,
    constructorCalldata: CallData.compile([]),
  });

  console.log("Transaction:", deployResponse.transaction_hash);
  await provider.waitForTransaction(deployResponse.transaction_hash);

  console.log("\n✓ Deployment successful!");
  console.log("Contract address:", deployResponse.contract_address);

  // Write to .env-like format for easy copy
  console.log("\n┌─────────────────────────────────────────┐");
  console.log("│ Add to scripts or copy:                 │");
  console.log("└─────────────────────────────────────────┘");
  console.log(`export CONTRACT_ADDRESS="${deployResponse.contract_address}"`);
}

main().catch((err) => {
  console.error("Error:", err.message || err);
  process.exit(1);
});
SCRIPT_EOF

# Invoke script (example)
cat > scripts/invoke.ts << 'SCRIPT_EOF'
/**
 * Example: Invoke contract functions on devnet
 *
 * Prerequisites:
 *   1. starknet-devnet --seed 0 --accounts 5
 *   2. Run declare.ts and deploy.ts first
 */
SCRIPT_EOF
cat >> scripts/invoke.ts << EOF
import { ${CONTRACT_NAME}Provider, ${CONTRACT_NAME}Abi } from "../src";
EOF
cat >> scripts/invoke.ts << 'SCRIPT_EOF'
import {
  createTestAccount,
  createTestProvider,
  waitForDevnet,
} from "../src/devnet/devnet-data";

// Get CONTRACT_ADDRESS from environment or command line
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || process.argv[2];

async function main() {
  if (!CONTRACT_ADDRESS) {
    console.error("Usage: bun run invoke <CONTRACT_ADDRESS>");
    console.error("   or: CONTRACT_ADDRESS=0x... bun run invoke");
    process.exit(1);
  }

  console.log("╔════════════════════════════════════════╗");
  console.log("║     Interacting with Contract          ║");
  console.log("╚════════════════════════════════════════╝\n");

  // Wait for devnet
  await waitForDevnet();

  const provider = createTestProvider();
  const account = createTestAccount(provider);

  console.log("Contract:", CONTRACT_ADDRESS);
  console.log("Account:", account.address);
SCRIPT_EOF
cat >> scripts/invoke.ts << EOF

  // Create provider with account (for write operations)
  const contract = ${CONTRACT_NAME}Provider.withAccount(
    CONTRACT_ADDRESS,
    ${CONTRACT_NAME}Abi,
    account
  );

  // Read balance
  console.log("\\n─── Reading balance ───");
  const balanceBefore = await contract.get_balance();
  console.log("Balance before:", balanceBefore);

  // Increase balance
  console.log("\\n─── Increasing balance by 42 ───");
  await contract.increase_balance("42");
  console.log("✓ Transaction confirmed");

  // Read balance again
  console.log("\\n─── Reading balance again ───");
  const balanceAfter = await contract.get_balance();
  console.log("Balance after:", balanceAfter);

  console.log("\\n✓ All operations completed successfully!");
}

main().catch((err) => {
  console.error("Error:", err.message || err);
  process.exit(1);
});
EOF

log_success "Created deployment scripts"

# Step 7: Create test files
log_info "Creating test files..."
mkdir -p tests

cat > tests/contract.test.ts << 'SCRIPT_EOF'
/**
 * Contract integration tests
 *
 * These tests run against a live devnet instance.
 * Prerequisites:
 *   1. starknet-devnet --seed 0 --accounts 5
 *   2. Contract must be declared and deployed first
 *
 * Run with: CONTRACT_ADDRESS=0x... bun test
 */
import { describe, test, expect, beforeAll, setDefaultTimeout } from "bun:test";

// Blockchain transactions need more time
setDefaultTimeout(60_000);

SCRIPT_EOF
cat >> tests/contract.test.ts << EOF
import { ${CONTRACT_NAME}Provider, ${CONTRACT_NAME}Abi } from "../src";
EOF
cat >> tests/contract.test.ts << 'SCRIPT_EOF'
import {
  createTestAccount,
  createTestProvider,
  waitForDevnet,
} from "../src/devnet/devnet-data";

const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;

describe("Contract Integration Tests", () => {
  let contract: any;

  beforeAll(async () => {
    if (!CONTRACT_ADDRESS) {
      throw new Error("CONTRACT_ADDRESS environment variable is required");
    }

    await waitForDevnet();
    const provider = createTestProvider();
    const account = createTestAccount(provider);
SCRIPT_EOF
cat >> tests/contract.test.ts << EOF

    contract = ${CONTRACT_NAME}Provider.withAccount(
      CONTRACT_ADDRESS,
      ${CONTRACT_NAME}Abi,
      account
    );
EOF
cat >> tests/contract.test.ts << 'SCRIPT_EOF'
  });

  test("should read initial balance", async () => {
    const balance = await contract.get_balance();
    expect(balance).toBeDefined();
    console.log("Current balance:", balance);
  });

  test("should increase balance", async () => {
    const balanceBefore = await contract.get_balance();
    const beforeValue = BigInt(balanceBefore);

    await contract.increase_balance("100");

    const balanceAfter = await contract.get_balance();
    const afterValue = BigInt(balanceAfter);

    expect(afterValue).toBe(beforeValue + 100n);
    console.log(`Balance changed: ${beforeValue} -> ${afterValue}`);
  });
});
SCRIPT_EOF

log_success "Created test files"

# Step 8: Install dependencies
log_info "Installing dependencies..."
bun install
log_success "Dependencies installed"

# Generation complete
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║     Generation Complete!                                      ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Generated TypeScript project:${NC} $OUTPUT_DIR"
echo ""
echo -e "${BOLD}Files:${NC}"
echo "  src/${CONTRACT_NAME}Provider.ts  - Contract provider class"
echo "  src/${CONTRACT_NAME}Abi.ts       - Contract ABI export"
echo "  scripts/declare.ts               - Declare contract class"
echo "  scripts/deploy.ts                - Deploy contract"
echo "  scripts/invoke.ts                - Example invocations"
echo "  tests/contract.test.ts           - Integration tests"
echo ""

# Skip test if requested
if [[ $SKIP_TEST -eq 1 ]]; then
  echo -e "${BOLD}Next steps (--no-test was specified):${NC}"
  echo "  1. Start a local devnet: starknet-devnet --seed 0 --accounts 5"
  echo "  2. Declare: bun run declare"
  echo "  3. Deploy: CLASS_HASH=0x... bun run deploy"
  echo "  4. Invoke: CONTRACT_ADDRESS=0x... bun run invoke"
  echo ""
  exit 0
fi

# Step 9: Start devnet and run tests
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     Running Contract Tests on Devnet                          ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Setup log file
LOG_FILE="$OUTPUT_DIR/test-results.log"
echo "Test Results - $(date)" > "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Start devnet
log_info "Starting starknet-devnet..."
DEVNET_LOG="$OUTPUT_DIR/devnet.log"
starknet-devnet --seed 0 --accounts 5 --port 5050 > "$DEVNET_LOG" 2>&1 &
DEVNET_PID=$!
echo "Devnet PID: $DEVNET_PID" >> "$LOG_FILE"

# Wait for devnet to be ready
log_info "Waiting for devnet to be ready..."
for i in {1..30}; do
  if curl -s http://127.0.0.1:5050/is_alive >/dev/null 2>&1; then
    log_success "Devnet is ready"
    echo "Devnet started successfully" >> "$LOG_FILE"
    break
  fi
  if [[ $i -eq 30 ]]; then
    log_error "Devnet failed to start"
    echo "ERROR: Devnet failed to start" >> "$LOG_FILE"
    cat "$DEVNET_LOG" >> "$LOG_FILE"
    exit 1
  fi
  sleep 1
done

# Run declare
echo "" >> "$LOG_FILE"
echo "--- DECLARE ---" >> "$LOG_FILE"
log_info "Declaring contract..."
DECLARE_OUTPUT=$(bun run declare 2>&1) || {
  log_error "Declaration failed"
  echo "DECLARE FAILED:" >> "$LOG_FILE"
  echo "$DECLARE_OUTPUT" >> "$LOG_FILE"
  echo ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║     Test Failed - Declaration Error                          ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "$DECLARE_OUTPUT"
  echo ""
  echo -e "${BOLD}Logs saved to:${NC} $LOG_FILE"
  echo -e "${BOLD}Devnet logs:${NC} $DEVNET_LOG"
  exit 1
}
echo "$DECLARE_OUTPUT" >> "$LOG_FILE"
log_success "Declaration successful"

# Extract class hash
CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oE '0x[a-fA-F0-9]+' | tail -1)
log_info "Class hash: $CLASS_HASH"
echo "CLASS_HASH=$CLASS_HASH" >> "$LOG_FILE"

# Run deploy
echo "" >> "$LOG_FILE"
echo "--- DEPLOY ---" >> "$LOG_FILE"
log_info "Deploying contract..."
DEPLOY_OUTPUT=$(CLASS_HASH="$CLASS_HASH" bun run deploy 2>&1) || {
  log_error "Deployment failed"
  echo "DEPLOY FAILED:" >> "$LOG_FILE"
  echo "$DEPLOY_OUTPUT" >> "$LOG_FILE"
  echo ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║     Test Failed - Deployment Error                           ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "$DEPLOY_OUTPUT"
  echo ""
  echo -e "${BOLD}Logs saved to:${NC} $LOG_FILE"
  echo -e "${BOLD}Devnet logs:${NC} $DEVNET_LOG"
  exit 1
}
echo "$DEPLOY_OUTPUT" >> "$LOG_FILE"
log_success "Deployment successful"

# Extract contract address
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE '0x[a-fA-F0-9]+' | tail -1)
log_info "Contract address: $CONTRACT_ADDRESS"
echo "CONTRACT_ADDRESS=$CONTRACT_ADDRESS" >> "$LOG_FILE"

# Run invoke
echo "" >> "$LOG_FILE"
echo "--- INVOKE ---" >> "$LOG_FILE"
log_info "Testing contract invocation..."
INVOKE_OUTPUT=$(CONTRACT_ADDRESS="$CONTRACT_ADDRESS" bun run invoke 2>&1) || {
  log_error "Invocation failed"
  echo "INVOKE FAILED:" >> "$LOG_FILE"
  echo "$INVOKE_OUTPUT" >> "$LOG_FILE"
  echo ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║     Test Failed - Invocation Error                           ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "$INVOKE_OUTPUT"
  echo ""
  echo -e "${BOLD}Logs saved to:${NC} $LOG_FILE"
  echo -e "${BOLD}Devnet logs:${NC} $DEVNET_LOG"
  exit 1
}
echo "$INVOKE_OUTPUT" >> "$LOG_FILE"
log_success "Invocation successful"

# Run integration tests
echo "" >> "$LOG_FILE"
echo "--- TESTS ---" >> "$LOG_FILE"
log_info "Running integration tests..."
TEST_OUTPUT=$(CONTRACT_ADDRESS="$CONTRACT_ADDRESS" bun test 2>&1) || {
  log_error "Tests failed"
  echo "TESTS FAILED:" >> "$LOG_FILE"
  echo "$TEST_OUTPUT" >> "$LOG_FILE"
  echo ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║     Test Failed - Integration Tests Error                    ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "$TEST_OUTPUT"
  echo ""
  echo -e "${BOLD}Logs saved to:${NC} $LOG_FILE"
  echo -e "${BOLD}Devnet logs:${NC} $DEVNET_LOG"
  exit 1
}
echo "$TEST_OUTPUT" >> "$LOG_FILE"
log_success "Integration tests passed"

# All tests passed!
echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "ALL TESTS PASSED" >> "$LOG_FILE"
echo "Completed at: $(date)" >> "$LOG_FILE"

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║     All Tests Passed!                                         ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Results:${NC}"
echo "  Class Hash:       $CLASS_HASH"
echo "  Contract Address: $CONTRACT_ADDRESS"
echo ""
echo -e "${BOLD}Logs:${NC}"
echo "  Test results: $LOG_FILE"
echo "  Devnet logs:  $DEVNET_LOG"
echo ""
