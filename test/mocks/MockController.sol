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
    
    // Market timing information
    struct MarketTiming {
        uint256 eventStartTime;
        uint256 eventEndTime;
    }
    
    mapping(uint256 => MarketTiming) public marketTimings;
    
    constructor() {
        // Initialize every market to Open state by default
    }
    
    // This function will be called by MarketCreator when a market is created (with timing parameters)
    function marketCreated(uint256 marketId, uint256 eventStartTime, uint256 eventEndTime) external {
        marketStates[marketId] = MarketState.Open;
        marketTimings[marketId] = MarketTiming(eventStartTime, eventEndTime);
    }
    
    // Legacy function for backward compatibility with tests
    function marketCreated(uint256 marketId) external {
        marketStates[marketId] = MarketState.Open;
        // Default to some reasonable times
        marketTimings[marketId] = MarketTiming(
            block.timestamp + 1 days,
            block.timestamp + 2 days
        );
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
    
    // Getter function for market timing information
    function getMarketTiming(uint256 marketId) external view returns (uint256 startTime, uint256 endTime) {
        MarketTiming memory timing = marketTimings[marketId];
        return (timing.eventStartTime, timing.eventEndTime);
    }
} 