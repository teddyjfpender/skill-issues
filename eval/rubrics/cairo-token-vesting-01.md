# Rubric: cairo-token-vesting-01

## Evaluation Criteria

### Step 1: Interface and Structs (Build)
- [ ] `VestingSchedule` struct defined with all fields:
  - `beneficiary: ContractAddress`
  - `total_amount: u64`
  - `start_time: u64`
  - `duration: u64`
  - `claimed_amount: u64`
- [ ] `ITokenVesting` trait defined with:
  - `create_vesting(ref self, beneficiary, total_amount, start_time, duration)`
  - `claim(ref self)`
  - `get_vesting_schedule(self, beneficiary) -> VestingSchedule`
  - `get_vested_amount(self, beneficiary) -> u64`
  - `get_claimable_amount(self, beneficiary) -> u64`
  - `get_admin(self) -> ContractAddress`
- [ ] Code compiles with `scarb build`

### Step 2: Storage and Constructor (Build)
- [ ] Storage struct contains `admin: ContractAddress`
- [ ] Storage struct contains `schedules: Map<ContractAddress, VestingSchedule>`
- [ ] Storage struct contains `total_allocated: u64`
- [ ] Constructor sets admin to deployer/caller
- [ ] Code compiles with `scarb build`

### Step 3: Vesting Calculation (Build)
- [ ] Vesting calculation function exists
- [ ] Returns 0 before start_time
- [ ] Returns total_amount after start_time + duration
- [ ] Returns proportional amount during vesting period
- [ ] Handles duration = 0 case
- [ ] Uses safe math (multiply before divide)
- [ ] Code compiles with `scarb build`

### Step 4: Create Vesting (Build)
- [ ] `create_vesting` function implemented
- [ ] Validates caller is admin
- [ ] Validates total_amount > 0
- [ ] Validates duration > 0
- [ ] Validates beneficiary doesn't have existing schedule
- [ ] Creates and stores VestingSchedule
- [ ] Updates total_allocated
- [ ] Code compiles with `scarb build`

### Step 5: Claim Function (Build)
- [ ] `claim` function implemented
- [ ] Gets caller as beneficiary
- [ ] Validates schedule exists
- [ ] Calculates claimable (vested - claimed)
- [ ] Validates claimable > 0
- [ ] Updates claimed_amount in storage
- [ ] Code compiles with `scarb build`

### Step 6: View Functions (Build)
- [ ] `get_vesting_schedule` returns schedule or asserts
- [ ] `get_vested_amount` calculates current vested
- [ ] `get_claimable_amount` returns vested - claimed
- [ ] `get_admin` returns admin address
- [ ] Code compiles with `scarb build`

### Step 7: Tests (Test)
- [ ] Test setup with snforge utilities
- [ ] Test create_vesting happy path
- [ ] Test only admin can create (non-admin fails)
- [ ] Test cannot create duplicate schedule
- [ ] Test vesting = 0 before start_time
- [ ] Test vesting = proportional during period
- [ ] Test vesting = total after duration
- [ ] Test claim updates claimed_amount
- [ ] Test cannot claim zero
- [ ] Test multiple claims over time
- [ ] Uses `start_cheat_caller_address` for admin testing
- [ ] Uses `start_cheat_block_timestamp_global` for time testing
- [ ] All tests pass with `snforge test`

## Scoring
- Steps 1-6: Build validation (5 points each) = 30 points
- Step 7: Test validation (15 points)
- Total: 45 points

## Key Implementation Notes

### Vesting Formula
```
if current_time < start_time:
    vested = 0
elif current_time >= start_time + duration:
    vested = total_amount
else:
    elapsed = current_time - start_time
    vested = total_amount * elapsed / duration
```

### Storage Pattern
```cairo
use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};

#[storage]
struct Storage {
    schedules: Map<ContractAddress, VestingSchedule>,
}

// Read
let schedule = self.schedules.entry(beneficiary).read();

// Write
self.schedules.entry(beneficiary).write(schedule);
```

### Test Cheats
```cairo
// Set caller for admin checks
start_cheat_caller_address(contract_address, admin_address);
// ... call admin function
stop_cheat_caller_address(contract_address);

// Set block timestamp for time-based tests
start_cheat_block_timestamp_global(500);
// ... call time-dependent function
stop_cheat_block_timestamp_global();
```

## Common Errors to Check
- [ ] Not importing `get_block_timestamp` from starknet
- [ ] Not importing storage traits properly
- [ ] Using `felt252` instead of `u64` for timestamps
- [ ] Integer overflow in vesting calculation
- [ ] Not checking schedule exists before operations
- [ ] Forgetting to update storage after claim
