// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeUtils } from "../../../script/upgradeability/UpgradeUtils.sol";
import { MockProxyImplementation } from "./MockProxyImplementation.sol";
import { TaskManagerEntrypoint } from "../../../src/core/Entrypoint.sol";
import { IShMonad } from "../../../src/interfaces/shmonad/IShMonad.sol";
import { IAddressHub } from "../../../src/interfaces/common/IAddressHub.sol";
import { Directory } from "../../../src/interfaces/common/Directory.sol";
contract SetupTaskManager is Test {
    using UpgradeUtils for VmSafe;

    TaskManagerEntrypoint taskManager;
    uint48 escrowDuration = 10;

    ProxyAdmin taskManagerProxyAdmin; // The ProxyAdmin to control upgrades to TaskManager
    address taskManagerImpl; // The current implementation of TaskManager

    function __setUpTaskManager(address deployer, IAddressHub addressHub) internal {
        __upgradeImplementationTaskManager(deployer, addressHub);
    }
    
    function __deployProxyTaskManager(address deployer, IAddressHub addressHub) internal {
        vm.startPrank(deployer);

        // Deploy a real temporary implementation first
        address tempImplementation = address(new MockProxyImplementation());

        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(address)",
            deployer
        );
        (TransparentUpgradeableProxy _proxy, ProxyAdmin _proxyAdmin) =
            VmSafe(vm).deployProxy(address(tempImplementation), deployer, initCalldata);
        // Use the proxy contract with the TaskManagerEntrypoint interface
        taskManager = TaskManagerEntrypoint(payable(address(_proxy)));
        taskManagerProxyAdmin = _proxyAdmin;
        // Add TaskManager to AddressHub

        if (addressHub.getAddressFromPointer(Directory._TASK_MANAGER) == address(0)) {
            addressHub.addPointerAddress(Directory._TASK_MANAGER, address(taskManager), "taskManager");
        } else {
            addressHub.updatePointerAddress(Directory._TASK_MANAGER, address(taskManager));
        }

        vm.stopPrank();
        vm.label(address(taskManager), "TaskManager");
    }
    
    function __upgradeImplementationTaskManager(address deployer, IAddressHub addressHub) internal {
        vm.startPrank(deployer);
        IShMonad shMonad = IShMonad(addressHub.getAddressFromPointer(Directory._SHMONAD));

        // Create a policy for the task manager, register the proxy as an agent and remove deployer as an agent 
        (uint64 policyId,) = shMonad.createPolicy(escrowDuration);
        shMonad.addPolicyAgent(policyId, address(taskManager));
        shMonad.removePolicyAgent(policyId, deployer);

        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(address)",
            deployer
        );

        // Deploy TaskManagerEntrypoint Implementation
        taskManagerImpl = address(new TaskManagerEntrypoint(address(shMonad), policyId));
        require(TaskManagerEntrypoint(payable(taskManagerImpl)).POLICY_ID() == policyId, "TaskManagerEntrypoint policy ID mismatch");
        require(TaskManagerEntrypoint(payable(taskManagerImpl)).SHMONAD() == address(shMonad), "TaskManagerEntrypoint shMonad mismatch");
        
        // Upgrade the proxy to the new implementation
        taskManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(taskManager)),
            taskManagerImpl,
            initCalldata
        );

        vm.stopPrank();
    }
}