#[test_only]
module time_lock_DAO::TxScheduler_tests {
    use sui::event::{Self, Event};
    use sui::test_scenario::{Self, Scenario};
    use sui::test_utils;
    use sui::tx_context;
    use std::vector;
    use std::option;
    use time_lock_DAO::TxScheduler::{
        Self,
        ContractState,
        AdminCap,
        TxData,
        TxStatus,
        TxQueued,
        TxExecuted,
        TxCancelled,
        STATUS_QUEUED,
        STATUS_CANCELLED,
        STATUS_EXECUTED,
        MIN_DELAY,
        MAX_DELAY,
        GRACE_PERIOD,
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
            let timestamp = current_time + 100;

            TxScheduler::queue_tx(
                &mut state,
                b"tx1",
                TARGET,
                b"test_func",
                b"test_data",
                timestamp,
                ctx
            );

            let tx_details = TxScheduler::get_tx_details(&state, b"tx1");
            assert!(option::is_some(&tx_details), 1);

            let tx_data = option::extract(&mut tx_details).unwrap();
            assert!(tx_data.owner == USER1, 2);
            assert!(tx_data.target == TARGET, 3);
            assert!(tx_data.status == STATUS_QUEUED, 4);

            // Check event emission
            let events = test_scenario::emitted_events::<TxQueued>(&scenario);
            assert!(vector::length(&events) == 1, 5);
            let event = vector::borrow(&events, 0);
            assert!(event.tx_id == b"tx1", 6);
            assert!(event.owner == USER1, 7);
            assert!(event.target == TARGET, 8);
            assert!(event.timestamp == timestamp, 9);


            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_INVALID_TIMESTAMP)]
    fun test_queue_invalid_timestamp() {
        // ... (No changes here)
    }

    #[test]
    fun test_cancel_transaction() {
      // ... (No changes here)
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_UNAUTHORIZED)]
    fun test_cancel_unauthorized() {
        // ... (No changes here)
    }

    #[test]
    fun test_admin_update_delays() {
        // ... (No changes here)
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_INVALID_DELAY)]
    fun test_invalid_admin_update() {
       // ... (No changes here)
    }

    #[test]
    fun test_execute_valid_transaction() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, USER1);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);
            let timestamp = current_time + 100;

            TxScheduler::queue_tx(
                &mut state,
                b"tx1",
                TARGET,
                b"test_func",
                b"test_data",
                timestamp,
                ctx
            );
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(&mut scenario, USER2);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);

            TxScheduler::execute_tx(&mut state, b"tx1", ctx);

            let tx_details = TxScheduler::get_tx_details(&state, b"tx1");
            assert!(option::is_some(&tx_details), 10);
            let tx_data = option::extract(&mut tx_details).unwrap();
            assert!(tx_data.status == STATUS_EXECUTED, 11);
            let events = test_scenario::emitted_events::<TxExecuted>(&scenario);
            assert!(vector::length(&events) == 1, 12);
            let event = vector::borrow(&events, 0);
            assert!(event.tx_id == b"tx1", 13);
            assert!(event.executor == USER2, 14);
            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_TX_NOT_READY)]
    fun test_execute_not_ready() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, USER1);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);
            let timestamp = current_time + 100;

            TxScheduler::queue_tx(
                &mut state,
                b"tx1",
                TARGET,
                b"test_func",
                b"test_data",
                timestamp,
                ctx
            );
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(&mut scenario, USER2);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let current_time = tx_context::epoch_timestamp_ms(ctx);

            TxScheduler::execute_tx(&mut state, b"tx1", ctx); //Attempt to execute too early

            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = TxScheduler::E_TX_NOT_FOUND)]
    fun test_execute_non_existent() {
        let scenario = setup();
        test_scenario::next_tx(&mut scenario, USER2);
        {
            let state = test_scenario::take_shared<ContractState>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            TxScheduler::execute_tx(&mut state, b"non_existent_tx", ctx);
            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario);
    }
}