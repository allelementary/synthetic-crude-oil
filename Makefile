-include .env

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network amoy,$(ARGS)),--network amoy)
	NETWORK_ARGS := --rpc-url $(AMOY_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(POLYSCAN_API_KEY) -vvvv
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
	echo $(AMOY_RPC_URL)
	echo $(SEPOLIA_RPC_URL)
	@forge script script/DeploysCrudeOil.s.sol:DeploysCrudeOil $(NETWORK_ARGS)
