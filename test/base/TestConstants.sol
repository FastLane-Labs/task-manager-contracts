// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// For any shared test constants (not specific to a protocol's setup)
contract TestConstants {
    // Chain Fork Settings
    uint256 MONAD_TESTNET_FORK_BLOCK = 8_149_082;

    // Testnet AddressHub
    address ADDRESS_HUB = 0xC9f0cDE8316AbC5Efc8C3f5A6b571e815C021B51;
    address ADDRESS_HUB_OWNER = 0x78C5d8DF575098a97A3bD1f8DCCEb22D71F3a474;

    address internal constant TESTNET_FASTLANE_DEPLOYER = 0x78C5d8DF575098a97A3bD1f8DCCEb22D71F3a474;
    address internal constant TESTNET_TASK_MANAGER_PROXY_ADMIN = 0x86780dA77e5c58f5DD3e16f58281052860f9136b;
}
