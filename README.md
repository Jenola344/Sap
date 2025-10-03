# Sap : A DeFi Token Swap Platform

A full-stack decentralized finance (DeFi) application featuring token swapping, liquidity provision, and staking functionality built with React, Node.js, and Solidity.

## Features

- **Token Swapping**: Trade between two ERC-20 tokens with automated market maker (AMM) functionality
- **Liquidity Provision**: Add/remove liquidity to earn trading fees
- **Token Staking**: Stake tokens to earn rewards over time
- **Real-time Data**: Live price quotes, pool information, and user balances
- **Responsive UI**: Modern, mobile-friendly interface

## Tech Stack

### Frontend
- React.js with hooks
- Ethers.js for blockchain interaction
- Tailwind CSS for styling
- Lucide React for icons

### Backend
- Node.js with Express
- Ethers.js for contract interaction
- RESTful API endpoints
- CORS enabled for cross-origin requests

### Smart Contracts
- Solidity ^0.8.19
- OpenZeppelin contracts for security
- ERC-20 token implementation
- AMM swap contract with 0.3% fees
- Staking contract with reward distribution

## Project Structure

```
defi-platform/
├── contracts/
│   ├── Token.sol          # ERC-20 token and swap contracts
│   └── Staking.sol        # Staking rewards contract
├── backend/
│   ├── server.js          # Express API server
│   ├── package.json       # Node.js dependencies
│   └── .env               # Environment variables
└── frontend/
    └── App.jsx            # React application
```


## Usage

1. **Connect Wallet**: Click "Connect Wallet" to connect MetaMask
2. **Swap Tokens**: Enter amount and swap between Token A and Token B
3. **Add Liquidity**: Provide equal value of both tokens to earn fees
4. **Stake Tokens**: Stake your tokens to earn additional rewards

## Security Features

- ReentrancyGuard protection
- Access control with Ownable pattern
- Safe math operations
- Input validation and error handling

## Disclaimer

This is a demonstration project. Do not use in production without proper security audits and testing.
