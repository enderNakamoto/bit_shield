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
        uint256 triggerPrice;
        bool hasLiquidated;
    }
    
    mapping(uint256 => MarketTiming) public marketTimings;
    
    constructor() {
        // Initialize every market to Open state by default
    }
    
    // This function will be called by MarketCreator when a market is created (with timing parameters)
    function marketCreated(uint256 marketId, uint256 eventStartTime, uint256 eventEndTime, uint256 triggerPrice) external {
        marketStates[marketId] = MarketState.Open;
        marketTimings[marketId] = MarketTiming(eventStartTime, eventEndTime, triggerPrice, false);
    }
    
    // Legacy function for backward compatibility with tests
    function marketCreated(uint256 marketId, uint256 eventStartTime, uint256 eventEndTime) external {
        marketStates[marketId] = MarketState.Open;
        // Default to some reasonable times and a default trigger price
        marketTimings[marketId] = MarketTiming(
            eventStartTime, 
            eventEndTime,
            1000, // Default trigger price
            false
        );
    }
    
    // Process oracle data to potentially liquidate or mature markets
    function processOracleData(uint256 marketId, uint256 currentPrice, uint256 timestamp) external {
        MarketTiming storage timing = marketTimings[marketId];
        
        // If price is below trigger and market is in progress, liquidate it
        if (currentPrice < timing.triggerPrice && 
            marketStates[marketId] == MarketState.InProgress &&
            block.timestamp >= timing.eventStartTime &&
            block.timestamp <= timing.eventEndTime) {
            
            marketStates[marketId] = MarketState.Liquidated;
            timing.hasLiquidated = true;
        }
        // If event has ended and market wasn't liquidated, mature it
        else if (marketStates[marketId] == MarketState.InProgress && 
                 block.timestamp > timing.eventEndTime &&
                 !timing.hasLiquidated) {
            
            marketStates[marketId] = MarketState.Matured;
        }
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
        marketTimings[marketId].hasLiquidated = true;
    }
    
    function matureMarket(uint256 marketId) external {
        // Only mature if not already liquidated
        if (!marketTimings[marketId].hasLiquidated) {
            marketStates[marketId] = MarketState.Matured;
        }
    }
    
    function startMarket(uint256 marketId) external {
        marketStates[marketId] = MarketState.InProgress;
    }
    
    // Getter function for market timing information
    function getMarketTiming(uint256 marketId) external view returns (uint256 startTime, uint256 endTime) {
        MarketTiming memory timing = marketTimings[marketId];
        return (timing.eventStartTime, timing.eventEndTime);
    }
    
    // Getter function for market trigger price
    function getMarketTriggerPrice(uint256 marketId) external view returns (uint256) {
        return marketTimings[marketId].triggerPrice;
    }
} 