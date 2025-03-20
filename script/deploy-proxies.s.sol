//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC1967 } from "openzeppelin-contracts/interfaces/IERC1967.sol";
import { Directory } from "src/interfaces/common/Directory.sol";
import { IAddressHub } from "src/interfaces/common/IAddressHub.sol";
import { UpgradeUtils } from "./upgradeability/UpgradeUtils.sol";

import { OwnableUpgradeable } from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

contract MockImplementation is OwnableUpgradeable {
    function initialize(address deployer) public {
        // Empty implementation
    }
}

contract DeployProxiesScript is Script {
    using UpgradeUtils for VmSafe;

    bool public deployShMonad;
    bool public deployTaskManager;
    bool public deployPaymaster;
    bool public forceDeployment;

    // Store the proxy details for reporting
    struct ProxyDetails {
        address proxyAdmin;
        address proxy;
        string name;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("GOV_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address addressHub = vm.envAddress("ADDRESS_HUB");

        // Parse command line arguments
        string memory deployWhat = vm.envOr("DEPLOY_WHAT", string(""));

        if (bytes(deployWhat).length == 0) {
            // Default: Deploy all proxies if no specific option is provided
            deployShMonad = true;
            deployTaskManager = true;
            deployPaymaster = true;
        } else {
            // Parse specific deployment options
            deployShMonad = vm.envOr("DEPLOY_PROXY_SHMONAD", false) || vm.envOr("DEPLOY_SHMONAD", false) // Keep for
                // backward compatibility
                || keccak256(abi.encodePacked(deployWhat)) == keccak256(abi.encodePacked("shmonad"));

            deployTaskManager = vm.envOr("DEPLOY_PROXY_TASK_MANAGER", false) || vm.envOr("DEPLOY_TASK_MANAGER", false) // Keep
                // for backward compatibility
                || keccak256(abi.encodePacked(deployWhat)) == keccak256(abi.encodePacked("taskmanager"));

            deployPaymaster = vm.envOr("DEPLOY_PROXY_PAYMASTER", false) || vm.envOr("DEPLOY_PAYMASTER", false) // Keep
                // for backward compatibility
                || keccak256(abi.encodePacked(deployWhat)) == keccak256(abi.encodePacked("paymaster"));

            // If "all" is specified, deploy everything
            if (keccak256(abi.encodePacked(deployWhat)) == keccak256(abi.encodePacked("all"))) {
                deployShMonad = true;
                deployTaskManager = true;
                deployPaymaster = true;
            }
        }

        // Log what we're going to deploy
        console.log("\n=== Deployment Configuration ===");
        console.log("Network:", block.chainid);
        console.log("Deploy ShMonad Proxy:", deployShMonad ? "Yes" : "No");
        console.log("Deploy TaskManager Proxy:", deployTaskManager ? "Yes" : "No");
        console.log("Deploy Paymaster Proxy:", deployPaymaster ? "Yes" : "No");

        // Read force deployment flag from environment
        forceDeployment = vm.envOr("FORCE_PROXY_DEPLOYMENT", false);
        console.log("Force Deployment:", forceDeployment ? "Yes" : "No");

        vm.startBroadcast(deployerPrivateKey);

        // Get AddressHub instance
        IAddressHub hub = IAddressHub(addressHub);

        // Using MockImplementation as temporary implementation with base OwnableUpgradeable
        address tempImplementation = address(new MockImplementation());
        bytes memory initData = abi.encodeWithSignature("initialize(address)", deployer);

        // Create an array to store proxy details for the deployment report
        ProxyDetails[] memory deployedProxies = new ProxyDetails[](3);
        uint256 deployedCount = 0;

        // Deploy proxies based on selection
        if (deployShMonad) {
            deployedProxies[deployedCount] =
                createAndRegisterProxy(deployer, hub, Directory._SHMONAD, "ShMonad", tempImplementation, initData);
            deployedCount++;
        }

        if (deployTaskManager) {
            deployedProxies[deployedCount] = createAndRegisterProxy(
                deployer, hub, Directory._TASK_MANAGER, "TaskManager", tempImplementation, initData
            );
            deployedCount++;
        }

        if (deployPaymaster) {
            deployedProxies[deployedCount] = createAndRegisterProxy(
                deployer, hub, Directory._PAYMASTER_4337, "Paymaster", tempImplementation, initData
            );
            deployedCount++;
        }

        vm.stopBroadcast();

        // Generate deployment report
        console.log("\n=== Proxy Deployment Report ===");
        console.log("Network:", block.chainid);
        console.log("| Contract                  | Address                                    |");
        console.log("|---------------------------|-------------------------------------------|");

        for (uint256 i = 0; i < deployedCount; i++) {
            console.log(
                string.concat("| ", deployedProxies[i].name, " ProxyAdmin        | "),
                deployedProxies[i].proxyAdmin,
                " |"
            );
            console.log(
                string.concat("| ", deployedProxies[i].name, " Proxy             | "), deployedProxies[i].proxy, " |"
            );
        }

        console.log("\nProxies deployment complete!");
        console.log("Next steps:");
        console.log("1. Update proxy admin constants in upgrade scripts:");

        for (uint256 i = 0; i < deployedCount; i++) {
            console.log(
                string.concat(
                    "   - In upgrade-",
                    toLower(deployedProxies[i].name),
                    ".s.sol, update ",
                    toUpper(deployedProxies[i].name),
                    "_PROXY_ADMIN = ",
                    toAddressString(deployedProxies[i].proxyAdmin)
                )
            );
        }

        console.log("2. Run the implementation upgrade scripts to deploy implementations");

        // Print usage help
        console.log("\n=== Usage Instructions ===");
        console.log("To deploy specific proxies, use environment variables:");
        console.log("DEPLOY_WHAT=all - Deploy all proxies");
        console.log("DEPLOY_WHAT=shmonad - Deploy only ShMonad proxy");
        console.log("DEPLOY_WHAT=taskmanager - Deploy only TaskManager proxy");
        console.log("DEPLOY_WHAT=paymaster - Deploy only Paymaster proxy");
        console.log(
            "Or use boolean flags: DEPLOY_PROXY_SHMONAD=true DEPLOY_PROXY_TASK_MANAGER=true DEPLOY_PROXY_PAYMASTER=true"
        );
        console.log("\nForce deployment over existing proxies:");
        console.log(
            "FORCE_PROXY_DEPLOYMENT=true - Override safety checks and deploy even if proxies already exist (USE WITH CAUTION)"
        );
    }

    /**
     * @notice Deploy and register a proxy for a specific contract type using UpgradeUtils
     * @param deployer The address that will own the ProxyAdmin contract
     * @param hub The AddressHub instance for registering the proxy
     * @param directoryPointer The Directory pointer for this contract type
     * @param proxyName The human-readable name of this proxy
     * @param implementation The initial implementation address (usually a placeholder)
     * @param initData The initialization data (usually empty for initial deployment)
     * @return details The details of the deployed proxy and admin
     * @dev Will exit the script if a proxy already exists at the specified directory pointer
     */
    function createAndRegisterProxy(
        address deployer,
        IAddressHub hub,
        uint256 directoryPointer,
        string memory proxyName,
        address implementation,
        bytes memory initData
    )
        internal
        returns (ProxyDetails memory details)
    {
        // Check if proxy already exists in AddressHub
        address proxyAddress = hub.getAddressFromPointer(directoryPointer);
        address proxyAdminAddress;

        if (proxyAddress == address(0) || forceDeployment) {
            // Display warning if we're overwriting an existing proxy
            if (proxyAddress != address(0)) {
                console.log(
                    string.concat(
                        "\n[WARNING]: Existing ",
                        proxyName,
                        " address/proxy found in address hub at: ",
                        toAddressString(proxyAddress)
                    )
                );
                console.log("[WARNING]: Force deployment is enabled - OVERWRITING existing proxy!");
                console.log("[WARNING]: This will deploy a new ProxyAdmin and break existing upgrade permissions!");
            }

            // Use the UpgradeUtils library to deploy the proxy properly
            (TransparentUpgradeableProxy proxy, ProxyAdmin proxyAdmin) =
                VmSafe(vm).deployProxy(implementation, deployer, initData);

            proxyAddress = address(proxy);
            proxyAdminAddress = address(proxyAdmin);

            console.log(
                string.concat("Deployed new ", proxyName, " ProxyAdmin at: ", toAddressString(proxyAdminAddress))
            );

            // Register in AddressHub
            if (proxyAddress != address(0) && hub.getAddressFromPointer(directoryPointer) != address(0)) {
                // Update existing pointer
                hub.updatePointerAddress(directoryPointer, proxyAddress);
                console.log(
                    string.concat("Updated existing ", proxyName, " proxy address to: ", toAddressString(proxyAddress))
                );
            } else {
                // Add new pointer
                hub.addPointerAddress(directoryPointer, proxyAddress, proxyName);
                console.log(string.concat("Deployed new ", proxyName, " proxy at: ", toAddressString(proxyAddress)));
            }
        } else {
            console.log(
                string.concat(
                    "\n[WARNING]: ",
                    proxyName,
                    " address/proxy already exists in address hub at: ",
                    toAddressString(proxyAddress)
                )
            );
            console.log("To prevent unintentional proxy admin changes, deployment has been stopped.");
            console.log("If you want to continue with deployment, use FORCE_PROXY_DEPLOYMENT=true.");
            console.log("Exiting script...");
            vm.stopBroadcast();
            revert(string.concat("Existing ", proxyName, " proxy found at ", toAddressString(proxyAddress)));
        }

        return ProxyDetails({ proxyAdmin: proxyAdminAddress, proxy: proxyAddress, name: proxyName });
    }

    // Helper functions for string formatting
    function toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory result = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Convert uppercase to lowercase if needed
            if (bStr[i] >= 0x41 && bStr[i] <= 0x5A) {
                result[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                result[i] = bStr[i];
            }
        }
        return string(result);
    }

    function toUpper(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory result = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Convert lowercase to uppercase if needed
            if (bStr[i] >= 0x61 && bStr[i] <= 0x7A) {
                result[i] = bytes1(uint8(bStr[i]) - 32);
            } else {
                result[i] = bStr[i];
            }
        }
        return string(result);
    }

    function toAddressString(address addr) internal pure returns (string memory) {
        return vm.toString(addr);
    }
}
