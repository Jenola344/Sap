import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { ArrowDownUp, Wallet, TrendingUp, DollarSign, BarChart3, Settings } from 'lucide-react';

// Contract ABIs (simplified)
const TOKEN_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)"
];

const SWAP_ABI = [
  "function swapAtoB(uint256 amountIn) returns (uint256)",
  "function swapBtoA(uint256 amountIn) returns (uint256)",
  "function addLiquidity(uint256 amountA, uint256 amountB) returns (uint256)",
  "function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) view returns (uint256)"
];

const STAKING_ABI = [
  "function stake(uint256 amount)",
  "function withdraw(uint256 amount)",
  "function getReward()",
  "function earned(address account) view returns (uint256)",
  "function balances(address account) view returns (uint256)"
];

// Contract addresses (update with actual deployed addresses)
const CONTRACTS = {
  TOKEN_A: '0x...',
  TOKEN_B: '0x...',
  SWAP: '0x...',
  STAKING: '0x...'
};

const API_BASE = 'http://localhost:5000/api';

function App() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState('');
  const [activeTab, setActiveTab] = useState('swap');
  const [balances, setBalances] = useState({ tokenA: '0', tokenB: '0' });
  const [swapData, setSwapData] = useState({
    fromToken: 'A',
    toToken: 'B',
    fromAmount: '',
    toAmount: '',
    slippage: '0.5'
  });
  const [liquidityData, setLiquidityData] = useState({
    tokenA: '',
    tokenB: '',
    userLiquidity: '0'
  });
  const [stakingData, setStakingData] = useState({
    staked: '0',
    earned: '0',
    amount: ''
  });
  const [loading, setLoading] = useState(false);
  const [poolInfo, setPoolInfo] = useState({ reserveA: '0', reserveB: '0', ratio: '0' });

  // Connect wallet
  const connectWallet = async () => {
    try {
      if (window.ethereum) {
        const provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send('eth_requestAccounts', []);
        const signer = await provider.getSigner();
        const address = await signer.getAddress();
        
        setProvider(provider);
        setSigner(signer);
        setAccount(address);
        
        await loadBalances(address);
        await loadPoolInfo();
        await loadStakingInfo(address);
      } else {
        alert('Please install MetaMask!');
      }
    } catch (error) {
      console.error('Connection error:', error);
    }
  };

  // Load user balances
  const loadBalances = async (address) => {
    try {
      const [balanceA, balance