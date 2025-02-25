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
    function processOracleData(uint256 marketId, uint256 price, uint256 timestamp) external {
        // For testing, we'll just liquidate the market if the price is less than 800
        if (price < 800) {
            marketStates[marketId] = MarketState.Liquidated;
            marketTimings[marketId].hasLiquidated = true;
        }
    }
    
    // Start a market (transition from Open to InProgress)
    function startMarket(uint256 marketId) external {
        marketStates[marketId] = MarketState.InProgress;
    }
    
    // Mature a market (transition from InProgress to Matured)
    function matureMarket(uint256 marketId) external {
        // Cannot mature a liquidated market
        if (marketTimings[marketId].hasLiquidated) {
            revert("MarketAlreadyLiquidated");
        }
        marketStates[marketId] = MarketState.Matured;
    }
    
    // Check if deposit is allowed for a given market
    function checkDepositAllowed(uint256 marketId) external view {
        // Only allow deposits in Open state
        if (marketStates[marketId] != MarketState.Open) {
            revert("DepositNotAllowed");
        }
    }
    
    // Check if withdrawal is allowed for a given market
    function checkWithdrawAllowed(uint256 marketId) external view {
        // Only allow withdrawals in Open, Matured, or Liquidated states
        if (marketStates[marketId] == MarketState.InProgress) {
            revert("WithdrawNotAllowed");
        }
    }
    
    // Directly get market timing parameters for testing
    function getMarketTiming(uint256 marketId) external view returns (uint256, uint256) {
        return (marketTimings[marketId].eventStartTime, marketTimings[marketId].eventEndTime);
    }
    
    // Get the trigger price for a market
    function getMarketTriggerPrice(uint256 marketId) external view returns (uint256) {
        return marketTimings[marketId].triggerPrice;
    }
} 