# TimeLock DAO - Transaction Scheduler

## This Sui Move smart contract module implements a time-locked transaction scheduler for a Decentralized Autonomous Organization (DAO). It allows authorized users to schedule transactions that are executed after a specified delay, ensuring a transparent and controlled execution process.

### Key Features:

**Transaction Scheduling:** Users can submit transactions specifying a target contract, function to call, and data to pass. These transactions are queued for execution after a configurable delay.

**Time-Locking:** Transactions are not executed immediately but wait for a predefined minimum and maximum delay window. This allows for community review and potential cancellation before execution.

**Authorization:** Only the transaction owner can cancel a scheduled transaction. A separate admin capability is used to update the minimum delay, maximum delay, and grace period parameters.

**Event Emission:** The contract emits events for transaction queuing, execution, and cancellation, enabling monitoring and tracking of transaction lifecycles.

**Contract Structure:**

### The contract is implemented using the Sui Move language and consists of several key components:

**Error Codes:** Defined constants representing various error conditions that can occur during transaction operations (e.g., unauthorized access, invalid timestamp).

**Constants:** Global variables for minimum delay, maximum delay, grace period, and maximum data length allowed in transactions.

**Transaction Statuses:** Enumerated constants representing the possible states of a transaction (queued, executed, cancelled).

**Capabilities:**

``AdminCap``: A capability struct used to identify authorized admins who can update delay parameters.

**Data Structures:**

``TxData``: Struct representing a scheduled transaction with details like owner, target, function name, data, timestamp, status, and creation time.

``ContractState``: Struct representing the overall state of the time-lock scheduler, including the transaction queue (implemented as a Sui Move table), minimum delay, maximum delay, and grace period.

**Events:**

``TxQueued``: Emitted when a transaction is successfully added to the queue.

``TxExecuted``: Emitted when a queued transaction is executed.

``TxCancelled``: Emitted when a scheduled transaction is cancelled by its owner.

**Public Functions:**

**initialize(ctx: &mut TxContext):** Initializes the contract by creating an admin capability and the contract state object.

**queue_tx(state: &mut ContractState, tx_id: vector<u8>, target: address, function_name: vector<u8>, data: vector<u8>, timestamp: u64, ctx: &mut TxContext):** Schedules a new transaction. It performs various checks like authorization, timestamp validity, and data size before adding the transaction to the queue and emitting a ``TxQueued`` event.

**execute_tx(state: &mut ContractState, tx_id: vector<u8>, ctx:** &mut TxContext): Executes a queued transaction if it's within the valid time window (considering minimum delay, maximum delay, and grace period). It updates the transaction status, emits a ``TxExecuted`` event, and performs the actual execution (not implemented in this code example).

**cancel_tx(state: &mut ContractState, tx_id: vector<u8>, ctx: &mut TxContext):** Cancels a scheduled transaction by its owner. It verifies ownership and transaction status before updating the status to cancelled and emitting a ``TxCancelled`` event.

**update_delays(cap: &AdminCap, state: &mut ContractState, new_min_delay: u64, new_max_delay: u64, new_grace_period: u64):** Updates the minimum delay, maximum delay, and grace period parameters by an authorized admin. It performs validation to ensure the minimum delay is less than or equal to the maximum delay and the grace period is positive.

**get_tx_details(state: &ContractState, tx_id: vector<u8>): Option<TxData>** Retrieves details of a specific transaction by its ID if it exists in the queue, returning ``None`` otherwise.

**Getting Started:**

Compile the Move code using the Sui compiler.

Deploy the contract to your Sui testnet or development environment.

Interact with the contract functions using Sui Move transactions to schedule, execute, cancel transactions, and update delay parameters.

**Note:** This code example provides a foundational implementation of a time-locked transaction scheduler. Additional features like access control mechanisms for specific functions and integration with other contracts for execution logic can be further built upon this base.