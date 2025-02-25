// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";
import "./mocks/MockController.sol";

contract RiskVaultTest is Test {
    RiskVault public vault;
    MockToken public token;
    MockController public controller;  // Use the MockController
    address public user1;
    address public user2;
    address public hedgeVault;
    
    uint256 constant INITIAL_MINT = 1000000 * 10**18; // 1M tokens
    uint256 constant DEPOSIT_AMOUNT = 100 * 10**18;   // 100 tokens
    
    function setUp() public {
        controller = new MockController();  // Use the mock controller
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        hedgeVault = makeAddr("hedgeVault");
        
        token = new MockToken();
        vault = new RiskVault(IERC20(address(token)), address(controller), hedgeVault, 1);
        
        token.transfer(user1, INITIAL_MINT / 2);
        token.transfer(user2, INITIAL_MINT / 2);
        
        vm.prank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        token.approve(address(vault), type(uint256).max);
    }

    function test_DepositAndWithdraw() public {
        vm.prank(user1);
        uint256 sharesReceived = vault.deposit(DEPOSIT_AMOUNT, user1);
        assertEq(sharesReceived, DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(user1), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT);

        vm.prank(user1);
        uint256 tokensWithdrawn = vault.withdraw(DEPOSIT_AMOUNT, user1, user1);
        assertEq(tokensWithdrawn, DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(user1), 0);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_TransferToHedge() public {
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, user1);
        
        vm.prank(address(controller));
        vault.transferAssets(hedgeVault, DEPOSIT_AMOUNT / 2);
        
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT / 2);
        assertEq(token.balanceOf(hedgeVault), DEPOSIT_AMOUNT / 2);
    }

    function test_TransferToNonSisterReverts() public {
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, user1);
        
        address nonSister = makeAddr("nonSister");
        vm.prank(address(controller));
        vm.expectRevert("Can only transfer to sister vault");
        vault.transferAssets(nonSister, DEPOSIT_AMOUNT);
    }
    
    // Add new tests for market states
    function test_DepositRevertsWhenInProgress() public {
        // First, make controller actually check market state
        vm.etch(
            address(controller),
            address(new StrictMockController()).code
        );
        
        // Set market state to InProgress
        StrictMockController(address(controller)).setMarketState(1, StrictMockController.MarketState.InProgress);
        
        // Expect revert when trying to deposit
        vm.prank(user1);
        vm.expectRevert("Deposit not allowed");
        vault.deposit(DEPOSIT_AMOUNT, user1);
    }
}

// A stricter controller that enforces market states
contract StrictMockController {
    enum MarketState {
        Open,
        InProgress,
        Matured,
        Liquidated
    }
    
    mapping(uint256 => MarketState) public marketStates;
    
    function setMarketState(uint256 marketId, MarketState state) external {
        marketStates[marketId] = state;
    }
    
    function checkDepositAllowed(uint256 marketId) external view {
        MarketState state = marketStates[marketId];
        require(
            state == MarketState.Open || 
            state == MarketState.Matured || 
            state == MarketState.Liquidated,
            "Deposit not allowed"
        );
    }
    
    function checkWithdrawAllowed(uint256 marketId) external view {
        MarketState state = marketStates[marketId];
        require(
            state == MarketState.Open || 
            state == MarketState.Matured || 
            state == MarketState.Liquidated,
            "Withdraw not allowed"
        );
    }
}