module TestTimelockDAO {

    use 0x1::Test;
    use 0x1::Signer;
    use 0x1::Vector;
    use TxScheduler;

    // Helper function to create dummy TxData
    fun create_tx_data(
        owner: address,
        target: address,
        function_name: vector<u8>,
        data: vector<u8>,
        timestamp: u64
    ): TxScheduler::TxData {
        TxScheduler::TxData {
            owner,
            target,
            function_name,
            data,
            timestamp,
        }
    }

    // Test initialization
    public fun test_initialize() {
        let state = TxScheduler::initialize(@0x1);
        Test::assert(table::length(&state.tx_map) == 0, 0);
    }

    // Test queuing a transaction
    public fun test_queue_tx() {
        let mut state = TxScheduler::initialize(@0x1);
        let current_time = 100;
        let tx_id = b"tx1";
        let tx_data = create_tx_data(@0x1, @0x2, b"test_func", b"test_data", current_time + 20);

        let queued = TxScheduler::queue_tx(&mut state, tx_id, tx_data, current_time);
        Test::assert(queued, 1);
        Test::assert(table::contains(&state.tx_map, tx_id), 2);
    }

    // Test queuing a transaction with an invalid timestamp
    public fun test_queue_invalid_timestamp() {
        let mut state = TxScheduler::initialize(@0x1);
        let current_time = 100;
        let tx_id = b"tx2";
        let tx_data = create_tx_data(@0x1, @0x2, b"test_func", b"test_data", current_time - 10);

        let queued = TxScheduler::queue_tx(&mut state, tx_id, tx_data, current_time);
        Test::assert(!queued, 3);
    }

    // Test executing a transaction
    public fun test_execute_tx() {
        let mut state = TxScheduler::initialize(@0x1);
        let current_time = 100;
        let tx_id = b"tx3";
        let tx_data = create_tx_data(@0x1, @0x2, b"test_func", b"test_data", current_time + 20);

        let _ = TxScheduler::queue_tx(&mut state, tx_id, tx_data, current_time);

        let executed = TxScheduler::execute_tx(&mut state, tx_id, current_time + 30);
        Test::assert(executed, 4);
        Test::assert(!table::contains(&state.tx_map, tx_id), 5);
    }

    // Test canceling a transaction
    public fun test_cancel_tx() {
        let mut state = TxScheduler::initialize(@0x1);
        let tx_id = b"tx4";
        let current_time = 100;
        let tx_data = create_tx_data(@0x1, @0x2, b"test_func", b"test_data", current_time + 20);

        let _ = TxScheduler::queue_tx(&mut state, tx_id, tx_data, current_time);

        let canceled = TxScheduler::cancel_tx(&mut state, tx_id, @0x1);
        Test::assert(canceled, 6);
        Test::assert(!table::contains(&state.tx_map, tx_id), 7);
    }

    // Test canceling a transaction by a non-owner
    public fun test_cancel_tx_non_owner() {
        let mut state = TxScheduler::initialize(@0x1);
        let tx_id = b"tx5";
        let current_time = 100;
        let tx_data = create_tx_data(@0x1, @0x2, b"test_func", b"test_data", current_time + 20);

        let _ = TxScheduler::queue_tx(&mut state, tx_id, tx_data, current_time);

        let canceled = TxScheduler::cancel_tx(&mut state, tx_id, @0x3);
        Test::assert(!canceled, 8);
    }
}
