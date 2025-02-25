// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MarketCreator.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";
import "./mocks/MockController.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MarketCreatorTest is Test {
    MarketCreator public marketCreator;
    MockToken public asset;
    MockController public controller;
    address public user1;

    // Constants for test timestamps
    uint256 public constant START_TIME = 1000000; // Base timestamp
    uint256 public constant EVENT_START_TIME = 2000000; // Future timestamp for event start
    uint256 public constant EVENT_END_TIME = 3000000; // Future timestamp for event end
    uint256 public constant DEFAULT_TRIGGER_PRICE = 20; // Default trigger price

    // Define event with all parameters
    event MarketVaultsCreated(
        uint256 indexed marketId,
        address indexed riskVault,
        address indexed hedgeVault,
        uint256 eventStartTime,
        uint256 eventEndTime
    );

    function setUp() public {
        // Set block timestamp to START_TIME for consistent testing
        vm.warp(START_TIME);
        
        user1 = address(2);
        asset = new MockToken();
        
        // Deploy the mock controller
        controller = new MockController();
        vm.label(address(controller), "Controller");
        vm.label(user1, "User1");
        
        marketCreator = new MarketCreator(address(controller), address(asset));
    }

    function testConstructor() public view {
        assertEq(marketCreator.controller(), address(controller), "Controller address mismatch");
        assertEq(address(marketCreator.asset()), address(asset), "Asset address mismatch");
    }

    function testConstructorZeroAddressChecks() public {
        vm.expectRevert("Invalid controller address");
        new MarketCreator(address(0), address(asset));

        vm.expectRevert("Invalid asset address");
        new MarketCreator(address(controller), address(0));
    }

    function testCreateMarketVaultsWithTriggerPrice() public {
        // Don't test events, just function behavior
        (uint256 marketId, address riskVault, address hedgeVault) = marketCreator.createMarketVaults(
            EVENT_START_TIME,
            EVENT_END_TIME,
            1000 // Trigger price
        );
        
        // Verify the function results
        assertEq(marketId, 1, "First market ID should be 1");
        assertNotEq(riskVault, address(0), "Risk vault should be created");
        assertNotEq(hedgeVault, address(0), "Hedge vault should be created");
        
        // Verify stored values
        (address storedRiskVault, address storedHedgeVault) = marketCreator.getVaults(marketId);
        assertEq(storedRiskVault, riskVault, "Risk vault address mismatch");
        assertEq(storedHedgeVault, hedgeVault, "Hedge vault address mismatch");
    }

    function testCreateMarketVaults() public {
        // Don't test events, just function behavior
        (uint256 marketId, address riskVault, address hedgeVault) = marketCreator.createMarketVaults(
            EVENT_START_TIME,
            EVENT_END_TIME,
            DEFAULT_TRIGGER_PRICE
        );
        
        // Verify the function results
        assertEq(marketId, 1, "First market ID should be 1");
        assertNotEq(riskVault, address(0), "Risk vault should be created");
        assertNotEq(hedgeVault, address(0), "Hedge vault should be created");
        
        // Verify stored values
        (address storedRiskVault, address storedHedgeVault) = marketCreator.getVaults(marketId);
        assertEq(storedRiskVault, riskVault, "Risk vault address mismatch");
        assertEq(storedHedgeVault, hedgeVault, "Hedge vault address mismatch");
    }

    function testMultipleMarketCreation() public {
        // Create first market
        (uint256 marketId1, , ) = marketCreator.createMarketVaults(
            EVENT_START_TIME, 
            EVENT_END_TIME, 
            DEFAULT_TRIGGER_PRICE
        );
        
        // Create second market
        (uint256 marketId2, , ) = marketCreator.createMarketVaults(
            EVENT_START_TIME, 
            EVENT_END_TIME, 
            DEFAULT_TRIGGER_PRICE
        );
        
        assertEq(marketId1, 1, "First market ID should be 1");
        assertEq(marketId2, 2, "Second market ID should be 2");
        
        // Verify we can get vaults for both markets
        (address riskVault1, address hedgeVault1) = marketCreator.getVaults(marketId1);
        (address riskVault2, address hedgeVault2) = marketCreator.getVaults(marketId2);
        
        assertNotEq(riskVault1, address(0), "Risk vault 1 should be created");
        assertNotEq(hedgeVault1, address(0), "Hedge vault 1 should be created");
        assertNotEq(riskVault2, address(0), "Risk vault 2 should be created");
        assertNotEq(hedgeVault2, address(0), "Hedge vault 2 should be created");
        
        // Ensure different vaults were created
        assertTrue(riskVault1 != riskVault2, "Risk vaults should be different");
        assertTrue(hedgeVault1 != hedgeVault2, "Hedge vaults should be different");
    }

    function testCreateMarketVaultsWithInvalidTimes() public {
        // Test start time in the past
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.InvalidTimeParameters.selector));
        marketCreator.createMarketVaults(START_TIME - 1, EVENT_END_TIME, DEFAULT_TRIGGER_PRICE);
        
        // Test end time before start time
        uint256 futureTime = block.timestamp + 1000;
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.InvalidTimeParameters.selector));
        marketCreator.createMarketVaults(futureTime, futureTime - 1, DEFAULT_TRIGGER_PRICE);
    }

    function testGetVaultsNonExistentMarket() public {
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.VaultsNotFound.selector));
        marketCreator.getVaults(999); // Non-existent market ID
    }
}