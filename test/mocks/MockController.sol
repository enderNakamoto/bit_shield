// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockController {
    enum MarketState {
        Open,
        InProgress,
        Matured,
        Liquidated
    }
    
    mapping(uint256 => MarketState) public marketStates;
    
    constructor() {
        // Initialize every market to Open state by default
    }
    
    // This function will be called by MarketCreator when a market is created
    function marketCreated(uint256 marketId) external {
        marketStates[marketId] = MarketState.Open;
    }
    
    // These functions will always succeed in tests by default
    function checkDepositAllowed(uint256) external pure {}
    function checkWithdrawAllowed(uint256) external pure {}
    
    // Set market state for testing different scenarios
    function setMarketState(uint256 marketId, MarketState state) external {
        marketStates[marketId] = state;
    }
    
    // Mock the required functions from the real Controller
    function liquidateMarket(uint256 marketId) external {
        marketStates[marketId] = MarketState.Liquidated;
    }
    
    function matureMarket(uint256 marketId) external {
        marketStates[marketId] = MarketState.Matured;
    }
    
    function startMarket(uint256 marketId) external {
        marketStates[marketId] = MarketState.InProgress;
    }
} 