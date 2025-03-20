# Task Manager

Task Manager is a smart contract–based task scheduling and execution system designed for the Monad blockchain. It leverages shMONAD (staked MON) bonding for economic security and uses advanced load balancing and dynamic fee pricing to schedule tasks with predictable gas usage.

## Overview

The system allows users to schedule smart contract tasks that will be executed in isolated environments at predetermined future blocks. Tasks are categorized by gas limits (Small, Medium, Large) and are queued using a block-based scheduling system. Economic security is ensured via shMONAD bonding.

## Key Features

- **Flexible Scheduling:**  
  Schedule tasks using either native MON (by sending native value along with the call) or bonded shMONAD.

- **Execution Isolation:**  
  Each task is executed in a dedicated execution environment deployed via CREATE2. Two environments are available:
  - **BasicTaskEnvironment:** For simple execution with pre-execution validation and logging.
  - **ReschedulingTaskEnvironment:** Extends basic functionality with automatic retry logic and rescheduling on failure.

- **Dynamic Fee Calculation:**  
  Execution fees are determined based on real-time load metrics. The fee computation considers multiple depths (block-level, group-level, supergroup-level) and factors in network congestion.

- **Robust Load Balancing:**  
  The load balancer allocates tasks across blocks using bitmaps and groupings, ensuring efficient processing and predictable gas usage.

- **Economic Security & Fee Distribution:**  
  Task fees are distributed as follows:
  - **Protocol:** 25%
  - **Validator (block.coinbase):** 26%
  - **Executor:** 49%
  
  This model incentivizes proper execution while maintaining system integrity.

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
