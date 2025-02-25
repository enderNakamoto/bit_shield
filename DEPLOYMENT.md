# Risk Hedge Protocol Deployment Guide

This document provides instructions for deploying the Risk Hedge Protocol to both testnet and mainnet environments.

## Prerequisites

Before deploying, ensure you have the following:

1. [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
2. A wallet with sufficient ETH for deployment gas fees
3. The private key for your deployment wallet (handle with extreme care!)
4. For mainnet deployment: The address of the asset token (BTC wrapped token) you wish to use

## Environment Setup

Create a `.env` file in the project root with the following variables:

```
PRIVATE_KEY=your_private_key_here
ASSET_TOKEN_ADDRESS=0x... # Optional for testnet, required for mainnet
ETHERSCAN_API_KEY=your_etherscan_api_key # For verification
```

Then load these environment variables:

```bash
source .env
```

## Deployment Steps

### 1. Testnet Deployment

To deploy to a testnet (like Sepolia):

```bash
# Make sure you're on the right network
forge script script/DeployTestnet.s.sol:DeployTestnetScript --rpc-url $TESTNET_RPC_URL --broadcast --verify
```

This will:
- Deploy a MockToken (if no ASSET_TOKEN_ADDRESS is provided)
- Deploy the Controller contract
- Deploy the MarketCreator contract
- Output all contract addresses

### 2. Mainnet Deployment

For mainnet deployment, you MUST provide a valid ASSET_TOKEN_ADDRESS:

```bash
# Make sure you're on the mainnet
forge script script/DeployMainnet.s.sol:DeployMainnetScript --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

### 3. Contract Verification

After deployment, verify your contracts on Etherscan:

```bash
forge verify-contract --chain-id $CHAIN_ID --watch --constructor-args $(cast abi-encode "constructor(address)" $MARKET_CREATOR_ADDRESS) $CONTROLLER_ADDRESS src/Controller.sol:Controller $ETHERSCAN_API_KEY

forge verify-contract --chain-id $CHAIN_ID --watch --constructor-args $(cast abi-encode "constructor(address,address)" $CONTROLLER_ADDRESS $ASSET_TOKEN_ADDRESS) $MARKET_CREATOR_ADDRESS src/MarketCreator.sol:MarketCreator $ETHERSCAN_API_KEY
```

### 4. Creating Markets

After the protocol is deployed, you can create markets using:

```bash
# Set the MarketCreator address in your environment first
export MARKET_CREATOR_ADDRESS=0x...

# Then run the create market script
forge script script/CreateMarket.s.sol:CreateMarketScript --rpc-url $RPC_URL --broadcast
```

## Important Notes

1. **Controller Address Issue**: Due to the architecture of the protocol, the MarketCreator contract is initialized with a controller address, and the Controller contract is initialized with the MarketCreator address. This creates a circular dependency. Our deployment script handles this by:
   - First deploying an interim Controller with a dummy address
   - Then deploying the MarketCreator with the interim Controller's address
   - Finally deploying the real Controller with the MarketCreator's address

2. **Post-Deployment Steps**: After deployment, you should:
   - Create markets as needed
   - Transfer ownership of any contracts if required
   - Perform thorough testing before actual usage

3. **Security**: Always be extremely careful with private keys, especially for mainnet deployments.

## Troubleshooting

If you encounter issues during deployment:

1. Check that you have sufficient ETH for gas
2. Verify that all addresses in your .env file are correct
3. Ensure you're connected to the right network
4. Check the Foundry logs for detailed error messages 