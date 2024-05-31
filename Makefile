-include .env

.PHONY: all test clean deploy_oil install format

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network op_sepolia,$(ARGS)),--network op_sepolia)
	NETWORK_ARGS := --rpc-url $(OP_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(OPTIMISM_SCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network fuji,$(ARGS)),--network fuji)
	NETWORK_ARGS := --rpc-url $(FUJI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv
endif

ifeq ($(findstring --network amoy,$(ARGS)),--network amoy)
	NETWORK_ARGS := --rpc-url $(AMOY_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
endif

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy_tokens:
	echo $(AMOY_RPC_URL)
	@forge script script/DeployTokenMocks.s.sol:DeployTokenMocks $(NETWORK_ARGS)

deploy_weth:
	echo $(AMOY_RPC_URL)
	@forge script script/DeployTokenMocks.s.sol:DeployWethMock $(NETWORK_ARGS)

deploy_dai:
	echo $(AMOY_RPC_URL)
	@forge script script/DeployTokenMocks.s.sol:DeployDaiMock $(NETWORK_ARGS)

deploy_oil:
	@forge script script/Deploy_sOIL.s.sol:Deploy_sOIL $(NETWORK_ARGS)

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install modules
install :; forge install cyfrin/foundry-devops --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.8.0 --no-commit && forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit && forge install cyfrin/ccip-contracts@1.4.0 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

aderyn :; aderyn .
