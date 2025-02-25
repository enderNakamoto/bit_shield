// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";

// Add a helper contract to modify the RiskVault
contract RiskVaultHelper {
    // Helper function to set the controller
    function setControllerAsOwner(RiskVault riskVault, address controller) external {
        // No ownership transfer in RiskVault, but we need to register the controller in tests
        // Instead, ensure we always deploy with the right controller
    }
}

contract ControllerTest is Test {
    MarketCreator public marketCreator;
    Controller public controller;
    MockToken public asset;
    address public user1;
    RiskVaultHelper public riskVaultHelper;
    
    // Test timestamps - make sure EVENT_START_TIME is sufficiently in the future
    uint256 public constant START_TIME = 1000000; // Block time at test start
    uint256 public constant EVENT_START_TIME = 2000000; // Much higher than START_TIME
    uint256 public constant EVENT_END_TIME = 3000000; // Much higher than EVENT_START_TIME
    
    /**
     * Helper function to debug market creation issues
     */
    function debugMarketCreation(uint256 marketId) internal view {
        console.log("-------- Market Debug --------");
        console.log("Block timestamp:", block.timestamp);
        
        try controller.marketStates(marketId) returns (Controller.MarketState state) {
            console.log("Market state:", uint(state));
        } catch {
            console.log("Failed to get market state");
        }
        
        try controller.getMarketTiming(marketId) returns (uint256 startTime, uint256 endTime) {
            console.log("Event start time:", startTime);
            console.log("Event end time:", endTime);
            console.log("Current time vs start time:", block.timestamp < startTime ? "before start" : "after start");
            console.log("Current time vs end time:", block.timestamp < endTime ? "before end" : "after end");
        } catch {
            console.log("Failed to get market timing");
        }
        
        try marketCreator.getVaults(marketId) returns (address riskVault, address hedgeVault) {
            console.log("Risk vault:", riskVault);
            console.log("Hedge vault:", hedgeVault);
        } catch {
            console.log("Failed to get market vaults");
        }
        
        console.log("-------- End Debug --------");
    }

    function setUp() public {
        console.log("Setting up test at timestamp:", block.timestamp);
        vm.warp(START_TIME); // Set a specific start time for tests
        console.log("After warp, timestamp is:", block.timestamp);
        
        user1 = address(2);
        asset = new MockToken();
        riskVaultHelper = new RiskVaultHelper();
        
        console.log("Deploying Controller...");
        // First, deploy the Controller
        controller = new Controller(address(this));
        
        console.log("Deploying MarketCreator...");
        // Then, deploy the MarketCreator with this test contract as the controller
        // This is important for testing so that this test contract can register vaults
        marketCreator = new MarketCreator(address(this), address(asset));
        
        // For debugging, let's print the current time
        console.log("Test setup complete at timestamp:", block.timestamp);
        console.log("Event start time:", EVENT_START_TIME);
        console.log("Event end time:", EVENT_END_TIME);
    }
    
    function testConstructorZeroAddressCheck() public {
        vm.expectRevert("Invalid market creator address");
        new Controller(address(0));
    }

    function testMarketCreation() public {
        console.log("--- testMarketCreation ---");
        console.log("Current block time:", block.timestamp);
        console.log("EVENT_START_TIME:", EVENT_START_TIME);
        console.log("EVENT_END_TIME:", EVENT_END_TIME);
        
        // Create a test market with our helper function
        (uint256 marketId, , ) = createTestMarketWithTimings();
        
        // Debug the created market
        debugMarketCreation(marketId);
        
        // Verify the market was created correctly
        Controller.MarketState state = controller.marketStates(marketId);
        assertEq(uint(state), uint(Controller.MarketState.Open), "Market should be in Open state");
        
        (uint256 startTime, uint256 endTime) = controller.getMarketTiming(marketId);
        assertEq(startTime, EVENT_START_TIME, "Start time should match EVENT_START_TIME");
        assertEq(endTime, EVENT_END_TIME, "End time should match EVENT_END_TIME");
    }

    function testLiquidatedMarketCannotBeMatured() public {
        console.log("--- testLiquidatedMarketCannotBeMatured ---");
        
        // Create a fixed marketId for testing
        uint256 marketId = 999;
        
        // Set the market state directly to Liquidated using the setMarketState function
        controller.setMarketState(marketId, Controller.MarketState.Liquidated);
        
        // Verify the market is in Liquidated state
        Controller.MarketState state = controller.marketStates(marketId);
        console.log("Market state:", uint(state));
        assertEq(uint(state), uint(Controller.MarketState.Liquidated), "Market should be in Liquidated state");
        
        // Try to mature the market - should fail with MarketAlreadyLiquidated
        vm.expectRevert(abi.encodeWithSelector(Controller.MarketAlreadyLiquidated.selector, marketId));
        controller.matureMarket(marketId);
    }

    // Helper function to create vaults for a specific market ID
    function createVaultsForMarket(uint256 marketId) internal returns (address riskVault, address hedgeVault) {
        console.log("Creating vaults for market ID:", marketId);
        
        // Deploy Hedge vault with controller as the controller
        HedgeVault hedge = new HedgeVault(
            asset,
            address(controller), // Use controller directly
            marketId
        );
        hedgeVault = address(hedge);
        console.log("Deployed Hedge vault at:", hedgeVault);
        
        // Deploy Risk vault with controller as the controller
        RiskVault risk = new RiskVault(
            asset,
            address(controller), // Use controller directly
            hedgeVault,
            marketId
        );
        riskVault = address(risk);
        console.log("Deployed Risk vault at:", riskVault);
        
        // Set sister vault - this requires ownership
        console.log("Setting sister vault...");
        vm.startPrank(address(this)); // Ensure we're the owner
        hedge.setSisterVault(riskVault);
        vm.stopPrank();
        
        // Register the vaults with the market creator
        // This test is the controller for marketCreator, so we can call this directly
        console.log("Registering vaults with market creator...");
        marketCreator.registerVaults(marketId, riskVault, hedgeVault);
        
        return (riskVault, hedgeVault);
    }
    
    // Helper function to create a test market with explicit timing
    function createTestMarketWithTimings() internal returns (uint256 marketId, address riskVault, address hedgeVault) {
        console.log("Creating test market with timing parameters...");
        console.log("Current time:", block.timestamp);
        console.log("EVENT_START_TIME:", EVENT_START_TIME);
        console.log("EVENT_END_TIME:", EVENT_END_TIME);
        
        // Create a fixed marketId for testing
        marketId = 1; // Fixed ID for testing
        console.log("Using market ID:", marketId);
        
        // Create vaults for the market
        (riskVault, hedgeVault) = createVaultsForMarket(marketId);
        
        // Directly call the controller to create the market with timing parameters
        console.log("Calling controller.marketCreated...");
        controller.marketCreated(marketId, EVENT_START_TIME, EVENT_END_TIME);
        console.log("Market created successfully.");
        
        return (marketId, riskVault, hedgeVault);
    }
} 