// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { UpgradeUtils } from "../../script/upgradeability/UpgradeUtils.sol";
// Lib imports
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

// Protocol Setup imports
import {SetupTaskManager} from "./setup/SetupTaskManager.t.sol";
import {IShMonad} from "src/interfaces/shmonad/IShMonad.sol";
import {Directory} from "src/interfaces/common/Directory.sol";

import {TestConstants} from "./TestConstants.sol";
import {IAddressHub} from "src/interfaces/common/IAddressHub.sol";
contract BaseTest is
    SetupTaskManager,
    TestConstants
{

    using UpgradeUtils for VmSafe;

    address deployer = makeAddr("Deployer");
    address user = makeAddr("User");

    // The upgradable proxy of the AddressHub
    IAddressHub addressHub;
    ProxyAdmin addressHubProxyAdmin;
    IShMonad shMonad;
    address addressHubImpl;

    // Network configuration
    string internal NETWORK_RPC_URL = "MONAD_TESTNET_RPC_URL";
    uint256 internal FORK_BLOCK = MONAD_TESTNET_FORK_BLOCK;
    bool internal isMonad = true;

    function setUp() public virtual {
        _configureNetwork();
    
        if (FORK_BLOCK != 0) {
            vm.createSelectFork(
                vm.envString(NETWORK_RPC_URL),
                FORK_BLOCK
            );
        } else {
            vm.createSelectFork(
                vm.envString(NETWORK_RPC_URL)
            );
        }
        // add our deployer as an owner of the AddressHub
        _setupAddressHub(deployer);

        shMonad = IShMonad(addressHub.getAddressFromPointer(Directory._SHMONAD));

        SetupTaskManager.__deployProxyTaskManager(deployer, addressHub);
        // Upgrade implementations to the latest version
        SetupTaskManager.__setUpTaskManager(deployer, addressHub);
    }

    // Virtual function to configure network - can be overridden by test contracts
    function _configureNetwork() internal virtual {
        // Default configuration is mainnet
        NETWORK_RPC_URL = "MONAD_TESTNET_RPC_URL";
        FORK_BLOCK = 0; // 0 means latest block
        isMonad = true;
    }

    function _setupAddressHub(address deployer) internal virtual {
        addressHub = IAddressHub(ADDRESS_HUB);
        // Add the deployer as an owner of the AddressHub
        vm.prank(ADDRESS_HUB_OWNER);
        addressHub.addOwner(deployer);
    }
}