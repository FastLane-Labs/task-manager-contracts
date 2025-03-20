# Include .env file if it exists
-include .env

# Default network and RPC settings
NETWORK ?= monad-testnet
# Extract network type and name from NETWORK variable (e.g., eth-mainnet -> ETH_MAINNET)
NETWORK_UPPER = $(shell echo $(NETWORK) | tr 'a-z-' 'A-Z_')
# Override any existing RPC_URL with the network-specific one
RPC_URL = $($(NETWORK_UPPER)_RPC_URL)
# Default fork block (can be overridden)
FORK_BLOCK ?= latest

# Conditionally set the fork block number flag
ifeq ($(FORK_BLOCK),latest)
  FORK_BLOCK_FLAG = 
else
  FORK_BLOCK_FLAG = --fork-block-number $(FORK_BLOCK)
endif

# Debug target
debug-network:
	@echo "NETWORK: $(NETWORK)"
	@echo "NETWORK_UPPER: $(NETWORK_UPPER)"
	@echo "RPC_URL: $(RPC_URL)"
	@echo "FORK_BLOCK: $(FORK_BLOCK)"
	@echo "FORK_BLOCK_FLAG: $(FORK_BLOCK_FLAG)"

# Declare all PHONY targets
.PHONY: all clean install build test test-gas format snapshot anvil size update
.PHONY: deploy test-deploy fork-anvil fork-test-deploy
.PHONY: deploy-address-hub deploy-shmonad deploy-taskmanager deploy-paymaster deploy-sponsored-executor
.PHONY: upgrade-address-hub upgrade-shmonad upgrade-taskmanager upgrade-paymaster
.PHONY: test-deploy-address-hub test-deploy-shmonad test-deploy-taskmanager test-deploy-paymaster test-deploy-sponsored-executor
.PHONY: test-upgrade-address-hub test-upgrade-shmonad test-upgrade-taskmanager test-upgrade-paymaster
.PHONY: fork-test-deploy-address-hub fork-test-deploy-shmonad fork-test-deploy-taskmanager fork-test-deploy-paymaster fork-test-deploy-sponsored-executor
.PHONY: fork-test-upgrade-address-hub fork-test-upgrade-shmonad fork-test-upgrade-taskmanager fork-test-upgrade-paymaster
.PHONY: request-tokens get-paymaster-info scenario_test_upgrade

# Default target
all: clean install build test

# Build and test targets
clean:
	forge clean

install:
	forge install

build:
	forge build

test:
	forge test -vvv

test-gas:
	forge test -vvv --gas-report

format:
	forge fmt

snapshot:
	forge snapshot

anvil:
	anvil

# Start anvil with fork of the specified network
fork-anvil: debug-network
	@if [ -z "$(RPC_URL)" ]; then echo "No RPC URL found for network $(NETWORK)"; exit 1; fi
	@echo "Starting anvil with fork of $(NETWORK) at block $(FORK_BLOCK)..."
	anvil --fork-url $(RPC_URL) $(FORK_BLOCK_FLAG)

size:
	forge build --sizes

update:
	forge update 

test-deploy-taskmanager:
	@if [ -z "$(GOV_PRIVATE_KEY)" ]; then echo "GOV_PRIVATE_KEY is not set"; exit 1; fi
	@if [ -z "$(ADDRESS_HUB)" ]; then echo "ADDRESS_HUB is not set"; exit 1; fi
	@if [ -z "$(RPC_URL)" ]; then echo "No RPC URL found for network $(NETWORK)"; exit 1; fi
	@echo "Testing TaskManager deployment on $(NETWORK)..."
	DEPLOY_PROXY_TASK_MANAGER=true forge script script/deploy-proxies.s.sol:DeployProxiesScript \
		--rpc-url $(RPC_URL) \
		-vvvv

test-upgrade-taskmanager: debug-network
	@if [ -z "$(GOV_PRIVATE_KEY)" ]; then echo "GOV_PRIVATE_KEY is not set"; exit 1; fi
	@if [ -z "$(ADDRESS_HUB)" ]; then echo "ADDRESS_HUB is not set"; exit 1; fi
	@if [ -z "$(TASK_MANAGER)" ]; then echo "TASK_MANAGER is not set"; exit 1; fi
	@if [ -z "$(RPC_URL)" ]; then echo "No RPC URL found for network $(NETWORK)"; exit 1; fi
	@echo "Testing TaskManager upgrade on $(NETWORK)..."
	forge script script/upgrade-task-manager.s.sol:UpgradeTaskManagerScript \
		--rpc-url $(RPC_URL) \
		-vvvv

fork-test-deploy-taskmanager: debug-network
	@if [ -z "$(GOV_PRIVATE_KEY)" ]; then echo "GOV_PRIVATE_KEY is not set"; exit 1; fi
	@if [ -z "$(ADDRESS_HUB)" ]; then echo "ADDRESS_HUB is not set"; exit 1; fi
	@if [ -z "$(RPC_URL)" ]; then echo "No RPC URL found for network $(NETWORK)"; exit 1; fi
	@echo "Testing TaskManager deployment on a fork of $(NETWORK) at block $(FORK_BLOCK)..."
	DEPLOY_PROXY_TASK_MANAGER=true forge script script/deploy-proxies.s.sol:DeployProxiesScript \
		--fork-url $(RPC_URL) \
		$(FORK_BLOCK_FLAG) \
		-vvvv

fork-test-upgrade-taskmanager: debug-network
	@if [ -z "$(GOV_PRIVATE_KEY)" ]; then echo "GOV_PRIVATE_KEY is not set"; exit 1; fi
	@if [ -z "$(ADDRESS_HUB)" ]; then echo "ADDRESS_HUB is not set"; exit 1; fi
	@if [ -z "$(TASK_MANAGER)" ]; then echo "TASK_MANAGER is not set"; exit 1; fi
	@if [ -z "$(RPC_URL)" ]; then echo "No RPC URL found for network $(NETWORK)"; exit 1; fi
	@echo "Testing TaskManager upgrade on a fork of $(NETWORK) at block $(FORK_BLOCK)..."
	forge script script/upgrade-task-manager.s.sol:UpgradeTaskManagerScript \
		--fork-url $(RPC_URL) \
		$(FORK_BLOCK_FLAG) \
		-vvvv

deploy-taskmanager:
	@if [ -z "$(GOV_PRIVATE_KEY)" ]; then echo "GOV_PRIVATE_KEY is not set"; exit 1; fi
	@if [ -z "$(ADDRESS_HUB)" ]; then echo "ADDRESS_HUB is not set"; exit 1; fi
	@if [ -z "$(PAYOUT_ADDRESS)" ]; then echo "PAYOUT_ADDRESS is not set"; exit 1; fi
	@if [ -z "$(RPC_URL)" ]; then echo "No RPC URL found for network $(NETWORK)"; exit 1; fi
	@echo "Deploying TaskManager to $(NETWORK)..."
	DEPLOY_PROXY_TASK_MANAGER=true forge script script/deploy-proxies.s.sol:DeployProxiesScript \
		--rpc-url $(RPC_URL) \
		--broadcast \
		-vvv

upgrade-taskmanager:
	@if [ -z "$(GOV_PRIVATE_KEY)" ]; then echo "GOV_PRIVATE_KEY is not set"; exit 1; fi
	@if [ -z "$(ADDRESS_HUB)" ]; then echo "ADDRESS_HUB is not set"; exit 1; fi
	@if [ -z "$(TASK_MANAGER)" ]; then echo "TASK_MANAGER is not set"; exit 1; fi
	@if [ -z "$(RPC_URL)" ]; then echo "No RPC URL found for network $(NETWORK)"; exit 1; fi
	@echo "Upgrading TaskManager on $(NETWORK)..."
	forge script script/upgrade-task-manager.s.sol:UpgradeTaskManagerScript \
		--rpc-url $(RPC_URL) \
		--broadcast \
		-vvv

# Combined deployment targets
test-deploy: test-deploy-taskmanager
	@echo "All deployment tests completed for $(NETWORK)"

test-upgrade: test-upgrade-taskmanager
	@echo "All upgrade tests completed for $(NETWORK)"

deploy: deploy-taskmanager
	@echo "All contracts deployed to $(NETWORK)"

upgrade: upgrade-taskmanager
	@echo "All contracts upgraded on $(NETWORK)"
