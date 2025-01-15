#[test_only]
module time_lock_DAO::TxScheduler_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::test_utils;
    use sui::tx_context;
    use std::vector;
    use std::option;
    use time_lock_DAO::TxScheduler::{
        Self, 
        ContractState, 
        AdminCap,
        get_tx_owner,
        get_tx_target,
        get_tx_status
    };

    const ADMIN: address = @0xA1;
    const USER1: address = @0xB1;
    const USER2: address = @0xB2;
    const TARGET: address = @0xC1;

    // Test helpers
    fun setup(): Scenario {
        let scenario = test_scenario::begin(ADMIN);
        {
            TxScheduler::initialize(test_scenario::ctx(&mut scenario));
        };
        scenario
    }

    #[test]
    fun test_initialization() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            assert!(TxScheduler::get_tx_details(&state, b"any") == option::none(), 0);
            test_scenario::return_shared(state);
            
            // Check admin cap
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        test_scenario::end(scenario);
    }

    #[test]
    fun test_queue_valid_transaction() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, USER1);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);
            
            TxScheduler::queue_tx(
                &mut state,
                b"tx1",
                TARGET,
                b"test_func",
                b"test_data",
                current_time + 100,
                ctx
            );

            let tx_details = TxScheduler::get_tx_details(&state, b"tx1");
            assert!(option::is_some(&tx_details), 1);
            
            let tx_data = option::extract(&mut tx_details);
            assert!(get_tx_owner(&tx_data) == USER1, 2);
            assert!(get_tx_target(&tx_data) == TARGET, 3);
            assert!(get_tx_status(&tx_data) == 0, 4); // STATUS_QUEUED

            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_INVALID_TIMESTAMP)]
    fun test_queue_invalid_timestamp() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, USER1);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);
            
            // Try to queue with timestamp too soon
            TxScheduler::queue_tx(
                &mut state,
                b"tx1",
                TARGET,
                b"test_func",
                b"test_data",
                current_time + 5, // Less than MIN_DELAY
                ctx
            );

            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }

    #[test]
    fun test_cancel_transaction() {
        let scenario = setup();
        
        // Queue a transaction
        test_scenario::next_tx(&mut scenario, USER1);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);
            
            TxScheduler::queue_tx(
                &mut state,
                b"tx1",
                TARGET,
                b"test_func",
                b"test_data",
                current_time + 100,
                ctx
            );
            
            test_scenario::return_shared(state);
        };

        // Cancel the transaction
        test_scenario::next_tx(&mut scenario, USER1);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            
            TxScheduler::cancel_tx(&mut state, b"tx1", ctx);
            
            // Verify cancellation
            let tx_details = TxScheduler::get_tx_details(&state, b"tx1");
            assert!(option::is_some(&tx_details), 7);
            let tx_data = option::extract(&mut tx_details);
            assert!(get_tx_status(&tx_data) == 2, 8); // STATUS_CANCELLED

            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_UNAUTHORIZED)]
    fun test_cancel_unauthorized() {
        let scenario = setup();
        
        // Queue a transaction as USER1
        test_scenario::next_tx(&mut scenario, USER1);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);
            
            TxScheduler::queue_tx(
                &mut state,
                b"tx1",
                TARGET,
                b"test_func",
                b"test_data",
                current_time + 100,
                ctx
            );
            
            test_scenario::return_shared(state);
        };

        // Try to cancel as USER2
        test_scenario::next_tx(&mut scenario, USER2);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            
            TxScheduler::cancel_tx(&mut state, b"tx1", ctx);
            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }

    #[test]
    fun test_admin_update_delays() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            
            TxScheduler::update_delays(
                &admin_cap,
                &mut state,
                20,  // new min delay
                2000, // new max delay
                1500  // new grace period
            );
            
            test_scenario::return_shared(state);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_INVALID_DELAY)]
    fun test_invalid_admin_update() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            
            // Try to set min_delay > max_delay
            TxScheduler::update_delays(
                &admin_cap,
                &mut state,
                2000, // min delay greater than max delay
                1000,
                1500
            );
            
            test_scenario::return_shared(state);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        test_scenario::end(scenario);
    }
}