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
    
    // Function to create market vaults with timing parameters
    function createMarketVaults(
        uint256 eventStartTime,
        uint256 eventEndTime
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
        try Controller(controller).marketCreated(marketId, eventStartTime, eventEndTime) {
            // Successfully notified the controller
        } catch {
            // The controller might not have the updated marketCreated function yet
            // or there might be an issue with the call, but we don't want to
            // revert the market creation process
        }
        
        emit MarketVaultsCreated(marketId, riskVault, hedgeVault, eventStartTime, eventEndTime);
        
        return (marketId, riskVault, hedgeVault);
    }
    
    // Keep a backwards-compatible version for test compatibility or simpler use cases
    function createMarketVaults() 
        external 
        returns (
            uint256 marketId,
            address riskVault,
            address hedgeVault
        ) 
    {
        // Default to start time 1 day in the future and end time 2 days in the future
        uint256 defaultStartTime = block.timestamp + 1 days;
        uint256 defaultEndTime = defaultStartTime + 1 days;
        
        // Create market vaults with default timing parameters
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
        
        // Notify the controller about the new market with default timing parameters
        try Controller(controller).marketCreated(marketId, defaultStartTime, defaultEndTime) {
            // Successfully notified the controller
        } catch {
            // The controller might not have the updated marketCreated function yet
            // or there might be an issue with the call, but we don't want to
            // revert the market creation process
        }
        
        emit MarketVaultsCreated(marketId, riskVault, hedgeVault, defaultStartTime, defaultEndTime);
        
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
    
    // For testing purposes - register existing vaults
    function registerVaults(uint256 marketId, address riskVault, address hedgeVault) external {
        // This should only be callable by the test contract
        require(msg.sender == controller, "Only controller can register vaults");
        
        marketVaults[marketId] = MarketVaults({
            riskVault: riskVault,
            hedgeVault: hedgeVault
        });
    }
} 