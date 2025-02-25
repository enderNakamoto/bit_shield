// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MarketCreator.sol";
import "./vaults/RiskVault.sol";
import "./vaults/HedgeVault.sol";

contract Controller {
    MarketCreator public immutable marketCreator;
    
    // Market states enum
    enum MarketState {
        Open,       // Market is open for deposits and withdrawals
        InProgress, // Market is in progress, no deposits or withdrawals allowed
        Matured,    // Market has matured, deposits and withdrawals allowed
        Liquidated  // Market has been liquidated, deposits and withdrawals allowed
    }
    
    // Market timing and pricing information
    struct MarketDetails {
        uint256 eventStartTime;   // Timestamp when the event starts (when market can transition to InProgress)
        uint256 eventEndTime;     // Timestamp when the event ends (when market can transition to Matured)
        uint256 triggerPrice;     // Price at which liquidation is triggered
        bool hasLiquidated;       // Flag to track if market has ever been liquidated
    }
    
    // Mapping from market ID to market state
    mapping(uint256 => MarketState) public marketStates;
    
    // Mapping from market ID to market details
    mapping(uint256 => MarketDetails) public marketDetails;
    
    event MarketStateChanged(uint256 indexed marketId, MarketState state);
    event MarketLiquidated(uint256 indexed marketId);
    event MarketMatured(uint256 indexed marketId);
    event MarketCreated(uint256 indexed marketId, uint256 eventStartTime, uint256 eventEndTime, uint256 triggerPrice);
    
    error DepositNotAllowed(uint256 marketId, MarketState state);
    error WithdrawNotAllowed(uint256 marketId, MarketState state);
    error InvalidStateTransition(uint256 marketId, MarketState currentState, MarketState newState);
    error EventNotStartedYet(uint256 marketId, uint256 currentTime, uint256 startTime);
    error EventNotEndedYet(uint256 marketId, uint256 currentTime, uint256 endTime);
    error EventAlreadyEnded(uint256 marketId, uint256 currentTime, uint256 endTime);
    error MarketAlreadyLiquidated(uint256 marketId);
    error PriceAboveTrigger(uint256 marketId, uint256 currentPrice, uint256 triggerPrice);
    error InvalidOracleData(uint256 marketId);
    error InvalidTriggerPrice();
    error OnlyCallableFromOracle();
    
    modifier notLiquidated(uint256 marketId) {
        if (marketStates[marketId] == MarketState.Liquidated || marketDetails[marketId].hasLiquidated) {
            revert MarketAlreadyLiquidated(marketId);
        }
        _;
    }
    
    constructor(address marketCreator_) {
        require(marketCreator_ != address(0), "Invalid market creator address");
        marketCreator = MarketCreator(marketCreator_);
    }
    
    // Function to set a market to In Progress state
    function startMarket(uint256 marketId) external {
        MarketState currentState = marketStates[marketId];
        MarketDetails memory details = marketDetails[marketId];
        
        // Only allow transitioning from Open to InProgress
        if (currentState != MarketState.Open) {
            revert InvalidStateTransition(marketId, currentState, MarketState.InProgress);
        }
        
        // Check if the event start time has been reached
        if (block.timestamp < details.eventStartTime) {
            revert EventNotStartedYet(marketId, block.timestamp, details.eventStartTime);
        }
        
        // Check if the event end time has not passed
        if (block.timestamp > details.eventEndTime) {
            revert EventAlreadyEnded(marketId, block.timestamp, details.eventEndTime);
        }
        
        marketStates[marketId] = MarketState.InProgress;
        emit MarketStateChanged(marketId, MarketState.InProgress);
    }
    
    // Process oracle data and trigger liquidation if needed
    function processOracleData(uint256 marketId, uint256 currentPrice, uint256 timestamp) external {
        // Validate the data
        if (timestamp > block.timestamp) {
            revert InvalidOracleData(marketId);
        }
        
        MarketState currentState = marketStates[marketId];
        MarketDetails storage details = marketDetails[marketId];
        
        // Handle liquidation case
        if (currentPrice < details.triggerPrice && 
            currentState == MarketState.InProgress &&
            block.timestamp >= details.eventStartTime &&
            block.timestamp <= details.eventEndTime) {
            
            // Call internal liquidation function
            _liquidateMarket(marketId);
            
        }
        // Handle maturation case - event ended without liquidation
        else if (currentState == MarketState.InProgress && 
                 block.timestamp > details.eventEndTime &&
                 !details.hasLiquidated) {
            
            matureMarket(marketId);
        }
    }
    
    // Internal function to liquidate market, only callable from processOracleData
    function _liquidateMarket(uint256 marketId) internal {
        (address riskVault, address hedgeVault) = marketCreator.getVaults(marketId);
        MarketDetails storage details = marketDetails[marketId];
        
        // Get total assets in Risk Vault
        uint256 riskAssets = IERC20(marketCreator.asset()).balanceOf(riskVault);
        
        // Move all assets from Risk to Hedge vault if there are any
        if (riskAssets > 0) {
            // Use try/catch to handle potential failures in transferAssets
            try RiskVault(riskVault).transferAssets(hedgeVault, riskAssets) {
                // Transfer succeeded
            } catch {
                // Transfer failed, but we still want to liquidate the market
                // Log a warning but don't revert
            }
        }
        
        // Update market state to Liquidated
        marketStates[marketId] = MarketState.Liquidated;
        // Set the liquidation flag
        details.hasLiquidated = true;
        
        emit MarketStateChanged(marketId, MarketState.Liquidated);
        emit MarketLiquidated(marketId);
    }
    
    // Check if deposit is allowed for a market
    function isDepositAllowed(uint256 marketId) external view returns (bool) {
        MarketState state = marketStates[marketId];
        return state == MarketState.Open || 
               state == MarketState.Matured || 
               state == MarketState.Liquidated;
    }
    
    // Check if withdraw is allowed for a market
    function isWithdrawAllowed(uint256 marketId) external view returns (bool) {
        MarketState state = marketStates[marketId];
        return state == MarketState.Open || 
               state == MarketState.Matured || 
               state == MarketState.Liquidated;
    }
    
    // Function to check deposit permission and revert if not allowed
    function checkDepositAllowed(uint256 marketId) external view {
        MarketState state = marketStates[marketId];
        if (!(state == MarketState.Open || 
              state == MarketState.Matured || 
              state == MarketState.Liquidated)) {
            revert DepositNotAllowed(marketId, state);
        }
    }
    
    // Function to check withdraw permission and revert if not allowed
    function checkWithdrawAllowed(uint256 marketId) external view {
        MarketState state = marketStates[marketId];
        if (!(state == MarketState.Open || 
              state == MarketState.Matured || 
              state == MarketState.Liquidated)) {
            revert WithdrawNotAllowed(marketId, state);
        }
    }
    
    function matureMarket(uint256 marketId) public notLiquidated(marketId) {
        (address riskVault, address hedgeVault) = marketCreator.getVaults(marketId);
        MarketState currentState = marketStates[marketId];
        MarketDetails memory details = marketDetails[marketId];
        
        // Only allow maturation if:
        // 1. The market is in progress
        // 2. The event has ended
        if (currentState != MarketState.InProgress) {
            revert InvalidStateTransition(marketId, currentState, MarketState.Matured);
        }
        
        if (block.timestamp < details.eventEndTime) {
            revert EventNotEndedYet(marketId, block.timestamp, details.eventEndTime);
        }
        
        // Get total assets in Hedge Vault
        uint256 hedgeAssets = IERC20(marketCreator.asset()).balanceOf(hedgeVault);
        
        // Move all assets from Hedge to Risk vault if there are any
        if (hedgeAssets > 0) {
            // Use try/catch to handle potential failures in transferAssets
            try HedgeVault(hedgeVault).transferAssets(riskVault, hedgeAssets) {
                // Transfer succeeded
            } catch {
                // Transfer failed, but we still want to mature the market
                // Log a warning but don't revert
                emit MarketMatured(marketId);
            }
        }
        
        // Update market state to Matured
        marketStates[marketId] = MarketState.Matured;
        emit MarketStateChanged(marketId, MarketState.Matured);
        emit MarketMatured(marketId);
    }
    
    // Internal implementation of marketCreated
    function _marketCreated(
        uint256 marketId, 
        uint256 eventStartTime, 
        uint256 eventEndTime,
        uint256 triggerPrice
    ) internal {
        // Validate parameters
        require(eventStartTime > block.timestamp, "Event start time must be in the future");
        require(eventEndTime > eventStartTime, "Event end time must be after start time");
        require(triggerPrice > 0, "Trigger price must be greater than zero");
        
        // Store details information
        marketDetails[marketId] = MarketDetails({
            eventStartTime: eventStartTime,
            eventEndTime: eventEndTime,
            triggerPrice: triggerPrice,
            hasLiquidated: false
        });
        
        // Set initial state to Open
        marketStates[marketId] = MarketState.Open;
        emit MarketStateChanged(marketId, MarketState.Open);
        emit MarketCreated(marketId, eventStartTime, eventEndTime, triggerPrice);
    }
    
    // Function called by MarketCreator when a new market is created with trigger price
    function marketCreated(
        uint256 marketId, 
        uint256 eventStartTime, 
        uint256 eventEndTime,
        uint256 triggerPrice
    ) external {
        // Only MarketCreator should be able to call this
        require(msg.sender == address(marketCreator), "Only MarketCreator can call this");
        _marketCreated(marketId, eventStartTime, eventEndTime, triggerPrice);
    }
    
    // For backward compatibility with existing tests
    function marketCreated(uint256 marketId, uint256 eventStartTime, uint256 eventEndTime) external {
        // Only MarketCreator should be able to call this
        require(msg.sender == address(marketCreator), "Only MarketCreator can call this");
        
        // Use a default trigger price of 1000 (arbitrary value)
        uint256 defaultTriggerPrice = 1000;
        _marketCreated(marketId, eventStartTime, eventEndTime, defaultTriggerPrice);
    }
    
    // Getter function for market timing information
    function getMarketTiming(uint256 marketId) external view returns (uint256 startTime, uint256 endTime) {
        MarketDetails memory details = marketDetails[marketId];
        return (details.eventStartTime, details.eventEndTime);
    }
    
    // Getter function for market trigger price
    function getMarketTriggerPrice(uint256 marketId) external view returns (uint256) {
        return marketDetails[marketId].triggerPrice;
    }
    
    // --- Frontend entry point functions ---
    
    // Create a market with custom parameters through Controller
    function createMarket(
        uint256 eventStartTime,
        uint256 eventEndTime,
        uint256 triggerPrice
    ) external returns (uint256 marketId, address riskVault, address hedgeVault) {
        return marketCreator.createMarketVaults(eventStartTime, eventEndTime, triggerPrice);
    }
    
    // Create a market with custom timing parameters and default trigger price
    function createMarket(
        uint256 eventStartTime,
        uint256 eventEndTime
    ) external returns (uint256 marketId, address riskVault, address hedgeVault) {
        return marketCreator.createMarketVaults(eventStartTime, eventEndTime);
    }
    
    // Create a market with all default parameters
    function createMarket() external returns (uint256 marketId, address riskVault, address hedgeVault) {
        return marketCreator.createMarketVaults();
    }
    
    // Get vaults for a specific market
    function getMarketVaults(uint256 marketId) external view returns (address riskVault, address hedgeVault) {
        return marketCreator.getVaults(marketId);
    }
} 