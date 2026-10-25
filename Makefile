-include .env

.PHONY: all test clean deploy install update build remove

# Default target: Clean, remove modules, install, update, and build
all: clean remove install update build

# Clean the build artifacts
clean:; forge clean

# Remove git modules (useful for resetting dependencies)
remove:
	@echo "Warning: This will remove all git submodules and lib/. Press Ctrl+C to cancel."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ]
	rm -rf .gitmodules .git/modules/* lib
	touch .gitmodules
	@echo "Modules removed. Run 'git add . && git commit' manually if desired."

# Install OpenZeppelin Contracts
install:; forge install OpenZeppelin/openzeppelin-contracts

# Update dependencies
update:; forge update

# Compile the smart contracts
build:; forge build

# Run tests
test:; forge test

# Deploy to a network (Requires .env file with RPC_URL and PRIVATE_KEY)
deploy:; forge script script/Deploy.s.sol:Deploy --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast $(FLAGS)

# Deploy to Anvil (Localhost) - No keys needed
deploy-anvil:; forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
