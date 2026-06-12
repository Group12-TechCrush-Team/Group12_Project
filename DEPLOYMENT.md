# onChainLottery Deployment Guide

## Overview
This guide explains how to deploy the `onChainLottery` smart contract using Foundry scripts.

## Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- A private key (ensure it has funds on the target network)
- RPC endpoint URL for your target blockchain

## Deployment Scripts

There are two deployment scripts available:

### 1. **Deploy.s.sol** - Basic Deployment
A minimal deployment script that creates the contract with an initial entry fee.

**Location:** `script/Deploy.s.sol`

**Features:**
- Deploys the contract with a default 0.1 ETH entry fee
- Displays deployment information (contract address, manager address, entry fee)

**Usage:**
```bash
# Set your private key
export PRIVATE_KEY=your_private_key_here

# Deploy to a network (example: Sepolia testnet)
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url https://sepolia.infura.io/v3/YOUR_INFURA_KEY \
  --private-key $PRIVATE_KEY \
  --broadcast

# Deploy to mainnet
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### 2. **onChainLottery.s.sol** - Deployment with Setup
A more comprehensive script that deploys the contract and optionally initializes the first lottery round.

**Location:** `script/onChainLottery.s.sol`

**Features:**
- Deploys the contract with configuration constants
- Includes commented code to automatically start the first round
- Formatted console output for better visibility

**Usage:**
```bash
# Basic deployment (same as above)
forge script script/onChainLottery.s.sol:DeployAndSetup \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**To auto-start first round:**
1. Edit `script/onChainLottery.s.sol`
2. Uncomment the `lottery.startRound()` call in the `run()` function
3. Run the script with `--broadcast`

## Configuration

### Entry Fee
Both scripts use `0.1 ether` as the initial entry fee. To change this:

**In Deploy.s.sol:**
```solidity
uint256 public entryFee = 0.05 ether; // Change this value
```

**In onChainLottery.s.sol:**
```solidity
uint256 public constant INITIAL_ENTRY_FEE = 0.05 ether; // Change this value
```

## Common Issues & Solutions

### "PRIVATE_KEY not found"
Make sure the environment variable is set:
```bash
export PRIVATE_KEY=your_key_here
```

### "Insufficient funds"
The deployment account needs enough native tokens (ETH, MATIC, etc.) for:
- Contract deployment gas fees
- Any initial transactions (like starting a round)

### "Transaction reverted"
- Verify the RPC URL is correct
- Check that you're on the right network
- Ensure the private key corresponds to the account with sufficient balance

## Verification

After deployment, verify your contract on a block explorer:

```bash
forge verify-contract <contract_address> \
  --compiler-version v0.8.33 \
  --etherscan-api-key <YOUR_ETHERSCAN_KEY> \
  onChainLottery
```

## Contract Interaction After Deployment

Once deployed, you can interact with the contract:

```bash
# Get current round status
cast call <LOTTERY_ADDRESS> "getCurrentRoundStatus()" \
  --rpc-url <RPC_URL>

# Get player list and pot
cast call <LOTTERY_ADDRESS> "getPlayers()" \
  --rpc-url <RPC_URL>
```

## Network Configuration Examples

### Sepolia Testnet
```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url https://sepolia.infura.io/v3/YOUR_KEY \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Polygon (Matic)
```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url https://polygon-rpc.com \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Local Anvil Instance
```bash
# Start anvil in another terminal
anvil

# Deploy to anvil
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02960247590bf80 \
  --broadcast
```

## Safety Notes
⚠️ **Never commit your private key to version control!**
- Use environment variables or `.env` files (add `.env` to `.gitignore`)
- Consider using hardware wallets for mainnet deployments
- Always test on testnet first

## Support
For more information, refer to:
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [onChainLottery Contract](../src/onChainLottery.sol)
