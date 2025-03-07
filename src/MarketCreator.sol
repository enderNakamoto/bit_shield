// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./vaults/RiskVault.sol";
import "./vaults/HedgeVault.sol";
import "./Controller.sol";

contract MarketCreator {
    address public immutable controller;
    IERC20 public immutable asset;
    
    uint256 private nextMarketId;
    
    mapping(uint256 => MarketVaults) public marketVaults;
    
    struct MarketVaults {
        address riskVault;
        address hedgeVault;
    }
    
    event MarketVaultsCreated(
        uint256 indexed marketId,
        address indexed riskVault,
        address indexed hedgeVault,
        uint256 eventStartTime,
        uint256 eventEndTime
    );

    error VaultsNotFound();
    error NotController();
    error InvalidTimeParameters();
    
    modifier onlyController() {
        if (msg.sender != controller) revert NotController();
        _;
    }
    
    constructor(address controller_, address asset_) {
        require(controller_ != address(0), "Invalid controller address");
        require(asset_ != address(0), "Invalid asset address");
        controller = controller_;
        asset = IERC20(asset_);
        nextMarketId = 1;
    }
    
    // Function to create market vaults with timing parameters and trigger price
    function createMarketVaults(
        uint256 eventStartTime,
        uint256 eventEndTime,
        uint256 triggerPrice
    ) 
        external 
        returns (
            uint256 marketId,
            address riskVault,
            address hedgeVault
        ) 
    {
        // Validate time parameters
        if (eventStartTime <= block.timestamp || eventEndTime <= eventStartTime) {
            revert InvalidTimeParameters();
        }
        
        if (triggerPrice == 0) {
            revert("Trigger price must be greater than zero");
        }
        
        marketId = nextMarketId++;
        
        // Deploy Hedge vault first
        HedgeVault hedge = new HedgeVault(
            asset,
            controller,
            marketId
        );
        
        hedgeVault = address(hedge);
        
        // Deploy Risk vault with Hedge vault address
        RiskVault risk = new RiskVault(
            asset,
            controller,
            hedgeVault,
            marketId
        );
        
        riskVault = address(risk);
        
        // Set sister vault in Hedge vault
        hedge.setSisterVault(riskVault);
        
        // Store vault addresses
        marketVaults[marketId] = MarketVaults({
            riskVault: riskVault,
            hedgeVault: hedgeVault
        });
        
        // Notify the controller about the new market with timing parameters
        try Controller(controller).marketCreated(marketId, eventStartTime, eventEndTime, triggerPrice) {
            // Successfully notified the controller
        } catch {
            // The controller might not have the updated marketCreated function yet
            // or there might be an issue with the call, but we don't want to
            // revert the market creation process
        }
        
        emit MarketVaultsCreated(marketId, riskVault, hedgeVault, eventStartTime, eventEndTime);
        
        return (marketId, riskVault, hedgeVault);
    }
    
    function getVaults(uint256 marketId) 
        external 
        view 
        returns (
            address riskVault,
            address hedgeVault
        ) 
    {
        MarketVaults memory vaults = marketVaults[marketId];
        if (vaults.riskVault == address(0)) revert VaultsNotFound();
        return (vaults.riskVault, vaults.hedgeVault);
    }
} 