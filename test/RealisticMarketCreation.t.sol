// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";

/**
 * This test focuses on creating markets with realistic values
 * that can be used for deployment
 */
contract RealisticMarketCreationTest is Test {
    Controller public controller;
    MarketCreator public marketCreator;
    MockToken public asset;
    
    // Constants for time intervals
    uint256 constant HOUR = 3600; // seconds in an hour
    uint256 constant MINUTE = 60; // seconds in a minute
    
    function setUp() public {
        // Use real timestamps for realistic testing
        // No vm.warp here to use actual block timestamps
        
        // Deploy mock token for testing
        asset = new MockToken();
        console.log("Deployed mock token at:", address(asset));
        
        // Deploy Controller
        controller = new Controller();
        console.log("Deployed Controller at:", address(controller));
        
        // Deploy MarketCreator with controller and asset token
        marketCreator = new MarketCreator(address(controller), address(asset));
        console.log("Deployed MarketCreator at:", address(marketCreator));
        
        // Set MarketCreator in Controller - CRITICAL STEP
        controller.setMarketCreator(address(marketCreator));
        console.log("Set MarketCreator in Controller");
        
        // Verify setup is correct
        address storedCreator = address(controller.marketCreator());
        console.log("Controller's stored MarketCreator:", storedCreator);
        require(storedCreator == address(marketCreator), "MarketCreator not set correctly");
    }

    function testRealisticMarketCreation() public {
        // Print current timestamp for reference
        uint256 currentTime = block.timestamp;
        console.log("Current block timestamp:", currentTime);
        
        // Configure realistic market parameters using integer math
        // Start time: 2 hours from now
        uint256 startTime = currentTime + 2 * HOUR;
        // End time: 2 hours and 30 minutes from now
        uint256 endTime = currentTime + 2 * HOUR + 30 * MINUTE;
        // Trigger price: 20 (as requested)
        uint256 triggerPrice = 20;
        
        console.log("Using start time (in 2 hours):", startTime);
        console.log("Using end time (in 2 hours 30 min):", endTime);
        console.log("Using trigger price:", triggerPrice);
        
        // Create market with all required parameters
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket(
            startTime,
            endTime,
            triggerPrice
        );
        
        // Verify results
        console.log("Created market with ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
        
        // Verify market details
        (uint256 storedStart, uint256 storedEnd) = controller.getMarketTiming(marketId);
        uint256 storedTrigger = controller.getMarketTriggerPrice(marketId);
        
        assertEq(storedStart, startTime, "Start time mismatch");
        assertEq(storedEnd, endTime, "End time mismatch");
        assertEq(storedTrigger, triggerPrice, "Trigger price mismatch");
        
        // Print human-readable timestamps for deployment reference
        console.log("Start time (unix timestamp):", startTime);
        console.log("End time (unix timestamp):", endTime);
        console.log("These values can be used for deployment");
    }
    
    function testFixedUnixTimestamps() public {
        // Use fixed timestamps for consistent deployment values
        
        // June 1, 2024 at 12:00:00 UTC (example future date)
        uint256 startTime = 1717171200;
        // June 1, 2024 at 12:30:00 UTC (30 minutes later)
        uint256 startTimePlus30Min = 1717173000;
        uint256 triggerPrice = 20;
        
        console.log("=== FIXED DEPLOYMENT VALUES ===");
        console.log("START_TIME:", startTime);
        console.log("END_TIME:", startTimePlus30Min);
        console.log("TRIGGER_PRICE:", triggerPrice);
        console.log("==============================");
        
        // Skip ahead to a time just before the start time
        vm.warp(startTime - 1 * HOUR);
        
        // Create the market with fixed timestamps and trigger price
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket(
            startTime,
            startTimePlus30Min,
            triggerPrice
        );
        
        console.log("Market created with ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
        
        // Deployment command with fixed values
        string memory castCmd = string(abi.encodePacked(
            "cast send YOUR_CONTROLLER_ADDRESS \"createMarket(uint256,uint256,uint256)\" ",
            vm.toString(startTime), " ",
            vm.toString(startTimePlus30Min), " ",
            vm.toString(triggerPrice),
            " --private-key YOUR_PRIVATE_KEY --rpc-url YOUR_RPC_URL"
        ));
        console.log("Deployment command:");
        console.log(castCmd);
    }
} 