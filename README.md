# TestTimelockDAO

`TestTimelockDAO` is a Move module designed to test the core functionalities of the `TxScheduler` module. The `TxScheduler` module implements a basic timelock mechanism for scheduling, executing, and canceling transactions. This test module ensures the correctness of these functionalities through various test scenarios.

## Features

The module provides the following test functionalities:

1. **Initialization**: Verify that the scheduler initializes correctly with an empty transaction map.
2. **Transaction Queueing**: Test the ability to queue transactions and ensure they are stored properly in the timelock state.
3. **Timestamp Validation**: Ensure that transactions with invalid timestamps (e.g., timestamps in the past) are not queued.
4. **Transaction Execution**: Test the ability to execute queued transactions after their timelock has expired.
5. **Transaction Cancellation**: Validate that transactions can be canceled by their owners and removed from the timelock state.
6. **Unauthorized Cancellation**: Ensure that transactions cannot be canceled by non-owners.

## Module Overview

### Functions

#### 1. `create_tx_data`

Creates a dummy `TxData` structure for testing.

**Parameters**:

- `owner`: Address of the transaction owner.
- `target`: Target address of the transaction.
- `function_name`: Function name to be executed.
- `data`: Data payload for the transaction.
- `timestamp`: Scheduled timestamp for execution.

---

#### 2. `test_initialize`

Tests the initialization of the `TxScheduler` module to ensure it starts with an empty transaction map.

---

#### 3. `test_queue_tx`

Tests queuing a transaction and verifies that the transaction is successfully added to the timelock state.

---

#### 4. `test_queue_invalid_timestamp`

Tests that transactions with timestamps in the past are not allowed to be queued.

---

#### 5. `test_execute_tx`

Tests the execution of a valid transaction after the timelock duration has passed. Verifies that the transaction is removed from the state.

---

#### 6. `test_cancel_tx`

Tests the cancellation of a transaction by its owner. Ensures that the transaction is removed from the state.

---

#### 7. `test_cancel_tx_non_owner`

Tests that a transaction cannot be canceled by a non-owner, ensuring proper ownership enforcement.

---

## Usage

To run the tests provided in this module, use the `Test` framework in the Move environment. Follow these steps:

1. **Compile the Module**:
   Ensure the `TxScheduler` module is available in your project, and compile the `TestTimelockDAO` module:
   ```bash
   move build
   ```

Run Tests: Execute the test suite:
```
move test
```

Queuing a Transaction
This test ensures that a transaction can be successfully queued:
```
let mut state = TxScheduler::initialize(@0x1);
let tx_id = b"tx1";
let current_time = 100;
let tx_data = create_tx_data(@0x1, @0x2, b"test_func", b"test_data", current_time + 20);

let queued = TxScheduler::queue_tx(&mut state, tx_id, tx_data, current_time);
Test::assert(queued, 1);
Test::assert(table::contains(&state.tx_map, tx_id), 2);
```


Canceling a Transaction by Non-Owner
This test ensures only the owner of a transaction can cancel it:

```
let mut state = TxScheduler::initialize(@0x1);
let tx_id = b"tx5";
let current_time = 100;
let tx_data = create_tx_data(@0x1, @0x2, b"test_func", b"test_data", current_time + 20);

let _ = TxScheduler::queue_tx(&mut state, tx_id, tx_data, current_time);

let canceled = TxScheduler::cancel_tx(&mut state, tx_id, @0x3);
Test::assert(!canceled, 8);
```


