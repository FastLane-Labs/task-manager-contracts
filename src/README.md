# Task Manager

Task scheduling and execution system for Monad blockchain using shMONAD for economic security.

## Overview

The Task Manager enables scheduling and execution of smart contract tasks with:
- Gas-based task categorization
- Block-based scheduling
- Economic security via shMONAD bonding

## Architecture

Core system components:

1. **TaskManagerEntrypoint**
   - Public interface
   - Access control and validation
   - Task scheduling and execution
   - Reentrancy protection

2. **TaskScheduler**
   - Task scheduling
   - Task quoting
   - Block-based scheduling
   - Task cancellation

3. **TaskExecutor**
   - Task execution
   - Environment management
   - Fee distribution
   - Execution safety

4. **LoadBalancer**
   - Load distribution
   - Block-based metrics
   - Task allocation
   - Performance tracking

5. **TaskPricing**
   - Fee calculation
   - Period-based averaging
   - Congestion adjustment
   - Base fee management

6. **TaskFactory**
   - Environment creation
   - CREATE2 deployment
   - Parameter embedding
   - Address generation

7. **TaskStorage**
   - State management
   - Metadata tracking
   - Load balancer state
   - Task queues

## Execution Environments

1. **BasicTaskEnvironment**
   - Provides isolated execution context
   - Validates pre-execution conditions
   - Logs execution events
   - Uses simple call pattern

2. **ReschedulingTaskEnvironment**
   - Extends basic environment
   - Adds automatic retry logic
   - Handles task rescheduling
   - Tracks execution attempts

## Core Interface

```solidity
interface ITaskManager {
    // Task Management
    function scheduleTask(Task calldata task, uint64 targetBlock) external returns (bytes32 taskId);
    function scheduleTaskWithQuote(Task calldata task, uint64 targetBlock, uint256 maxPayment) 
        external returns (bool scheduled, uint256 executionCost, bytes32 taskId);
    function cancelTask(bytes32 taskId) external;
    
    // Task Execution
    function executeQueuedTasks(address payoutAddress, uint256 targetGasReserve) 
        external returns (uint256 feesEarned, bool success);
    
    // Task Information
    function getAccountNonce(address account) external view returns (uint64);
    function estimateRequiredBond(Task calldata task, uint64 targetBlock) external view returns (uint256);
    function getTaskMetadata(bytes32 taskId) external view returns (TaskMetadata memory);
    function getNextExecutionBlockInRange(uint64 startBlock, uint64 endBlock) external view returns (uint64);
}
```

## Task Structure

```solidity
struct Task {
    address from;      // Task owner
    uint64 nonce;      // Account nonce
    Size size;         // Task size category
    bool cancelled;    // Cancellation status
    address target;    // Target contract
    bytes data;        // Execution data
}

enum Size {
    Small,   // <= 100,000 gas
    Medium,  // <= 250,000 gas
    Large    // <= 750,000 gas
}

struct TaskMetadata {
    address owner;    // Task owner
    uint64 nonce;     // Task nonce
    bool isActive;    // Active status
}
```

## Economic Security

The system uses shMONAD for economic security:
- Tasks require bonded shMONAD for execution
- Bond amounts are calculated dynamically based on:
  - Historical execution costs
  - Task size category
  - Block distance
  - Network congestion
- Fees are distributed between:
  - Executors (95%)
  - Protocol (5%)

## Load Balancing

The system implements a sophisticated load balancing mechanism:
- Multi-depth tracking system (B, C, D trackers)
- Dynamic fee adjustment based on historical data
- Block-based task distribution
- Bayesian prior updates for low demand periods
- Congestion-aware scheduling

## Load Balancer Workflow

The TaskLoadBalancer module manages task execution across different sizes and blocks:

### 1. Queue Selection at Execution Start
- **Execution Entry Point**
  - `executeTasks` call is delegated to `_execute` in TaskExecutor
  - Initial gas calculations and safety checks performed

- **Allocating Load**
  - `_allocateLoad` determines queue based on available gas
  - Reserves gas for post-execution operations
  - Checks queues in order: Large → Medium → Small
  - Selects earliest active block with pending tasks

### 2. Running the Selected Queue
- **Task Loading**
  - `_loadNextTask` fetches next task from current block
  - Validates task metadata and execution requirements

- **Task Execution**
  - Invokes task environment with size-specific gas limit
  - Handles execution results and state updates

- **Fee Handling**
  - `_getReimbursementAmount` computes fees
  - Updates execution metrics and distributes payments

### 3. Block Iteration
- **Block Advancement**
  - `_iterate` triggers when current block is complete
  - Uses bitmap flags for efficient block skipping
  - Leverages `_GROUP_SIZE` and `_BITMAP_SPECIFICITY` for optimization

- **State Management**
  - Updates metrics via `_storeSpecificTracker`
  - Maintains load balancer pointers
  - Ensures consistent state across executions

### 4. System Integration
- **Pricing Integration**
  - Provides metrics for dynamic fee calculation
  - Supports multi-depth tracking for fee adjustments

- **State Persistence**
  - Maintains execution metrics at block, group, and supergroup levels
  - Ensures consistent load balancer state across iterations

### Execution Flow

```mermaid
flowchart TD
    A["executeTasks"] --> B["_execute"]
    B --> C["Check gas"]
    C --> D{"Sufficient gas?"}
    D -- No --> J["Exit"]
    D -- Yes --> E["_allocateLoad"]
    E --> F["Select queue by size<br/>Large > Medium > Small"]
    F --> G["Set active block"]
    G --> H["_runQueue"]
    H --> I{"Block complete?"}
    I -- No --> H
    I -- Yes --> K["_iterate"]
    K --> L["Increment block<br/>Skip empty blocks"]
    L --> M{"Tasks found?"}
    M -- Yes --> G
    M -- No --> J
```

## Task Flow

```mermaid
sequenceDiagram
    participant U as User
    participant TM as TaskManagerEntrypoint
    participant TS as TaskScheduler
    participant TE as TaskExecutor
    participant TP as TaskPricing
    participant TL as TaskLoadBalancer
    participant TF as TaskFactory
    participant S as TaskStorage
    participant EE as Execution Environment

    U->>TM: scheduleTask(implementation, taskGasLimit, targetBlock, maxPayment, taskCallData)
    TM->>TS: _buildTaskMetadata(taskGasLimit, owner)
    TS->>TP: _getTaskQuote(size, targetBlock)
    TP->>TL: Get current metrics for fee calculation
    TL-->>TP: Return load balancing metrics
    TP-->>TS: Return executionCost and trackers
    TS->>TF: _createEnvironment(owner, taskNonce, implementation, taskData)
    TF->>EE: Deploy environment via CREATE2 (if not deployed)
    TS->>S: Store task metadata & update task queue (S_taskIdQueue)
    TM-->>U: Emit TaskScheduled(taskId, owner, targetBlock)

    Note over U,TM: Later, at execution time...
    
    U/Executor->>TM: executeTasks(payoutAddress, targetGasReserve)
    TM->>TE: _execute(payoutAddress, targetGasReserve)
    loop While gas available & tasks exist
      TE->>S: Load next task from queue
      TE->>EE: executeTask(taskData) via delegatecall/call
      EE-->>TE: Return execution result (success/failure)
      TE->>TP: _handleExecutionFees(executor, payout)
      TE->>S: Update execution metrics & load balancer state
    end
    TE-->>TM: Return feesEarned
```

## Component Architecture

```mermaid
graph TD
    subgraph Internal[Internal Components]
        subgraph Core[Core Contracts]
          A[TaskManagerEntrypoint]
          B[TaskScheduler]
          C[TaskExecutor]
          D[TaskPricing]
          E[TaskLoadBalancer]
          F[TaskFactory]
        end

        subgraph Storage[Storage Layer]
          G[TaskStorage]
        end

        subgraph Lib[Libraries]
          L[TaskBits]
          M[TaskAccountingMath]
          N[TaskTypes & Events]
        end
    end

    subgraph External[External Components]
        subgraph Env[Execution Environments]
          H[BasicTaskEnvironment]
          I[ReschedulingTaskEnvironment]
        end

        subgraph API[Interfaces]
          J[ITaskManager]
          K[ITaskExecutionEnvironment]
        end
    end

    A --> B
    B --> C
    C --> D
    D --> E
    B --> F
    F --> H
    F --> I
    A --> G
    B --> G
    E --> G
    J --> A
    K --> H
    K --> I
    L --> B
    L --> G
    M --> D
    N --> Core

    %% Add labels
    classDef default fill:#f9f9f9,stroke:#333,stroke-width:2px;
    classDef core fill:#e1f5fe,stroke:#0277bd,stroke-width:2px;
    classDef storage fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef env fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;
    classDef lib fill:#fff3e0,stroke:#ef6c00,stroke-width:2px;
    classDef api fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    
    class A,B,C,D,E,F core;
    class G storage;
    class H,I env;
    class J,K api;
    class L,M,N lib;
```

## Execution Environment

Tasks are executed in isolated environments:
- Deterministic addressing using CREATE2
- One environment per task
- No persistent state
- Strict gas limits per size category
- Comprehensive reentrancy protection

## Events

```solidity
event TaskScheduled(bytes32 indexed taskId, address indexed owner, uint64 targetBlock);
event ExecutionEnvironmentCreated(address indexed owner, address environment, address implementation, uint64 taskNonce);
event ExecutorReimbursed(address indexed executor, uint256 amount);
event ProtocolFeeCollected(uint256 amount);
```

## Usage Example

```solidity
// Create a task
Task memory task = Task({
    from: msg.sender,
    nonce: taskManager.getAccountNonce(msg.sender),
    size: Size.Small,
    cancelled: false,
    target: targetContract,
    data: encodedCalldata
});

// Get required bond
uint256 requiredBond = taskManager.estimateRequiredBond(task, targetBlock);

// Bond shMONAD
shMonad.bond(taskManager.POLICY_ID(), requiredBond);

// Schedule task
bytes32 taskId = taskManager.scheduleTask(task, targetBlock);
```

## Security Model

1. **Execution Isolation**
   - Isolated environments per task
   - No cross-task interference
   - Clean execution context

2. **Access Control**
   - Owner-based task management
   - Executor-only task execution
   - Protocol-controlled fee distribution

3. **Economic Security**
   - shMONAD-based bonding
   - Dynamic fee calculation
   - Fair distribution model

4. **Safety Measures**
   - Comprehensive reentrancy protection
   - Strict gas limits
   - Safe transfer patterns
   - Immutable critical addresses

## Libraries and Utilities

1. **TaskBits**
   - Efficient task metadata packing
   - Unpacking utilities
   - Storage optimization

2. **TaskAccountingMath**
   - Fee calculation helpers
   - Protocol fee constants
   - Weighted average computation

3. **Types and Errors**
   - Shared data structures
   - Custom error definitions
   - Event declarations