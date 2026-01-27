use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct VestingSchedule {
    pub beneficiary: ContractAddress,
    pub total_amount: u64,
    pub start_time: u64,
    pub duration: u64,
    pub claimed_amount: u64,
}

#[starknet::interface]
pub trait ITokenVesting<TContractState> {
    fn create_vesting(
        ref self: TContractState,
        beneficiary: ContractAddress,
        total_amount: u64,
        start_time: u64,
        duration: u64,
    );
    fn claim(ref self: TContractState);
    fn get_vesting_schedule(self: @TContractState, beneficiary: ContractAddress) -> VestingSchedule;
    fn get_vested_amount(self: @TContractState, beneficiary: ContractAddress) -> u64;
    fn get_claimable_amount(self: @TContractState, beneficiary: ContractAddress) -> u64;
    fn get_admin(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod TokenVesting {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use core::num::traits::Zero;
    use super::{VestingSchedule, ITokenVesting};

    #[storage]
    struct Storage {
        admin: ContractAddress,
        schedules: Map<ContractAddress, VestingSchedule>,
        total_allocated: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.total_allocated.write(0);
    }

    fn calculate_vested_amount(schedule: VestingSchedule, current_time: u64) -> u64 {
        // Duration of 0: return total_amount immediately
        if schedule.duration == 0 {
            return schedule.total_amount;
        }

        // Before start_time: return 0
        if current_time < schedule.start_time {
            return 0;
        }

        let end_time = schedule.start_time + schedule.duration;

        // After end_time: return total_amount
        if current_time >= end_time {
            return schedule.total_amount;
        }

        // Linear vesting: total_amount * elapsed / duration
        let elapsed = current_time - schedule.start_time;
        
        // Use u128 for intermediate calculation to avoid overflow
        let total_amount_u128: u128 = schedule.total_amount.into();
        let elapsed_u128: u128 = elapsed.into();
        let duration_u128: u128 = schedule.duration.into();
        
        let vested_u128 = (total_amount_u128 * elapsed_u128) / duration_u128;
        
        // Safe to unwrap since result will fit in u64 (it's <= total_amount)
        vested_u128.try_into().unwrap()
    }

    #[abi(embed_v0)]
    impl TokenVestingImpl of ITokenVesting<ContractState> {
        fn create_vesting(
            ref self: ContractState,
            beneficiary: ContractAddress,
            total_amount: u64,
            start_time: u64,
            duration: u64,
        ) {
            // Only admin can create vesting schedules
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(caller == admin, 'Only admin can create vesting');

            // Validate inputs
            assert(total_amount > 0, 'Amount must be positive');
            assert(duration > 0, 'Duration must be positive');

            // Check beneficiary doesn't already have a schedule
            let existing_schedule = self.schedules.read(beneficiary);
            assert(existing_schedule.beneficiary.is_zero(), 'Already has schedule');

            let schedule = VestingSchedule {
                beneficiary,
                total_amount,
                start_time,
                duration,
                claimed_amount: 0,
            };
            self.schedules.write(beneficiary, schedule);
            let current_allocated = self.total_allocated.read();
            self.total_allocated.write(current_allocated + total_amount);
        }

        fn claim(ref self: ContractState) {
            let caller = get_caller_address();
            let mut schedule = self.schedules.read(caller);
            
            // Validate beneficiary has a schedule
            assert(!schedule.beneficiary.is_zero(), 'No vesting schedule');
            
            // Calculate claimable amount (vested - claimed)
            let current_time = get_block_timestamp();
            let vested = calculate_vested_amount(schedule, current_time);
            let claimable = vested - schedule.claimed_amount;
            
            // Validate claimable > 0
            assert(claimable > 0, 'Nothing to claim');
            
            // Update claimed_amount in storage
            schedule.claimed_amount = schedule.claimed_amount + claimable;
            self.schedules.write(caller, schedule);
            
            // In real contract: transfer tokens to caller
            // Skip for this exercise
        }

        fn get_vesting_schedule(self: @ContractState, beneficiary: ContractAddress) -> VestingSchedule {
            let schedule = self.schedules.read(beneficiary);
            assert(!schedule.beneficiary.is_zero(), 'No vesting schedule');
            schedule
        }

        fn get_vested_amount(self: @ContractState, beneficiary: ContractAddress) -> u64 {
            let schedule = self.schedules.read(beneficiary);
            let current_time = get_block_timestamp();
            calculate_vested_amount(schedule, current_time)
        }

        fn get_claimable_amount(self: @ContractState, beneficiary: ContractAddress) -> u64 {
            let schedule = self.schedules.read(beneficiary);
            let current_time = get_block_timestamp();
            let vested = calculate_vested_amount(schedule, current_time);
            vested - schedule.claimed_amount
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{ITokenVesting, ITokenVestingDispatcher, ITokenVestingDispatcherTrait};
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait,
                      start_cheat_caller_address, stop_cheat_caller_address,
                      start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};

    fn deploy_contract() -> (ITokenVestingDispatcher, ContractAddress) {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let contract = declare("TokenVesting").unwrap().contract_class();
        let constructor_calldata = array![admin.into()];
        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = ITokenVestingDispatcher { contract_address };
        (dispatcher, admin)
    }

    #[test]
    fn test_create_vesting_happy_path() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
        
        let schedule = dispatcher.get_vesting_schedule(beneficiary);
        assert(schedule.beneficiary == beneficiary, 'Wrong beneficiary');
        assert(schedule.total_amount == 1000, 'Wrong total amount');
        assert(schedule.start_time == 100, 'Wrong start time');
        assert(schedule.duration == 500, 'Wrong duration');
        assert(schedule.claimed_amount == 0, 'Wrong claimed amount');
    }

    #[test]
    #[should_panic(expected: 'Only admin can create vesting')]
    fn test_only_admin_can_create() {
        let (dispatcher, _admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        let non_admin: ContractAddress = contract_address_const::<'non_admin'>();
        
        start_cheat_caller_address(dispatcher.contract_address, non_admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Already has schedule')]
    fn test_cannot_create_duplicate_schedule() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        dispatcher.create_vesting(beneficiary, 2000, 200, 600);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_vesting_calculation_before_start() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
        
        // Set time before start
        start_cheat_block_timestamp_global(50);
        let vested = dispatcher.get_vested_amount(beneficiary);
        assert(vested == 0, 'Should be 0 before start');
        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_vesting_calculation_at_midpoint() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
        
        // Set time to midpoint (100 + 250 = 350)
        start_cheat_block_timestamp_global(350);
        let vested = dispatcher.get_vested_amount(beneficiary);
        assert(vested == 500, 'Should be 50% at midpoint');
        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_vesting_calculation_at_quarter() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
        
        // Set time to quarter (100 + 125 = 225)
        start_cheat_block_timestamp_global(225);
        let vested = dispatcher.get_vested_amount(beneficiary);
        assert(vested == 250, 'Should be 25% at quarter');
        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_claim_updates_claimed_amount() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
        
        // Set time to midpoint
        start_cheat_block_timestamp_global(350);
        
        // Claim as beneficiary
        start_cheat_caller_address(dispatcher.contract_address, beneficiary);
        dispatcher.claim();
        stop_cheat_caller_address(dispatcher.contract_address);
        
        let schedule = dispatcher.get_vesting_schedule(beneficiary);
        assert(schedule.claimed_amount == 500, 'Claimed should be 500');
        
        let claimable = dispatcher.get_claimable_amount(beneficiary);
        assert(claimable == 0, 'Claimable should be 0');
        
        stop_cheat_block_timestamp_global();
    }

    #[test]
    #[should_panic(expected: 'Nothing to claim')]
    fn test_cannot_claim_more_than_vested() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
        
        // Set time to midpoint and claim
        start_cheat_block_timestamp_global(350);
        start_cheat_caller_address(dispatcher.contract_address, beneficiary);
        dispatcher.claim();
        
        // Try to claim again at same time - should fail
        dispatcher.claim();
        stop_cheat_caller_address(dispatcher.contract_address);
        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_full_vesting_after_duration() {
        let (dispatcher, admin) = deploy_contract();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.create_vesting(beneficiary, 1000, 100, 500);
        stop_cheat_caller_address(dispatcher.contract_address);
        
        // Set time after end (100 + 500 = 600, so 700 is after)
        start_cheat_block_timestamp_global(700);
        let vested = dispatcher.get_vested_amount(beneficiary);
        assert(vested == 1000, 'Should be fully vested');
        
        // Claim all
        start_cheat_caller_address(dispatcher.contract_address, beneficiary);
        dispatcher.claim();
        stop_cheat_caller_address(dispatcher.contract_address);
        
        let schedule = dispatcher.get_vesting_schedule(beneficiary);
        assert(schedule.claimed_amount == 1000, 'Should claim all');
        
        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_get_admin() {
        let (dispatcher, admin) = deploy_contract();
        let retrieved_admin = dispatcher.get_admin();
        assert(retrieved_admin == admin, 'Admin mismatch');
    }
}
