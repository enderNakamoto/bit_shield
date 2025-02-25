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
    
    // Mapping from market ID to market state
    mapping(uint256 => MarketState) public marketStates;
    
    event MarketStateChanged(uint256 indexed marketId, MarketState state);
    event MarketLiquidated(uint256 indexed marketId);
    event MarketMatured(uint256 indexed marketId);
    
    error DepositNotAllowed(uint256 marketId, MarketState state);
    error WithdrawNotAllowed(uint256 marketId, MarketState state);
    error InvalidStateTransition(uint256 marketId, MarketState currentState, MarketState newState);
    
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
        
        // Only allow transitioning from Open to InProgress
        if (currentState != MarketState.Open) {
            revert InvalidStateTransition(marketId, currentState, MarketState.InProgress);
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
        
        // Get total assets in Risk Vault
        uint256 riskAssets = IERC20(marketCreator.asset()).balanceOf(riskVault);
        
        // Move all assets from Risk to Hedge vault if there are any
        if (riskAssets > 0) {
            RiskVault(riskVault).transferAssets(hedgeVault, riskAssets);
        }
        
        // Update market state to Liquidated
        marketStates[marketId] = MarketState.Liquidated;
        emit MarketStateChanged(marketId, MarketState.Liquidated);
        emit MarketLiquidated(marketId);
    }
    
    function matureMarket(uint256 marketId) external {
        (address riskVault, address hedgeVault) = marketCreator.getVaults(marketId);
        
        // Get total assets in Hedge Vault
        uint256 hedgeAssets = IERC20(marketCreator.asset()).balanceOf(hedgeVault);
        
        // Move all assets from Hedge to Risk vault if there are any
        if (hedgeAssets > 0) {
            HedgeVault(hedgeVault).transferAssets(riskVault, hedgeAssets);
        }
        
        // Update market state to Matured
        marketStates[marketId] = MarketState.Matured;
        emit MarketStateChanged(marketId, MarketState.Matured);
        emit MarketMatured(marketId);
    }
    
    // Function called by MarketCreator when a new market is created
    function marketCreated(uint256 marketId) external {
        // Only MarketCreator should be able to call this
        require(msg.sender == address(marketCreator), "Only MarketCreator can call this");
        
        // Set initial state to Open
        marketStates[marketId] = MarketState.Open;
        emit MarketStateChanged(marketId, MarketState.Open);
    }
} 