module time_lock_DAO::TxScheduler {
    use sui::event;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use std::option::{Self, Option};
    use std::vector;

    // Error codes
    const E_UNAUTHORIZED: u64 = 0;
    const E_INVALID_TIMESTAMP: u64 = 1;
    const E_INVALID_ADDRESS: u64 = 2;
    const E_INVALID_TX_DATA: u64 = 3;
    const E_TX_NOT_FOUND: u64 = 4;
    const E_TX_ALREADY_EXISTS: u64 = 5;
    const E_TX_NOT_READY: u64 = 6;
    const E_INVALID_DELAY: u64 = 8;

    // Constants
    const MIN_DELAY: u64 = 10; // Minimum delay in seconds
    const MAX_DELAY: u64 = 1000; // Maximum delay in seconds
    const GRACE_PERIOD: u64 = 1000; // Grace period in seconds
    const MAX_DATA_LENGTH: u64 = 10000; // Maximum allowed data length in bytes
    const ZERO_ADDRESS: address = @0x0;

    // Transaction status constants
    const STATUS_QUEUED: u8 = 0;
    const STATUS_EXECUTED: u8 = 1;
    const STATUS_CANCELLED: u8 = 2;

    // Capability for administrative actions
    struct AdminCap has key { id: UID }

    // Transaction data structure
    struct TxData has store, copy, drop {
        owner: address,
        target: address,
        function_name: vector<u8>,
        data: vector<u8>,
        timestamp: u64,
        status: u8,
        created_at: u64
    }

    // Contract state structure
    struct ContractState has key {
        id: UID,
        tx_map: Table<vector<u8>, TxData>,
        min_delay: u64,
        max_delay: u64,
        grace_period: u64
    }

    // Events for tracking
    struct TxQueued has copy, drop {
        tx_id: vector<u8>,
        owner: address,
        target: address,
        timestamp: u64
    }

    struct TxExecuted has copy, drop {
        tx_id: vector<u8>,
        executor: address
    }

    struct TxCancelled has copy, drop {
        tx_id: vector<u8>,
        canceller: address
    }

    // Initialize the contract
    public fun initialize(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx)
        };

        let contract_state = ContractState {
            id: object::new(ctx),
            tx_map: table::new(ctx),
            min_delay: MIN_DELAY,
            max_delay: MAX_DELAY,
            grace_period: GRACE_PERIOD
        };

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(contract_state);
    }

    // Helper function to validate addresses
    fun validate_address(addr: address) {
        assert!(addr != ZERO_ADDRESS, E_INVALID_ADDRESS);
    }

    // Helper function to validate transaction data
    fun validate_tx_data(tx_data: &TxData) {
        validate_address(tx_data.owner);
        validate_address(tx_data.target);
        assert!(!vector::is_empty(&tx_data.function_name), E_INVALID_TX_DATA);
        assert!(vector::length(&tx_data.data) <= MAX_DATA_LENGTH, E_INVALID_TX_DATA);
    }

    // Helper function to check timestamp validity
    fun is_timestamp_in_range(
        state: &ContractState,
        timestamp: u64,
        current_time: u64
    ): bool {
        timestamp >= current_time + state.min_delay && 
        timestamp <= current_time + state.max_delay
    }

    // Helper function to determine transaction executability
    fun is_executable(
        tx_data: &TxData,
        current_time: u64,
        grace_period: u64
    ): bool {
        current_time >= tx_data.timestamp && 
        current_time <= tx_data.timestamp + grace_period &&
        tx_data.status == STATUS_QUEUED
    }

    // Public function to queue a transaction
    public fun queue_tx(
        state: &mut ContractState,
        tx_id: vector<u8>,
        target: address,
        function_name: vector<u8>,
        data: vector<u8>,
        timestamp: u64,
        ctx: &TxContext
    ) {
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        assert!(!table::contains(&state.tx_map, tx_id), E_TX_ALREADY_EXISTS);
        assert!(is_timestamp_in_range(state, timestamp, current_time), E_INVALID_TIMESTAMP);

        let tx_data = TxData {
            owner: tx_context::sender(ctx),
            target,
            function_name,
            data,
            timestamp,
            status: STATUS_QUEUED,
            created_at: current_time
        };

        validate_tx_data(&tx_data);
        table::add(&mut state.tx_map, tx_id, tx_data);

        event::emit(TxQueued {
            tx_id,
            owner: tx_context::sender(ctx),
            target,
            timestamp
        });
    }

    // Public function to execute a transaction
    public fun execute_tx(
        state: &mut ContractState,
        tx_id: vector<u8>,
        ctx: &TxContext
    ) {
        assert!(table::contains(&state.tx_map, tx_id), E_TX_NOT_FOUND);
        
        let tx_data = table::borrow(&state.tx_map, tx_id);
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        
        assert!(is_executable(tx_data, current_time, state.grace_period), E_TX_NOT_READY);
        
        let mut tx_data = table::remove(&mut state.tx_map, tx_id);
        tx_data.status = STATUS_EXECUTED;
        table::add(&mut state.tx_map, tx_id, tx_data);

        event::emit(TxExecuted {
            tx_id,
            executor: tx_context::sender(ctx)
        });
    }

    // Public function to cancel a transaction
    public fun cancel_tx(
        state: &mut ContractState,
        tx_id: vector<u8>,
        ctx: &TxContext
    ) {
        assert!(table::contains(&state.tx_map, tx_id), E_TX_NOT_FOUND);
        
        let tx_data = table::borrow(&state.tx_map, tx_id);
        assert!(tx_data.owner == tx_context::sender(ctx), E_UNAUTHORIZED);
        assert!(tx_data.status == STATUS_QUEUED, E_TX_NOT_READY);
        
        let mut tx_data = table::remove(&mut state.tx_map, tx_id);
        tx_data.status = STATUS_CANCELLED;
        table::add(&mut state.tx_map, tx_id, tx_data);

        event::emit(TxCancelled {
            tx_id,
            canceller: tx_context::sender(ctx)
        });
    }

    // Admin function to update delay parameters
    public fun update_delays(
        _: &AdminCap,
        state: &mut ContractState,
        new_min_delay: u64,
        new_max_delay: u64,
        new_grace_period: u64
    ) {
        assert!(new_min_delay <= new_max_delay, E_INVALID_DELAY);
        assert!(new_grace_period > 0, E_INVALID_DELAY);
        
        state.min_delay = new_min_delay;
        state.max_delay = new_max_delay;
        state.grace_period = new_grace_period;
    }

    // View function to retrieve transaction details
    public fun get_tx_details(
        state: &ContractState,
        tx_id: vector<u8>
    ): Option<TxData> {
        if (table::contains(&state.tx_map, tx_id)) {
            option::some(*table::borrow(&state.tx_map, tx_id))
        } else {
            option::none()
        }
    }
}
