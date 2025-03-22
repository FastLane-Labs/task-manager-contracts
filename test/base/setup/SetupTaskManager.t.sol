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

    function __setUpTaskManager(address contractDeployer, IAddressHub addressHub) internal {
        __upgradeImplementationTaskManager(contractDeployer, addressHub);
    }
    
    function __deployProxyTaskManager(address contractDeployer, IAddressHub addressHub) internal {
        vm.startPrank(contractDeployer);

        // Deploy a real temporary implementation first
        address tempImplementation = address(new MockProxyImplementation());

        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(address)",
            contractDeployer
        );
        (TransparentUpgradeableProxy proxy, ProxyAdmin proxyAdmin) =
            VmSafe(vm).deployProxy(address(tempImplementation), contractDeployer, initCalldata);
        // Use the proxy contract with the TaskManagerEntrypoint interface
        taskManager = TaskManagerEntrypoint(payable(address(proxy)));
        taskManagerProxyAdmin = proxyAdmin;
        // Add TaskManager to AddressHub

        if (addressHub.getAddressFromPointer(Directory._TASK_MANAGER) == address(0)) {
            addressHub.addPointerAddress(Directory._TASK_MANAGER, address(taskManager), "taskManager");
        } else {
            addressHub.updatePointerAddress(Directory._TASK_MANAGER, address(taskManager));
        }

        vm.stopPrank();
        vm.label(address(taskManager), "TaskManager");
    }
    
    function __upgradeImplementationTaskManager(address contractDeployer, IAddressHub addressHub) internal {
        IShMonad _shMonad = IShMonad(addressHub.getAddressFromPointer(Directory._SHMONAD));

        // Get the owner of the shMonad
        address _shMonadOwner = __getOwnerOfShMonad(address(_shMonad));
        
        vm.startPrank(_shMonadOwner);
        // Create a policy for the task manager, register the proxy as an agent and remove _shMonadOwner as an agent 
        (uint64 policyId,) = _shMonad.createPolicy(escrowDuration);
        _shMonad.addPolicyAgent(policyId, address(taskManager));
        _shMonad.removePolicyAgent(policyId, _shMonadOwner);
        vm.stopPrank();

        // Deploy TaskManagerEntrypoint Implementation as contractDeployer
        vm.startPrank(contractDeployer);
        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(address)",
            contractDeployer
        );

        // Deploy TaskManagerEntrypoint Implementation
        taskManagerImpl = address(new TaskManagerEntrypoint(address(_shMonad), policyId));
        require(TaskManagerEntrypoint(payable(taskManagerImpl)).POLICY_ID() == policyId, "TaskManagerEntrypoint policy ID mismatch");
        require(TaskManagerEntrypoint(payable(taskManagerImpl)).SHMONAD() == address(_shMonad), "TaskManagerEntrypoint shMonad mismatch");
        
        // Upgrade the proxy to the new implementation
        taskManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(taskManager)),
            taskManagerImpl,
            initCalldata
        );

        vm.stopPrank();
    }

    /**
     * @notice Get the owner of the shMonad contract
     * @param shMonadAddress The address of the shMonad contract
     * @return The owner of the shMonad contract
     */
    function __getOwnerOfShMonad(address shMonadAddress) internal view returns (address) {
        bytes32 OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;
        bytes32 slotValue = vm.load(shMonadAddress, OwnableStorageLocation);
        return address(uint160(uint256(slotValue)));
    }
}