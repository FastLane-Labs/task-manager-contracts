# Task Manager

Task Manager is a smart contract–based task scheduling and execution system designed for the Monad blockchain. It leverages shMONAD (staked MON) bonding for enhanced yield in between scheduling and execution, and uses advanced load balancing and dynamic fee pricing to schedule tasks with predictable gas usage. An emphasis was placed on optimizing the tradeoff between fee precision and gas efficiency.

## Overview

The system allows users to schedule smart contract tasks that will be executed in isolated environments at predetermined future blocks. Tasks are categorized by gas limits (Small, Medium, Large) and are queued using a block-based scheduling system.

## Key Features 
- **Designed for Monad:**  
  In the context of both block building and transaction pricing, Monad's asynchronous execution induces validators and users to evaluate a transaction's gas limit rather than its gas usage. This is because in asynchronous environments, a transaction's gas usage is not known until after a transaction has been executed, which occurs after it is included in a block that has been proposed and validated. The Task Manager is intended to use the "unused but paid-for" gas that resulting from this system.

  While the primary supplier of gas used in the execution of tasks will most likely be failed searcher transactions calling the `FastLane MEV EntryPoint` smart contract, any app or smart contract in the monad ecosystem can offer their users gas rebates by allocating any unused gas at the end of the transaction to the task manager.

- **Flexible Scheduling:**  
  Schedule tasks using either native MON (by sending native value along with the call) or bonded shMONAD.

- **Execution Isolation:**  
  Each task is executed in a dedicated execution environment deployed via `CREATE2`. These environments will `DELEGATECALL` an `IMPLEMENTATION` smart contract supplied by the task creator. Two example `IMPLEMENTATION` smart contracts are available in the repository:
  - **BasicTaskEnvironment:** For simple execution with pre-execution validation and logging.
  - **ReschedulingTaskEnvironment:** Extends basic functionality with automatic retry logic and rescheduling on failure.
  Additional `IMPLEMENTATION` examples will be added as development continues. 

- **Dynamic Fee Calculation:**  
  Execution fees are determined based on real-time load metrics. The fee computation considers multiple depths (block-level, group-level, supergroup-level) and factors in network congestion. Additional work is being done on the fee calculation and we expect it to change over time.

- **Robust Load Balancing:**  
  The load balancer allocates execution across task sizes and blocks using bitmaps and groupings, ensuring efficient processing and predictable gas usage with minimal storage reads or writes.

- **Fee Distribution:**  
  Task fees are distributed as follows:
  - **ShMONAD Yield Boost:** 25%
  - **Validator (block.coinbase):** 26%
  - **Executor:** 49%
  
  This model incentivizes proper execution while maintaining system integrity. Note that the fee distribution may change in future iterations.

## Documentation

The Task Manager system is documented in two main guides:

- **[Design Documentation](docs/design.md)** - Technical architecture and system design details
- **[Integration Guide](docs/integration.md)** - Implementation guide with code examples and best practices

## Deployed Contracts

| Contract | Address |
|----------|---------|
| TaskManagerProxy | `0x...` |
| TaskManagerImpl | `0x...` |
| ExampleExecutionEnvironment | `0x...` |

## Foundry Tools

This project uses Foundry for development, testing, and deployment.

### Commands

- **Build:**  
  ```shell
  forge build
  ```

- **Test:**  
  ```shell
  forge test
  ```

- **Format:**  
  ```shell
  forge fmt
  ```

- **Gas Snapshots:**  
  ```shell
  forge snapshot
  ```

- **Run Local Node:**  
  ```shell
  anvil
  ```

- **Deploy a Script:**  
  ```shell
  forge script <script_path> --rpc-url <your_rpc_url> --private-key <your_private_key>
  ```

For more help, run:
```shell
forge --help
anvil --help
cast --help
```

### Additional Documentation

For more detailed documentation on Foundry tools, please visit:
https://book.getfoundry.sh/
