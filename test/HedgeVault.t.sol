// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vaults/HedgeVault.sol";
import "../src/vaults/RiskVault.sol";
import "./mocks/MockToken.sol";
import "./mocks/MockController.sol";

contract HedgeVaultTest is Test {
    HedgeVault public vault;
    MockToken public token;
    MockController public controller;
    address public user1;
    address public user2;

    uint256 constant INITIAL_MINT = 1000000 * 10**18; // 1M tokens
    uint256 constant DEPOSIT_AMOUNT = 100 * 10**18;   // 100 tokens

    function setUp() public {
        controller = new MockController();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new MockToken();
        vault = new HedgeVault(IERC20(address(token)), address(controller), 1);

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
        assertEq(sharesReceived, DEPOSIT_AMOUNT, "First deposit should mint equal shares");
        assertEq(vault.balanceOf(user1), DEPOSIT_AMOUNT, "User should receive correct shares");
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT, "Vault should receive tokens");

        vm.prank(user1);
        uint256 tokensWithdrawn = vault.withdraw(DEPOSIT_AMOUNT, user1, user1);
        assertEq(tokensWithdrawn, DEPOSIT_AMOUNT, "Should withdraw all tokens");
        assertEq(vault.balanceOf(user1), 0, "Should burn all shares");
        assertEq(token.balanceOf(address(vault)), 0, "Vault should be empty");
    }

    function test_MultipleDepositsAndShares() public {
        vm.prank(user1);
        uint256 shares1 = vault.deposit(DEPOSIT_AMOUNT, user1);

        vm.prank(user2);
        uint256 shares2 = vault.deposit(DEPOSIT_AMOUNT, user2);

        assertEq(shares1, shares2, "Equal deposits should get equal shares");
        assertEq(vault.totalSupply(), DEPOSIT_AMOUNT * 2, "Total shares should be sum of deposits");
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT * 2, "Vault should hold all tokens");

        vm.prank(user1);
        vault.withdraw(shares1 / 2, user1, user1);
        vm.prank(user2);
        vault.withdraw(shares2 / 2, user2, user2);

        assertEq(vault.totalSupply(), DEPOSIT_AMOUNT, "Should have half shares remaining");
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT, "Should have half tokens remaining");
    }

    function test_TransferToSisterVault() public {
        // Create a sister vault
        address sisterVault = address(new RiskVault(
            IERC20(address(token)),
            address(controller),
            address(vault),
            1
        ));
        
        // We need to be the actual owner of the vault to set the sister vault
        // The owner is set to msg.sender in the constructor
        // We need to create a new vault where this test contract is the owner
        
        // Create a new vault owned by this test contract
        HedgeVault ownedVault = new HedgeVault(
            IERC20(address(token)),
            address(controller),
            1
        );
        
        // Now we can set the sister vault directly
        ownedVault.setSisterVault(sisterVault);
        
        // Continue with the deposit test using the ownedVault
        vm.prank(user1);
        token.approve(address(ownedVault), type(uint256).max);
        
        vm.prank(user1);
        ownedVault.deposit(DEPOSIT_AMOUNT, user1);

        vm.prank(address(controller));
        ownedVault.transferAssets(sisterVault, DEPOSIT_AMOUNT / 2);

        assertEq(token.balanceOf(address(ownedVault)), DEPOSIT_AMOUNT / 2, "Hedge vault should have half");
        assertEq(token.balanceOf(sisterVault), DEPOSIT_AMOUNT / 2, "Sister vault should have half");
        assertEq(ownedVault.balanceOf(user1), DEPOSIT_AMOUNT, "Share balance should not change after transfer");
    }

    function test_DepositWithdrawRoundTrip() public {
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, user1);

        vm.prank(user2);
        uint256 largerShares = vault.deposit(DEPOSIT_AMOUNT * 2, user2);
        assertEq(largerShares, DEPOSIT_AMOUNT * 2, "Should get proportional shares");

        vm.startPrank(user1);
        uint256 assets = vault.withdraw(DEPOSIT_AMOUNT, user1, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 assets2 = vault.withdraw(largerShares, user2, user2);
        vm.stopPrank();

        assertEq(assets, DEPOSIT_AMOUNT, "First user should get initial deposit back");
        assertEq(assets2, DEPOSIT_AMOUNT * 2, "Second user should get double deposit back");
        assertEq(vault.totalSupply(), 0, "Vault should have no shares");
        assertEq(token.balanceOf(address(vault)), 0, "Vault should have no tokens");
    }
    
    // Test market state transitions
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
    
    function test_WithdrawRevertsWhenInProgress() public {
        // First, set up a deposit while market is Open
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, user1);
        
        // Now make controller actually check market state
        vm.etch(
            address(controller),
            address(new StrictMockController()).code
        );
        
        // Set market state to InProgress
        StrictMockController(address(controller)).setMarketState(1, StrictMockController.MarketState.InProgress);
        
        // Expect revert when trying to withdraw
        vm.prank(user1);
        vm.expectRevert("Withdraw not allowed");
        vault.withdraw(DEPOSIT_AMOUNT, user1, user1);
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