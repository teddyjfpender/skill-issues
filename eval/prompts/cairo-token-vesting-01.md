# Prompt ID: cairo-token-vesting-01

Task:
- Implement a token vesting smart contract with linear vesting schedules

## Problem Description

Create a Starknet smart contract that manages token vesting schedules. The contract allows an admin to create vesting schedules for beneficiaries, who can then claim their vested tokens over time.

**Vesting Logic:**
- Linear vesting: tokens vest linearly from `start_time` over `duration` seconds
- Vested amount at time `t` = `total_amount * (t - start_time) / duration` (capped at total)
- Claimable = vested - already_claimed
- Before start_time, nothing is vested
- After start_time + duration, everything is vested

**Example 1:**
- Schedule: total=1000, start=100, duration=400
- At time 100: vested=0 (just started)
- At time 300: vested=500 (halfway through)
- At time 500+: vested=1000 (fully vested)

**Example 2:**
- Schedule: total=120, start=0, duration=12
- At time 3: vested=30 (25% of duration)
- At time 6: vested=60 (50% of duration)
- At time 12+: vested=120 (fully vested)

## Related Skills
- `cairo-quirks`
- `cairo-quality`
- `cairo-contract-storage`
- `cairo-storage-mappings`
- `cairo-contract-functions`
- `cairo-structs`
- `cairo-smart-contract-testing`
- `cairo-starknet-types`

## Context

**CRITICAL - Starknet Contract Structure:**
```cairo
#[starknet::interface]
pub trait IContractName<TContractState> {
    fn method_name(ref self: TContractState, arg: felt252);
    fn view_method(self: @TContractState) -> u64;
}

#[starknet::contract]
mod ContractName {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    #[storage]
    struct Storage {
        field: felt252,
    }

    #[abi(embed_v0)]
    impl ContractNameImpl of super::IContractName<ContractState> {
        fn method_name(ref self: ContractState, arg: felt252) { }
        fn view_method(self: @ContractState) -> u64 { 0 }
    }
}
```

**Storage Maps:** Use `starknet::storage::Map` for key-value storage:
```cairo
use starknet::storage::Map;

#[storage]
struct Storage {
    balances: Map<ContractAddress, u64>,
}

// Read: self.balances.entry(addr).read()
// Write: self.balances.entry(addr).write(value)
```

**Block Timestamp:** Use `get_block_timestamp()` which returns `u64`.

**Assertions:** Use `assert(condition, 'error message');` for validation.

---

## Step 1: Define Interface and Structs

Set up the contract interface and data structures.

**Requirements:**
- Define `VestingSchedule` struct with fields:
  - `beneficiary: ContractAddress`
  - `total_amount: u64`
  - `start_time: u64`
  - `duration: u64`
  - `claimed_amount: u64`
- Define `ITokenVesting` trait with methods:
  - `create_vesting(beneficiary, total_amount, start_time, duration)`
  - `claim()` - beneficiary claims their vested tokens
  - `get_vesting_schedule(beneficiary) -> VestingSchedule`
  - `get_vested_amount(beneficiary) -> u64`
  - `get_claimable_amount(beneficiary) -> u64`
  - `get_admin() -> ContractAddress`

**Validation:** Code compiles with `scarb build`

---

## Step 2: Storage and Constructor

Implement contract storage and initialization.

**Requirements:**
- Storage fields:
  - `admin: ContractAddress` - contract administrator
  - `schedules: Map<ContractAddress, VestingSchedule>` - vesting schedules by beneficiary
  - `total_allocated: u64` - total tokens allocated to schedules
- Constructor that sets the admin to the deployer

**Validation:** Code compiles with `scarb build`

---

## Step 3: Vesting Calculation Logic

Implement the core vesting calculation.

**Requirements:**
- Create internal function to calculate vested amount at current time
- Formula: `total_amount * elapsed / duration` (capped at total_amount)
- Handle edge cases:
  - Before start_time: return 0
  - After end_time (start + duration): return total_amount
  - Duration of 0: return total_amount immediately
- Use safe math to avoid overflow (multiply before divide)

**Validation:** Code compiles with `scarb build`

---

## Step 4: Create Vesting Schedule

Implement the create_vesting function.

**Requirements:**
- Only admin can create vesting schedules
- Validate inputs:
  - `total_amount > 0`
  - `duration > 0`
  - Beneficiary doesn't already have a schedule
- Store the new VestingSchedule
- Update total_allocated
- Emit event (optional for this exercise)

**Validation:** Code compiles with `scarb build`

---

## Step 5: Claim Function

Implement the claim function for beneficiaries.

**Requirements:**
- Get caller address as beneficiary
- Validate beneficiary has a schedule
- Calculate claimable amount (vested - claimed)
- Validate claimable > 0
- Update claimed_amount in storage
- (In real contract: transfer tokens - skip for this exercise)

**Validation:** Code compiles with `scarb build`

---

## Step 6: View Functions

Implement all view functions.

**Requirements:**
- `get_vesting_schedule`: Return schedule for beneficiary (assert exists)
- `get_vested_amount`: Return currently vested amount
- `get_claimable_amount`: Return vested - claimed
- `get_admin`: Return admin address

**Validation:** Code compiles with `scarb build`

---

## Step 7: Comprehensive Tests

Create tests using snforge's contract testing.

**Requirements:**
- Test schedule creation (happy path)
- Test only admin can create schedules
- Test cannot create duplicate schedule
- Test vesting calculation at different times
- Test claim updates claimed_amount correctly
- Test cannot claim more than vested
- Test full vesting after duration

**Test Setup:**
```cairo
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait,
                  start_cheat_caller_address, stop_cheat_caller_address,
                  start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
```

**Validation:** All tests pass with `snforge test`

---

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use `u64` for amounts and timestamps
- Handle all edge cases
- Follow Starknet contract patterns

## Deliverable

Complete `src/lib.cairo` with:
1. VestingSchedule struct
2. ITokenVesting interface
3. TokenVesting contract implementation
4. Comprehensive test suite
