const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Contract ABIs (simplified for demo)
const TOKEN_ABI = [
    "function balanceOf(address owner) view returns (uint256)",
    "function totalSupply() view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)"
];

const SWAP_ABI = [
    "function reserveA() view returns (uint256)",
    "function reserveB() view returns (uint256)",
    "function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) pure returns (uint256)",
    "function balanceOf(address owner) view returns (uint256)",
    "function totalSupply() view returns (uint256)"
];

const STAKING_ABI = [
    "function balances(address account) view returns (uint256)",
    "function earned(address account) view returns (uint256)",
    "function rewardRate() view returns (uint256)",
    "function totalStaked() view returns (uint256)",
    "function getStakingInfo(address account) view returns (uint256, uint256, uint256, uint256)"
];

// Initialize provider (you can use different networks)
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL || 'http://localhost:8545');

// Contract addresses (you'll need to deploy and update these)
const CONTRACT_ADDRESSES = {
    TOKEN_A: process.env.TOKEN_A_ADDRESS || '0x...',
    TOKEN_B: process.env.TOKEN_B_ADDRESS || '0x...',
    SWAP: process.env.SWAP_ADDRESS || '0x...',
    STAKING: process.env.STAKING_ADDRESS || '0x...'
};

// Routes

// Get token information
app.get('/api/token/:address', async (req, res) => {
    try {
        const { address } = req.params;
        const contract = new ethers.Contract(address, TOKEN_ABI, provider);
        
        const [symbol, decimals, totalSupply] = await Promise.all([
            contract.symbol(),
            contract.decimals(),
            contract.totalSupply()
        ]);
        
        res.json({
            address,
            symbol,
            decimals: decimals.toString(),
            totalSupply: ethers.formatUnits(totalSupply, decimals)
        });
    } catch (error) {
        console.error('Token info error:', error);
        res.status(500).json({ error: 'Failed to fetch token information' });
    }
});

// Get user token balance
app.get('/api/balance/:tokenAddress/:userAddress', async (req, res) => {
    try {
        const { tokenAddress, userAddress } = req.params;
        const contract = new ethers.Contract(tokenAddress, TOKEN_ABI, provider);
        
        const [balance, decimals] = await Promise.all([
            contract.balanceOf(userAddress),
            contract.decimals()
        ]);
        
        res.json({
            balance: ethers.formatUnits(balance, decimals),
            raw: balance.toString()
        });
    } catch (error) {
        console.error('Balance error:', error);
        res.status(500).json({ error: 'Failed to fetch balance' });
    }
});

// Get swap quote
app.get('/api/swap/quote', async (req, res) => {
    try {
        const { amountIn, tokenIn, tokenOut } = req.query;
        
        if (!amountIn || !tokenIn || !tokenOut) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }
        
        const swapContract = new ethers.Contract(CONTRACT_ADDRESSES.SWAP, SWAP_ABI, provider);
        const [reserveA, reserveB] = await Promise.all([
            swapContract.reserveA(),
            swrapContract.reserveB()
        ]);
        
        // Determine which direction the swap is
        const isAtoB = tokenIn.toLowerCase() === CONTRACT_ADDRESSES.TOKEN_A.toLowerCase();
        const amountInWei = ethers.parseUnits(amountIn, 18);
        
        let amountOut;
        if (isAtoB) {
            amountOut = await swapContract.getAmountOut(amountInWei, reserveA, reserveB);
        } else {
            amountOut = await swapContract.getAmountOut(amountInWei, reserveB, reserveA);
        }
        
        res.json({
            amountIn,
            amountOut: ethers.formatUnits(amountOut, 18),
            priceImpact: calculatePriceImpact(amountInWei, isAtoB ? reserveA : reserveB, amountOut),
            reserveA: ethers.formatUnits(reserveA, 18),
            reserveB: ethers.formatUnits(reserveB, 18)
        });
    } catch (error) {
        console.error('Swap quote error:', error);
        res.status(500).json({ error: 'Failed to get swap quote' });
    }
});

// Get liquidity pool information
app.get('/api/pool/info', async (req, res) => {
    try {
        const swapContract = new ethers.Contract(CONTRACT_ADDRESSES.SWAP, SWAP_ABI, provider);
        
        const [reserveA, reserveB, totalSupply] = await Promise.all([
            swapContract.reserveA(),
            swapContract.reserveB(),
            swapContract.totalSupply()
        ]);
        
        res.json({
            reserveA: ethers.formatUnits(reserveA, 18),
            reserveB: ethers.formatUnits(reserveB, 18),
            totalSupply: ethers.formatUnits(totalSupply, 18),
            ratio: reserveA > 0 ? (Number(ethers.formatUnits(reserveB, 18)) / Number(ethers.formatUnits(reserveA, 18))).toFixed(6) : '0'
        });
    } catch (error) {
        console.error('Pool info error:', error);
        res.status(500).json({ error: 'Failed to fetch pool information' });
    }
});

// Get user liquidity position
app.get('/api/pool/position/:userAddress', async (req, res) => {
    try {
        const { userAddress } = req.params;
        const swapContract = new ethers.Contract(CONTRACT_ADDRESSES.SWAP, SWAP_ABI, provider);
        
        const [userLiquidity, totalSupply, reserveA, reserveB] = await Promise.all([
            swapContract.balanceOf(userAddress),
            swapContract.totalSupply(),
            swapContract.reserveA(),
            swapContract.reserveB()
        ]);
        
        const share = totalSupply > 0 ? (userLiquidity * 10000n) / totalSupply : 0n;
        const userTokenA = totalSupply > 0 ? (userLiquidity * reserveA) / totalSupply : 0n;
        const userTokenB = totalSupply > 0 ? (userLiquidity * reserveB) / totalSupply : 0n;
        
        res.json({
            liquidity: ethers.formatUnits(userLiquidity, 18),
            share: (Number(share) / 100).toFixed(2) + '%',
            tokenA: ethers.formatUnits(userTokenA, 18),
            tokenB: ethers.formatUnits(userTokenB, 18)
        });
    } catch (error) {
        console.error('Position error:', error);
        res.status(500).json({ error: 'Failed to fetch position' });
    }
});

// Get staking information
app.get('/api/staking/info/:userAddress', async (req, res) => {
    try {
        const { userAddress } = req.params;
        const stakingContract = new ethers.Contract(CONTRACT_ADDRESSES.STAKING, STAKING_ABI, provider);
        
        const [stakedAmount, earnedRewards, timeStaked, rewardRate] = await stakingContract.getStakingInfo(userAddress);
        const totalStaked = await stakingContract.totalStaked();
        
        res.json({
            stakedAmount: ethers.formatUnits(stakedAmount, 18),
            earnedRewards: ethers.formatUnits(earnedRewards, 18),
            timeStaked: timeStaked.toString(),
            rewardRate: rewardRate.toString(),
            totalStaked: ethers.formatUnits(totalStaked, 18),
            apr: calculateAPR(rewardRate, totalStaked)
        });
    } catch (error) {
        console.error('Staking info error:', error);
        res.status(500).json({ error: 'Failed to fetch staking information' });
    }
});

// Get transaction history (simplified - you might want to use a graph protocol or event logs)
app.get('/api/transactions/:userAddress', async (req, res) => {
    try {
        const { userAddress } = req.params;
        const { limit = 20, offset = 0 } = req.query;
        
        // This is a simplified implementation
        // In production, you'd want to use event logs or a subgraph
        const transactions = await getTransactionHistory(userAddress, limit, offset);
        
        res.json({
            transactions,
            total: transactions.length
        });
    } catch (error) {
        console.error('Transaction history error:', error);
        res.status(500).json({ error: 'Failed to fetch transaction history' });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Utility functions
function calculatePriceImpact(amountIn, reserve, amountOut) {
    if (reserve === 0n) return '0';
    
    const spotPrice = Number(ethers.formatUnits(reserve, 18));
    const effectivePrice = Number(ethers.formatUnits(amountIn, 18)) / Number(ethers.formatUnits(amountOut, 18));
    const impact = Math.abs((effectivePrice - spotPrice) / spotPrice) * 100;
    
    return impact.toFixed(2);
}

function calculateAPR(rewardRate, totalStaked) {
    if (totalStaked === 0n) return '0';
    
    const yearlyRewards = Number(rewardRate) * 365 * 24 * 60 * 60; // rewards per year
    const apr = (yearlyRewards / Number(ethers.formatUnits(totalStaked, 18))) * 100;
    
    return apr.toFixed(2);
}

async function getTransactionHistory(userAddress, limit, offset) {
    // Simplified implementation - in production, use event logs
    return [
        {
            hash: '0x123...',
            type: 'swap',
            timestamp: Date.now() - 86400000,
            amount: '100.0',
            token: 'DFT'
        }
    ];
}

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Unhandled error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;