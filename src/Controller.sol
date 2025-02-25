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
    
    // Market timing information
    struct MarketTiming {
        uint256 eventStartTime;   // Timestamp when the event starts (when market can transition to InProgress)
        uint256 eventEndTime;     // Timestamp when the event ends (when market can transition to Matured)
    }
    
    // Mapping from market ID to market state
    mapping(uint256 => MarketState) public marketStates;
    
    // Mapping from market ID to market timing information
    mapping(uint256 => MarketTiming) public marketTimings;
    
    event MarketStateChanged(uint256 indexed marketId, MarketState state);
    event MarketLiquidated(uint256 indexed marketId);
    event MarketMatured(uint256 indexed marketId);
    event MarketCreated(uint256 indexed marketId, uint256 eventStartTime, uint256 eventEndTime);
    
    error DepositNotAllowed(uint256 marketId, MarketState state);
    error WithdrawNotAllowed(uint256 marketId, MarketState state);
    error InvalidStateTransition(uint256 marketId, MarketState currentState, MarketState newState);
    error EventNotStartedYet(uint256 marketId, uint256 currentTime, uint256 startTime);
    error EventNotEndedYet(uint256 marketId, uint256 currentTime, uint256 endTime);
    error EventAlreadyEnded(uint256 marketId, uint256 currentTime, uint256 endTime);
    error MarketAlreadyLiquidated(uint256 marketId);
    
    modifier notLiquidated(uint256 marketId) {
        if (marketStates[marketId] == MarketState.Liquidated) {
            revert MarketAlreadyLiquidated(marketId);
        }
        _;
    }
    
    constructor(address marketCreator_) {
        require(marketCreator_ != address(0), "Invalid market creator address");
        marketCreator = MarketCreator(marketCreator_);
    }
    
    // Function to set the market state
    function setMarketState(uint256 marketId, MarketState state) external {
        // For now, anyone can change the state. In a real implementation, 
        // this should be restricted to authorized roles.
        marketStates[marketId] = state;
        emit MarketStateChanged(marketId, state);
    }
    
    // Function to set a market to In Progress state
    function startMarket(uint256 marketId) external {
        MarketState currentState = marketStates[marketId];
        MarketTiming memory timing = marketTimings[marketId];
        
        // Only allow transitioning from Open to InProgress
        if (currentState != MarketState.Open) {
            revert InvalidStateTransition(marketId, currentState, MarketState.InProgress);
        }
        
        // Check if the event start time has been reached
        if (block.timestamp < timing.eventStartTime) {
            revert EventNotStartedYet(marketId, block.timestamp, timing.eventStartTime);
        }
        
        // Check if the event end time has not passed
        if (block.timestamp > timing.eventEndTime) {
            revert EventAlreadyEnded(marketId, block.timestamp, timing.eventEndTime);
        }
        
        marketStates[marketId] = MarketState.InProgress;
        emit MarketStateChanged(marketId, MarketState.InProgress);
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
    
    function liquidateMarket(uint256 marketId) external {
        (address riskVault, address hedgeVault) = marketCreator.getVaults(marketId);
        MarketState currentState = marketStates[marketId];
        MarketTiming memory timing = marketTimings[marketId];
        
        // Only allow liquidation if:
        // 1. The market is in progress
        // 2. The event has started
        // 3. The event hasn't ended yet
        if (currentState != MarketState.InProgress) {
            revert InvalidStateTransition(marketId, currentState, MarketState.Liquidated);
        }
        
        if (block.timestamp < timing.eventStartTime) {
            revert EventNotStartedYet(marketId, block.timestamp, timing.eventStartTime);
        }
        
        if (block.timestamp > timing.eventEndTime) {
            revert EventAlreadyEnded(marketId, block.timestamp, timing.eventEndTime);
        }
        
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
                emit MarketLiquidated(marketId);
            }
        }
        
        // Update market state to Liquidated
        marketStates[marketId] = MarketState.Liquidated;
        emit MarketStateChanged(marketId, MarketState.Liquidated);
        emit MarketLiquidated(marketId);
    }
    
    function matureMarket(uint256 marketId) external notLiquidated(marketId) {
        (address riskVault, address hedgeVault) = marketCreator.getVaults(marketId);
        MarketState currentState = marketStates[marketId];
        MarketTiming memory timing = marketTimings[marketId];
        
        // Only allow maturation if:
        // 1. The market is in progress
        // 2. The event has ended
        if (currentState != MarketState.InProgress) {
            revert InvalidStateTransition(marketId, currentState, MarketState.Matured);
        }
        
        if (block.timestamp < timing.eventEndTime) {
            revert EventNotEndedYet(marketId, block.timestamp, timing.eventEndTime);
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
    
    // Function called by MarketCreator when a new market is created
    function marketCreated(uint256 marketId, uint256 eventStartTime, uint256 eventEndTime) external {
        // Only MarketCreator should be able to call this
        require(msg.sender == address(marketCreator), "Only MarketCreator can call this");
        require(eventStartTime > block.timestamp, "Event start time must be in the future");
        require(eventEndTime > eventStartTime, "Event end time must be after start time");
        
        // Store timing information
        marketTimings[marketId] = MarketTiming({
            eventStartTime: eventStartTime,
            eventEndTime: eventEndTime
        });
        
        // Set initial state to Open
        marketStates[marketId] = MarketState.Open;
        emit MarketStateChanged(marketId, MarketState.Open);
        emit MarketCreated(marketId, eventStartTime, eventEndTime);
    }
    
    // Getter function for market timing information
    function getMarketTiming(uint256 marketId) external view returns (uint256 startTime, uint256 endTime) {
        MarketTiming memory timing = marketTimings[marketId];
        return (timing.eventStartTime, timing.eventEndTime);
    }
} 