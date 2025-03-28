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

    function __setUpTaskManager(address deployer, address proxyAdminAddress, IAddressHub addressHub) internal {
        __upgradeImplementationTaskManager(deployer, proxyAdminAddress, addressHub);
    }
    
    function __upgradeImplementationTaskManager(address deployer, address proxyAdminAddress, IAddressHub addressHub) internal {
        //Note deployer is the owner of the task manager proxy as well as the shMonad owner
        
        // Get shMonad address from AddressHub
        IShMonad shMonad = IShMonad(addressHub.getAddressFromPointer(Directory._SHMONAD));
        taskManager = TaskManagerEntrypoint(payable(addressHub.getAddressFromPointer(Directory._TASK_MANAGER)));
        // Get policy ID from TaskManagerEntrypoint
        uint64 policyId = taskManager.POLICY_ID();
        require(policyId != 0, "TaskManagerEntrypoint policy ID is 0");

        // use deployer to upgrade implementation
        vm.startPrank(deployer);
        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(address)",
            deployer
        );

        // Deploy TaskManagerEntrypoint Implementation
        taskManagerImpl = address(new TaskManagerEntrypoint(address(shMonad), policyId));
        require(TaskManagerEntrypoint(payable(taskManagerImpl)).POLICY_ID() == policyId, "TaskManagerEntrypoint policy ID mismatch");
        require(TaskManagerEntrypoint(payable(taskManagerImpl)).SHMONAD() == address(shMonad), "TaskManagerEntrypoint shMonad mismatch");
        
        // Upgrade the proxy to the new implementation
        taskManagerProxyAdmin = ProxyAdmin(proxyAdminAddress);
        taskManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(taskManager)),
            taskManagerImpl,
            initCalldata
        );

        vm.stopPrank();
    }
}