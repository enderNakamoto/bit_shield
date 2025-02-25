// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MarketCreator.sol";
import "./vaults/RiskVault.sol";
import "./vaults/HedgeVault.sol";

contract Controller {
    MarketCreator public immutable marketCreator;
    
    event MarketLiquidated(uint256 indexed marketId);
    event MarketMatured(uint256 indexed marketId);
    
    constructor(address marketCreator_) {
        require(marketCreator_ != address(0), "Invalid market creator address");
        marketCreator = MarketCreator(marketCreator_);
    }
    
    function liquidateMarket(uint256 marketId) external {
        (address riskVault, address hedgeVault) = marketCreator.getVaults(marketId);
        
        // Get total assets in Risk Vault
        uint256 riskAssets = IERC20(marketCreator.asset()).balanceOf(riskVault);
        
        // Move all assets from Risk to Hedge vault if there are any
        if (riskAssets > 0) {
            RiskVault(riskVault).transferAssets(hedgeVault, riskAssets);
        }
        
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
        
        emit MarketMatured(marketId);
    }
} 