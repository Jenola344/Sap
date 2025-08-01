// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DeFiToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1M tokens
    
    constructor() ERC20("DeFi Token", "DFT") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

contract TokenSwap is ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool isAtoB);
    event AddLiquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }
    
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");
        
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        
        if (totalSupply == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * totalSupply) / reserveA,
                (amountB * totalSupply) / reserveB
            );
        }
        
        require(liquidity > 0, "Insufficient liquidity");
        
        balanceOf[msg.sender] += liquidity;
        totalSupply += liquidity;
        reserveA += amountA;
        reserveB += amountB;
        
        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
    }
    
    function removeLiquidity(uint256 liquidity) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0 && balanceOf[msg.sender] >= liquidity, "Invalid liquidity");
        
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;
        
        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;
        
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);
        
        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
    }
    
    function swapAtoB(uint256 amountIn) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid amount");
        
        amountOut = getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut > 0, "Insufficient output amount");
        
        tokenA.transferFrom(msg.sender, address(this), amountIn);
        tokenB.transfer(msg.sender, amountOut);
        
        reserveA += amountIn;
        reserveB -= amountOut;
        
        emit Swap(msg.sender, amountIn, amountOut, true);
    }
    
    function swapBtoA(uint256 amountIn) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid amount");
        
        amountOut = getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut > 0, "Insufficient output amount");
        
        tokenB.transferFrom(msg.sender, address(this), amountIn);
        tokenA.transfer(msg.sender, amountOut);
        
        reserveB += amountIn;
        reserveA -= amountOut;
        
        emit Swap(msg.sender, amountIn, amountOut, false);
    }
    
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public pure returns (uint256 amountOut) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid reserves");
        
        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
        if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
        if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
        if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
        if (xx >= 0x100) { xx >>= 8; r <<= 4; }
        if (xx >= 0x10) { xx >>= 4; r <<= 2; }
        if (xx >= 0x8) { r <<= 1; }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
    
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }
}