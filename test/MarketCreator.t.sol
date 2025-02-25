// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MarketCreator.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MarketCreatorTest is Test {
    MarketCreator public marketCreator;
    MockToken public asset;
    address public controller;
    address public user1;

    event MarketVaultsCreated(
        uint256 indexed marketId,
        address indexed riskVault,
        address indexed hedgeVault
    );

    function setUp() public {
        controller = address(1);
        user1 = address(2);
        asset = new MockToken();
        vm.label(controller, "Controller");
        vm.label(user1, "User1");
        
        marketCreator = new MarketCreator(controller, address(asset));
    }

    function testConstructor() public view {
        assertEq(marketCreator.controller(), controller, "Controller address mismatch");
        assertEq(address(marketCreator.asset()), address(asset), "Asset address mismatch");
    }

    function testConstructorZeroAddressChecks() public {
        vm.expectRevert("Invalid controller address");
        new MarketCreator(address(0), address(asset));

        vm.expectRevert("Invalid asset address");
        new MarketCreator(controller, address(0));
    }

    function testCreateMarketVaults() public {        
        (uint256 marketId, address riskVault, address hedgeVault) = marketCreator.createMarketVaults();
        
        assertEq(marketId, 1, "First market ID should be 1");
        assertTrue(riskVault != address(0), "Risk vault not deployed");
        assertTrue(hedgeVault != address(0), "Hedge vault not deployed");
        
        // Verify stored vaults
        (address storedRisk, address storedHedge) = marketCreator.getVaults(marketId);
        assertEq(storedRisk, riskVault, "Stored risk vault mismatch");
        assertEq(storedHedge, hedgeVault, "Stored hedge vault mismatch");
    }

    function testMultipleMarketCreation() public {
        (uint256 firstId, , ) = marketCreator.createMarketVaults();
        (uint256 secondId, , ) = marketCreator.createMarketVaults();
        (uint256 thirdId, , ) = marketCreator.createMarketVaults();
        
        assertEq(firstId, 1, "First ID should be 1");
        assertEq(secondId, 2, "Second ID should be 2");
        assertEq(thirdId, 3, "Third ID should be 3");
    }

    function testControllerLiquidate() public {
        // Create market and fund risk vault
        (uint256 marketId, address riskVault, address hedgeVault) = marketCreator.createMarketVaults();
        asset.transfer(riskVault, 1000);
        
        // Non-controller cannot liquidate
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.NotController.selector));
        marketCreator.controllerLiquidate(marketId);
        
        // Controller can liquidate
        vm.prank(controller);
        marketCreator.controllerLiquidate(marketId);
        
        assertEq(asset.balanceOf(riskVault), 0, "Risk vault should be empty");
        assertEq(asset.balanceOf(hedgeVault), 1000, "Hedge vault should have funds");
    }

    function testControllerMature() public {
        // Create market and fund hedge vault
        (uint256 marketId, address riskVault, address hedgeVault) = marketCreator.createMarketVaults();
        asset.transfer(hedgeVault, 1000);
        
        // Non-controller cannot mature
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.NotController.selector));
        marketCreator.controllerMature(marketId);
        
        // Controller can mature
        vm.prank(controller);
        marketCreator.controllerMature(marketId);
        
        assertEq(asset.balanceOf(hedgeVault), 0, "Hedge vault should be empty");
        assertEq(asset.balanceOf(riskVault), 1000, "Risk vault should have funds");
    }

    function testGetNonExistentVaults() public {
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.VaultsNotFound.selector));
        marketCreator.getVaults(999);
    }

    function testLiquidateNonExistentMarket() public {
        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.VaultsNotFound.selector));
        marketCreator.controllerLiquidate(999);
    }

    function testMatureNonExistentMarket() public {
        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(MarketCreator.VaultsNotFound.selector));
        marketCreator.controllerMature(999);
    }
}