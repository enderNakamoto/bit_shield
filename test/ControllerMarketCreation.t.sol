// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";

/**
 * This test specifically focuses on testing market creation through the Controller
 * to diagnose deployment issues
 */
contract ControllerMarketCreationTest is Test {
    Controller public controller;
    MarketCreator public marketCreator;
    MockToken public asset;
    address public deployer;
    
    // Test timestamps
    uint256 public constant START_TIME = 1000000; // Block time at test start
    uint256 public constant EVENT_START_TIME = 2000000; // Future event start time
    uint256 public constant EVENT_END_TIME = 3000000; // Future event end time

    function setUp() public {
        // Set up test environment
        vm.warp(START_TIME);
        deployer = address(this);
        
        // Deploy mock token for testing
        asset = new MockToken();
        console.log("Deployed mock token at:", address(asset));
        
        // Deploy contracts in the same order as real deployment
        controller = new Controller();
        console.log("Deployed Controller at:", address(controller));
        
        marketCreator = new MarketCreator(address(controller), address(asset));
        console.log("Deployed MarketCreator at:", address(marketCreator));
        
        // Set MarketCreator in Controller - CRITICAL STEP
        controller.setMarketCreator(address(marketCreator));
        console.log("Set MarketCreator in Controller");
        
        // Verify setup
        address storedCreator = address(controller.marketCreator());
        console.log("Controller's stored MarketCreator:", storedCreator);
        require(storedCreator == address(marketCreator), "MarketCreator not set correctly");
    }

    function testCreateMarketDefault() public {
        console.log("Testing default market creation...");
        
        // Call createMarket with no parameters
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket();
        
        // Verify results
        console.log("Created market with ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
        
        // Verify market state
        Controller.MarketState state = controller.marketStates(marketId);
        assertEq(uint(state), uint(Controller.MarketState.Open), "Market should be in Open state");
        
        // Verify vaults from controller match
        (address storedRisk, address storedHedge) = controller.getMarketVaults(marketId);
        assertEq(storedRisk, riskVault, "Risk vault mismatch");
        assertEq(storedHedge, hedgeVault, "Hedge vault mismatch");
    }
    
    function testCreateMarketWithTimings() public {
        console.log("Testing market creation with custom timings...");
        
        // Calculate future timestamps (relative to current block time)
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 1 days;
        
        console.log("Using start time:", startTime);
        console.log("Using end time:", endTime);
        
        // Call createMarket with timing parameters
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket(
            startTime,
            endTime
        );
        
        // Verify results
        console.log("Created market with ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
        
        // Verify market timing details
        (uint256 storedStart, uint256 storedEnd) = controller.getMarketTiming(marketId);
        assertEq(storedStart, startTime, "Start time mismatch");
        assertEq(storedEnd, endTime, "End time mismatch");
    }
    
    function testCreateMarketWithTimingsAndTrigger() public {
        console.log("Testing market creation with custom timings and trigger price...");
        
        // Calculate future timestamps (relative to current block time)
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 1 days;
        uint256 triggerPrice = 500; // Custom trigger price
        
        console.log("Using start time:", startTime);
        console.log("Using end time:", endTime);
        console.log("Using trigger price:", triggerPrice);
        
        // Call createMarket with all parameters
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket(
            startTime,
            endTime,
            triggerPrice
        );
        
        // Verify results
        console.log("Created market with ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
        
        // Verify market trigger price
        uint256 storedTrigger = controller.getMarketTriggerPrice(marketId);
        assertEq(storedTrigger, triggerPrice, "Trigger price mismatch");
    }
    
    function testMarketCreationDepositWithdraw() public {
        // Create a market
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket();
        
        // Fund user with tokens
        address user = address(0x1234);
        asset.transfer(user, 1000 ether);
        
        // Approve and deposit as user
        vm.startPrank(user);
        asset.approve(riskVault, 10 ether);
        RiskVault(riskVault).deposit(10 ether, user);
        vm.stopPrank();
        
        // Verify deposit
        uint256 balance = RiskVault(riskVault).balanceOf(user);
        assertEq(balance, 10 ether, "User should have 10 ether in shares");
        
        // Try full cycle with withdrawal
        vm.startPrank(user);
        RiskVault(riskVault).withdraw(5 ether, user, user);
        vm.stopPrank();
        
        // Verify withdrawal
        balance = RiskVault(riskVault).balanceOf(user);
        assertEq(balance, 5 ether, "User should have 5 ether in shares left");
    }
} 