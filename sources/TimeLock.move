module TxScheduler {

    // Constants
    const MIN_DELAY: u64 = 10; // seconds
    const MAX_DELAY: u64 = 1000; // seconds
    const GRACE_PERIOD: u64 = 1000; // seconds

    // Define data types for transactions
    struct TxData {
        owner: address,
        target: address,
        function_name: vector<u8>,
        data: vector<u8>,
        timestamp: u64,
    }

    // Define contract state
    struct ContractState has key {
        tx_map: table<vector<u8>, TxData>, // Mapping TxId -> TxData
    }

    public fun initialize(owner: address): ContractState {
        ContractState {
            tx_map: table::new(),
        }
    }

    // Helper function to check if a timestamp is within the allowed range
    fun is_timestamp_in_range(timestamp: u64, current_time: u64): bool {
        timestamp >= current_time + MIN_DELAY && timestamp <= current_time + MAX_DELAY
    }

    // Helper function to check if a transaction is queued
    fun is_queued(state: &ContractState, tx_id: vector<u8>): bool {
        table::contains(&state.tx_map, tx_id)
    }

    // Helper function to retrieve transaction data
    fun get_tx_data(state: &ContractState, tx_id: vector<u8>): Option<TxData> {
        table::borrow(&state.tx_map, tx_id)
    }

    // Helper function to check if a transaction is executable
    fun is_executable(state: &ContractState, tx_id: vector<u8>, current_time: u64): bool {
        if let Some(tx_data) = table::borrow(&state.tx_map, tx_id) {
            tx_data.timestamp <= current_time + GRACE_PERIOD
        } else {
            false
        }
    }

    // Helper function to execute a transaction
    public fun execute_tx(
        state: &mut ContractState,
        tx_id: vector<u8>,
        current_time: u64
    ): bool {
        if let Some(tx_data) = table::borrow_mut(&mut state.tx_map, tx_id) {
            if is_executable(state, tx_id, current_time) {
                // Logic to execute the transaction (e.g., call target contract)
                table::remove(&mut state.tx_map, tx_id);
                true
            } else {
                false
            }
        } else {
            false
        }
    }

    // Public function to queue a transaction
    public fun queue_tx(
        state: &mut ContractState,
        tx_id: vector<u8>,
        tx_data: TxData,
        current_time: u64
    ): bool {
        if !is_queued(state, tx_id) && is_timestamp_in_range(tx_data.timestamp, current_time) {
            table::add(&mut state.tx_map, tx_id, tx_data);
            true
        } else {
            false
        }
    }

    // Public function to cancel a transaction
    public fun cancel_tx(
        state: &mut ContractState,
        tx_id: vector<u8>,
        owner: address
    ): bool {
        if let Some(tx_data) = table::borrow(&state.tx_map, tx_id) {
            if tx_data.owner == owner {
                table::remove(&mut state.tx_map, tx_id);
                true
            } else {
                false
            }
        } else {
            false
        }
    }
}
