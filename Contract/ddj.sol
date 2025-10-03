// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Defi Token Swap
 * @dev Interface for the Chainlink V3 data feed aggregator.
 */
interface Defi Token Swap  {
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);
  function getRoundData(uint80 _roundId) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
  function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/**
 * @title PriceOracle
 * @dev A decentralized price prediction platform using Chainlink oracles and commit-reveal scheme.
 */
contract PriceOracle {
    // --- State Variables ---

    address public owner;
    mapping(address => address) public priceFeeds; // Mapping from token address to price feed address

    enum PredictionChoice { High, Low }
    enum PredictionResult { Pending, Won, Lost }

    struct Prediction {
        address user;
        address token;
        uint256 predictedPrice;
        uint256 targetTimestamp;
        PredictionChoice choice;
        PredictionResult result;
        bool revealed;
    }

    mapping(address => bytes32) public commitments;
    mapping(bytes32 => Prediction) public predictions;

    // --- Events ---

    event PredictionCommitted(address indexed user, bytes32 commitment);
    event PredictionRevealed(address indexed user, address indexed token, uint256 predictedPrice, PredictionChoice choice, uint256 targetTimestamp);
    event PredictionOutcome(bytes32 indexed commitment, PredictionResult result);
    event PriceFeedSet(address indexed token, address indexed priceFeed);

    // --- Modifiers ---

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // --- Functions ---

    /**
     * @dev Sets the contract owner and pre-configures price feeds for Base mainnet.
     */
    constructor() {
        owner = msg.sender;

        // Pre-configure price feeds for Base mainnet
        // These are the addresses for wrapped tokens and their corresponding oracles.
        // Users will make predictions against these token addresses.

        // ETH/USD -> WETH on Base
        setPriceFeed(0x4200000000000000000000000000000000000006, 0x4adC67696ba383F43Dd60A9eA08325aC242a4b93);

        // BTC/USD -> WBTC on Base
        setPriceFeed(0x1cea84203673764245E35E2154A8563D2574A049, 0x042264344422c42661571052A36a021235636594);

        // SOL/USD -> Wrapped SOL on Base
        setPriceFeed(0x2d346c4593E2548148a0747a7536a444c901844a, 0x000216E161f32a334850125471452652aC226767);
    }

    /**
     * @dev Allows the owner to set or update the price feed address for a given token.
     * @param _token The address of the token (e.g., WETH).
     * @param _priceFeed The address of the Chainlink data feed for that token.
     */
    function setPriceFeed(address _token, address _priceFeed) public onlyOwner {
        require(_token != address(0), "Invalid token address");
        require(_priceFeed != address(0), "Invalid price feed address");
        priceFeeds[_token] = _priceFeed;
        emit PriceFeedSet(_token, _priceFeed);
    }

    /**
     * @dev Commits a prediction.
     * @param _commitment A hash of the prediction details and a salt.
     */
    function commit(bytes32 _commitment) public {
        require(commitments[msg.sender] == 0, "Commitment already exists");
        commitments[msg.sender] = _commitment;
        emit PredictionCommitted(msg.sender, _commitment);
    }

    /**
     * @dev Reveals a prediction.
     * @param _token The token address for the prediction.
     * @param _predictedPrice The predicted price of the token.
     * @param _choice The user's prediction choice (High or Low).
     * @param _targetTimestamp The timestamp for the prediction.
     * @param _salt A random salt to prevent hash collisions.
     */
    function reveal(
        address _token,
        uint256 _predictedPrice,
        PredictionChoice _choice,
        uint256 _targetTimestamp,
        bytes32 _salt
    ) public {
        bytes32 commitment = commitments[msg.sender];
        require(commitment != 0, "No commitment found");

        bytes32 calculatedCommitment = keccak256(
            abi.encodePacked(
                msg.sender,
                _token,
                _predictedPrice,
                _choice,
                _targetTimestamp,
                _salt
            )
        );

        require(commitment == calculatedCommitment, "Calculated commitment does not match stored commitment");
        require(priceFeeds[_token] != address(0), "Price feed not set for this token");


        predictions[commitment] = Prediction({
            user: msg.sender,
            token: _token,
            predictedPrice: _predictedPrice,
            targetTimestamp: _targetTimestamp,
            choice: _choice,
            result: PredictionResult.Pending,
            revealed: true
        });

        delete commitments[msg.sender];

        emit PredictionRevealed(
            msg.sender,
            _token,
            _predictedPrice,
            _choice,
            _targetTimestamp
        );
    }

    /**
     * @dev Checks the price and determines the winner.
     * @param _commitment The commitment of the prediction to check.
     */
    function checkPrice(bytes32 _commitment) public {
        Prediction storage prediction = predictions[_commitment];
        require(prediction.revealed, "Prediction not revealed");
        require(block.timestamp > prediction.targetTimestamp + 24 hours, "Prediction window not over");
        require(prediction.result == PredictionResult.Pending, "Prediction already resolved");

        address priceFeedAddress = priceFeeds[prediction.token];
        require(priceFeedAddress != address(0), "Price feed not set for this token");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price, , , ) = priceFeed.latestRoundData();

        uint256 currentPrice = uint256(price);

        if (prediction.choice == PredictionChoice.High) {
            if (currentPrice > prediction.predictedPrice) {
                prediction.result = PredictionResult.Won;
            } else {
                prediction.result = PredictionResult.Lost;
            }
        } else { // PredictionChoice.Low
            if (currentPrice < prediction.predictedPrice) {
                prediction.result = PredictionResult.Won;
            } else {
                prediction.result = PredictionResult.Lost;
            }
        }

        emit PredictionOutcome(_commitment, prediction.result);
    }
}