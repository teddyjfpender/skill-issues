# Prompt ID: cairo-hello-contract-01

Task:
- Initialize a Starknet smart contract using Scarb's built-in hello-world template.

## Problem Description

Create a basic Starknet smart contract project using `scarb new` with the starknet-foundry test runner. The contract should be the standard hello-world template that Scarb provides.

This prompt tests that the evaluation framework can handle contract projects (vs library projects) and validates the build/test pipeline works correctly.

## Related Skills
- `cairo-quirks`

## Context

**Scarb Contract Template**: Running `scarb new <name> --test-runner starknet-foundry` creates a project with:
- A simple `HelloStarknet` contract with `increase_balance` and `get_balance` functions
- Storage using `felt252` for the balance
- Integration tests using snforge's `declare` and `deploy` pattern
- Proper `Scarb.toml` with starknet dependencies

**No Code Generation Required**: This prompt uses Scarb's built-in template. The task is to scaffold and validate, not to write custom code.

---

## Step 1: Project Initialization

Initialize the Scarb contract project.

**Requirements:**
- Use `scarb new` with `--test-runner starknet-foundry`
- Project should have standard structure:
  - `src/lib.cairo` with `HelloStarknet` contract
  - `tests/test_contract.cairo` with integration tests
  - `Scarb.toml` with starknet and snforge dependencies

**Validation:** Project files exist

---

## Step 2: Build Validation

Verify the contract compiles successfully.

**Requirements:**
- Run `scarb build`
- Contract class JSON should be generated in `target/dev/`
- No compilation errors

**Validation:** `scarb build` succeeds

---

## Step 3: Test Validation

Verify all tests pass.

**Requirements:**
- Run `scarb test` (which runs `snforge test`)
- Both integration tests should pass:
  - `test_increase_balance`
  - `test_cannot_increase_balance_with_zero_value`

**Validation:** All tests pass with `snforge test`

---

## Constraints

- Must use Scarb's built-in template (no custom contract code)
- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Contract ABI must be generated in `target/dev/`

## Deliverable

A working Scarb contract project with:
1. Standard hello-world contract from Scarb template
2. Passing build
3. Passing tests
4. Generated contract class JSON with ABI
