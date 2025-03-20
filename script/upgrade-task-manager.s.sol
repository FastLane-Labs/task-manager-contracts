//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { ITransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

import { IAddressHub } from "src/interfaces/common/IAddressHub.sol";
import { TaskManagerEntrypoint } from "src/core/Entrypoint.sol";
import { Directory } from "src/interfaces/common/Directory.sol";
import { IShMonad } from "src/interfaces/shmonad/IShMonad.sol";

/**
 * @title UpgradeTaskManagerScript
 * @notice Script to upgrade the TaskManager implementation while keeping the same proxy address
 * @dev This script deploys a new TaskManager implementation and upgrades the existing proxy to point to it
 */
contract UpgradeTaskManagerScript is Script {
    // Update this address after deployment
    address public constant TASK_MANAGER_PROXY_ADMIN = address(0); // Set this after deployment

    // Existing policy ID to use if retrieval fails
    uint64 public constant EXISTING_POLICY_ID = 5; // TaskManager policy ID

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("GOV_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address addressHub = vm.envAddress("ADDRESS_HUB");
        uint48 escrowDuration = 10; // 10 blocks

        // Get the AddressHub instance
        IAddressHub hub = IAddressHub(addressHub);

        // Get TaskManager proxy address from AddressHub
        address taskManagerProxyAddress = hub.getAddressFromPointer(Directory._TASK_MANAGER);
        require(taskManagerProxyAddress != address(0), "TaskManager proxy address not set in AddressHub");

        // Get shMONAD address from AddressHub
        address shmonadAddress = hub.getAddressFromPointer(Directory._SHMONAD);
        require(shmonadAddress != address(0), "shMONAD not properly set in AddressHub");

        // Check if ProxyAdmin address is set
        require(TASK_MANAGER_PROXY_ADMIN != address(0), "TaskManager ProxyAdmin address not set in script constants");

        console.log("Starting TaskManager implementation upgrade...");
        console.log("Deployer address:", deployer);
        console.log("AddressHub address:", addressHub);
        console.log("Escrow duration:", escrowDuration);
        console.log("TaskManager proxy address:", taskManagerProxyAddress);
        console.log("TaskManager ProxyAdmin address:", TASK_MANAGER_PROXY_ADMIN);
        console.log("Verified shMONAD address:", shmonadAddress);

        // Initialize the TaskManager with the deployer address as the owner
        bytes memory initCalldata = abi.encodeWithSignature("initialize(address)", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // Try to get policy ID from existing TaskManager proxy
        uint64 policyId;

        try TaskManagerEntrypoint(payable(taskManagerProxyAddress)).POLICY_ID() returns (uint64 existingPolicyId) {
            if (existingPolicyId != 0) {
                policyId = existingPolicyId;
                console.log("Retrieved existing policy ID from TaskManager proxy:", policyId);
            } else {
                policyId = EXISTING_POLICY_ID;
                console.log("Using hardcoded policy ID:", policyId);
                // Register proxy as agent for the hardcoded policy
                IShMonad(shmonadAddress).addPolicyAgent(policyId, address(taskManagerProxyAddress));
                console.log("Registered TaskManager proxy as agent for hardcoded policy ID:", policyId);
            }
        } catch {
            // Fallback to hardcoded value
            policyId = EXISTING_POLICY_ID;
            console.log("Could not retrieve policy ID from TaskManager proxy, using hardcoded ID:", policyId);
            // Register proxy as agent for the hardcoded policy
            IShMonad(shmonadAddress).addPolicyAgent(policyId, address(taskManagerProxyAddress));
            console.log("Registered TaskManager proxy as agent for hardcoded policy ID:", policyId);
        }

        // Deploy TaskManagerEntrypoint implementation with constructor args
        TaskManagerEntrypoint taskManagerImpl = new TaskManagerEntrypoint(shmonadAddress, policyId);

        // Get a reference to the ProxyAdmin contract
        ProxyAdmin proxyAdmin = ProxyAdmin(TASK_MANAGER_PROXY_ADMIN);

        // Upgrade proxy to point to new implementation
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(taskManagerProxyAddress), address(taskManagerImpl), initCalldata
        );

        vm.stopBroadcast();

        console.log("\n=== Upgrade Report ===");
        console.log("Network:", block.chainid);
        console.log("| TaskManager Implementation   |", address(taskManagerImpl), "|");
        console.log("| TaskManager Proxy            |", taskManagerProxyAddress, "|");
        console.log("| TaskManager ProxyAdmin       |", TASK_MANAGER_PROXY_ADMIN, "|");
        console.log("| TaskManager Execution Env    |", address(taskManagerImpl.EXECUTION_ENV_TEMPLATE()), "|");

        console.log("\nTaskManager upgrade complete!");

        string memory verifyStr = string.concat(
            "forge verify-contract --rpc-url https://explorer.monad-testnet.category.xyz/api/eth-rpc --verifier blockscout --verifier-url 'https://explorer.monad-testnet.category.xyz/api/' ",
            vm.toString(address(taskManagerImpl)),
            " src/task-manager/core/Entrypoint.sol:TaskManagerEntrypoint ",
            vm.toString(shmonadAddress)
        );

        console.log("\n");
        console.log("Verify TaskManagerImpl with:");
        console.log(verifyStr);

        verifyStr = string.concat(
            "forge verify-contract --rpc-url https://explorer.monad-testnet.category.xyz/api/eth-rpc --verifier blockscout --verifier-url 'https://explorer.monad-testnet.category.xyz/api/' ",
            vm.toString(address(taskManagerImpl.EXECUTION_ENV_TEMPLATE())),
            " src/task-manager/common/ExecutionEnvironment.sol:TaskExecutionEnvironment"
        );

        console.log("\n");
        console.log("Verify TaskManagerExecEnv with:");
        console.log(verifyStr);
    }
}
