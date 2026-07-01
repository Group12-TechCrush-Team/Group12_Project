# 🎰 On-Chain Lottery
> TechCrush Cohort 6 — Group Capstone Project | Topic 6

A fully on-chain lottery system built in Solidity where players buy tickets and a pseudo-random winner takes the prize pool. Features three prize modes — ETH only, NFT only, or both — with a real ERC721 NFT contract for prize distribution.

---

## ⚠️ Randomness Disclaimer

This contract uses **pseudo-randomness** generated from `keccak256` hashing of:
- `block.prevrandao` — post-Merge randomness from Ethereum's RANDAO validator system
- `block.timestamp` — the block's timestamp
- `players.length` — number of players in the current round

**This is NOT cryptographically secure.** A validator with sufficient incentive could manipulate `block.prevrandao` or `block.timestamp` to influence the outcome. This implementation is for **educational purposes only**.

In production, replace `_random()` with a **Chainlink VRF v2** `fulfillRandomWords()` callback for verifiable, tamper-proof randomness.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Contracts](#contracts)
- [Features](#features)
- [Gas Optimizations](#gas-optimizations)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [How to Deploy](#how-to-deploy)
- [How to Run Tests](#how-to-run-tests)
- [How to Use](#how-to-use)
- [Contract Functions](#contract-functions)
- [Security Considerations](#security-considerations)
- [Deployed Contracts](#deployed-contracts)

---

## Overview

The On-Chain Lottery allows:
- A **manager** (deployer) to open rounds, set prize types, set entry fees, pick winners, or cancel rounds
- **Players** to enter an active round by sending the exact entry fee in ETH
- **Winners** to automatically receive ETH, an NFT, or both — determined at the start of each round

Each completed round is permanently recorded on-chain and queryable by anyone.

---

## Contracts

### `LotteryNFT.sol`
An ERC721 NFT contract used as lottery prizes. The manager mints NFTs here and approves the Lottery contract to transfer them to winners.

- Inherits OpenZeppelin `ERC721` and `Ownable`
- Only the owner (manager) can mint
- Auto-incrementing token IDs
- Collection name: **LotteryPrize** | Symbol: **LPRIZE**

### `Lottery.sol`
The main lottery contract. Manages rounds, players, payouts, and history.

- Three prize modes via `PrizeType` enum
- Real ERC721 NFT transfer to winner via `IERC721.transferFrom()`
- Full on-chain round history via `RoundInfo` struct mapping
- Gas-optimized duplicate entry check using round stamp pattern

---

## Features

| Feature | Description |
|---|---|
| 🎁 Three prize types | `ETH_ONLY`, `NFT_ONLY`, `ETH_AND_NFT` — manager chooses per round |
| 🖼️ Real NFT prizes | Actual ERC721 transfer to winner — verifiable on Etherscan and OpenSea |
| 💰 Manager fee | 5% of the ETH prize pool goes to the manager each round |
| 📜 Round history | Every completed round stored permanently on-chain |
| 🔒 Duplicate prevention | O(1) gas mapping check — same address can't enter twice per round |
| 🚨 Emergency cancel | Manager can cancel a round and refund all players |
| 📊 Lifetime stats | `totalPrizePaid` tracks all ETH ever distributed to winners |
| 🔍 View functions | Query current round state or any historical round |

---

## Gas Optimizations

| Optimization | What we did | Why |
|---|---|---|
| **Custom errors** | `error RoundAlreadyOpen()` instead of `require(condition, "string")` | ~50% cheaper on failure — 4 byte selector vs full string encoding |
| **Round stamp pattern** | `mapping(address => uint) enteredRound` instead of `mapping(address => bool)` | Eliminates O(n) reset loop — `roundId++` invalidates all stamps in O(1) |
| **`constant` fee** | `uint public constant MANAGER_FEE_PERCENT = 5` | Stored in bytecode not storage — zero gas to read |
| **`IERC721` not `ERC721`** | Import interface only in Lottery.sol | Avoids adding full ERC721 bytecode to Lottery contract |
| **Local variable capture** | Cache `roundId` and `nftTokenId` before reset | Memory reads (3 gas) vs storage reads (100–2100 gas) |
| **Multiply before divide** | `balance * 5 / 100` not `balance / 100 * 5` | Prevents precision loss from integer truncation |
| **`call` not `transfer`** | `winner.call{value: prize}("")` | No 2300 gas stipend limit — safe for smart contract wallets |
| **`block.prevrandao`** | Not `block.difficulty` (deprecated) | Works correctly on testnets; correct post-Merge naming |

---

## Project Structure

```
lottery-project/
├── src/
│   ├── Lottery.sol          ← main lottery contract
│   └── LotteryNFT.sol       ← ERC721 prize NFT contract
├── test/
│   └── LotteryTest.t.sol    ← Foundry tests
├── script/
│   └── Deploy.s.sol         ← deployment script (Sepolia)
├── foundry.toml             ← Foundry config
└── README.md
```

---

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- An Ethereum wallet with Sepolia testnet ETH
- A free [Alchemy](https://alchemy.com) or [Infura](https://infura.io) RPC URL
- An [Etherscan API key](https://etherscan.io/myapikey) for verification

---

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_GROUP/lottery-project
cd lottery-project

# 2. Install dependencies (OpenZeppelin)
forge install OpenZeppelin/openzeppelin-contracts --no-git

# 3. Build the contracts
forge build
```

You should see:
```
Compiler run successful!
```

---

## How to Deploy

### 1. Set up environment variables

Create a `.env` file in the project root:

```bash
PRIVATE_KEY=your_wallet_private_key_here
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

> ⚠️ Never commit `.env` to git. Add it to `.gitignore`.

### 2. Load environment variables

```bash
source .env
```

### 3. Deploy to Sepolia

```bash
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

The script deploys `LotteryNFT` first, then `Lottery` with the NFT contract address. Both contracts are verified on Etherscan automatically.

---

## How to Run Tests

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vvvv

# Run a specific test
forge test --match-test testPickWinner -vvvv

# See gas report
forge test --gas-report
```

You should see all tests passing with a screenshot like:
```
[PASS] testParticipate() (gas: xxxxx)
[PASS] testPickWinnerETHOnly() (gas: xxxxx)
[PASS] testPickWinnerNFTOnly() (gas: xxxxx)
[PASS] testPickWinnerETHAndNFT() (gas: xxxxx)
[PASS] testCannotEnterTwice() (gas: xxxxx)
[PASS] testCancelRoundRefunds() (gas: xxxxx)
[PASS] testRoundHistory() (gas: xxxxx)
```

---

## How to Use

### As Manager

**Step 1 — Mint an NFT (for NFT rounds)**
```solidity
// Call on LotteryNFT contract
// Returns tokenId (e.g. 0)
lotteryNFT.mint(managerAddress);
```

**Step 2 — Approve Lottery to transfer your NFT**
```solidity
// Call on LotteryNFT contract
lotteryNFT.approve(lotteryAddress, tokenId);
```

**Step 3 — Start a round**
```solidity
// ETH only round — 0.01 ETH entry fee
lottery.startRound(PrizeType.ETH_ONLY, 0.01 ether, 0);

// NFT only round — tokenId 0
lottery.startRound(PrizeType.NFT_ONLY, 0.01 ether, 0);

// ETH + NFT round — tokenId 0
lottery.startRound(PrizeType.ETH_AND_NFT, 0.05 ether, 0);
```

**Step 4 — Pick a winner (after at least 3 players enter)**
```solidity
lottery.pickWinner();
```

**Step 5 — Cancel a round (emergency)**
```solidity
// Refunds all players and returns NFT to manager
lottery.cancelRound();
```

### As Player

**Enter the current round**
```solidity
// Send exactly the entry fee — check getCurrentRoundStatus() first
lottery.participate{value: 0.01 ether}();
```

**Check if you're in the current round**
```solidity
// Returns the roundId you entered — compare against current roundId
lottery.enteredRound(yourAddress);
```

---

## Contract Functions

### Manager Functions

| Function | Parameters | Description |
|---|---|---|
| `startRound()` | `_prizeType, _entryFee, _nftTokenId` | Opens a new round |
| `pickWinner()` | none | Picks winner, pays out, resets |
| `cancelRound()` | none | Cancels round, refunds all players |

### Player Functions

| Function | Parameters | Description |
|---|---|---|
| `participate()` | payable — send exact `entryFee` | Enter the current round |

### View Functions

| Function | Returns | Description |
|---|---|---|
| `getPlayers()` | `players[], playerCount, pot` | Current round snapshot |
| `getRoundInfo(roundId)` | `RoundInfo struct` | Full history of a past round |
| `getCurrentRoundStatus()` | `isOpen, roundId, numPlayers, pot, fee, prizeType, nftTokenId` | Complete current state |

### Events

| Event | When fired |
|---|---|
| `RoundStarted` | Manager opens a round |
| `PlayerEntered` | A player enters |
| `WinnerPicked` | Winner selected and paid |
| `RoundCancelled` | Manager cancels round |

### Custom Errors

| Error | Meaning |
|---|---|
| `RoundAlreadyOpen()` | Tried to start a round when one is running |
| `RoundNotOpen()` | Tried to enter/pick when no round is active |
| `EntryFeeTooLow(provided, minimum)` | Entry fee set below 0.001 ETH |
| `IncorrectEntryFee(sent, required)` | Player sent wrong ETH amount |
| `AlreadyEntered()` | Same address tried to enter twice |
| `MissingNftTokenId(prizeType)` | NFT round started without a tokenId |
| `NotEnoughPlayers(current, required)` | Less than 3 players when pickWinner called |
| `TransferFailed()` | ETH transfer to winner or manager failed |
| `RefundFailed(player)` | ETH refund to a player failed during cancel |
| `InvalidRoundId(requested)` | getRoundInfo called with non-existent roundId |

---

## Security Considerations

| Pattern | Implementation |
|---|---|
| **Checks-Effects-Interactions** | All require/revert checks run before state changes, state changes before external calls |
| **Access control** | `onlyManager` modifier on all admin functions |
| **Safe ETH transfer** | `call{value}()` with return value check — not `transfer()` |
| **Integer precision** | Multiply before divide in fee calculation |
| **No selfdestruct** | Contract cannot be destroyed |
| **NFT held in escrow** | NFT transferred into Lottery contract at round start — not just approved |

---

## Deployed Contracts

| Contract | Network | Address | Etherscan |
|---|---|---|---|
| `LotteryNFT` | Sepolia | `0x...` | [View](https://sepolia.etherscan.io/address/0x...) |
| `Lottery` | Sepolia | `0x...` | [View](https://sepolia.etherscan.io/address/0x...) |

> Update these addresses after deployment.

---

## Team

| Name | Role |
|---|---|
| Member 1 | Smart contracts (src) |
| Member 2 | Smart contracts (src) |
| Member 3 | Smart contracts (src) |
| Member 4 | Smart contracts (src) |
| Member 5 | Smart contracts (src) |
| Member 6 | Deployment scripts (script) |
| Member 7 | Deployment scripts (script) |
| Member 8 | Deployment scripts (script) |
| Member 9 | Tests (test) |
| Member 10 | Tests (test) |

---

## License

MIT
