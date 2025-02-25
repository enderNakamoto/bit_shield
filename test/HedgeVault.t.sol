// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vaults/HedgeVault.sol";
import "../src/vaults/RiskVault.sol";
import "./mocks/MockToken.sol";

contract HedgeVaultTest is Test {
    HedgeVault public vault;
    MockToken public token;
    address public controller;
    address public user1;
    address public user2;

    uint256 constant INITIAL_MINT = 1000000 * 10**18; // 1M tokens
    uint256 constant DEPOSIT_AMOUNT = 100 * 10**18;   // 100 tokens

    function setUp() public {
        controller = makeAddr("controller");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new MockToken();
        vault = new HedgeVault(IERC20(address(token)), controller, 1);

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
        RiskVault sisterVault = new RiskVault(
            IERC20(address(token)),
            controller,
            address(vault),
            1
        );
        vault.setSisterVault(address(sisterVault));

        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, user1);

        vm.prank(controller);
        vault.transferAssets(address(sisterVault), DEPOSIT_AMOUNT / 2);

        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT / 2, "Hedge vault should have half");
        assertEq(token.balanceOf(address(sisterVault)), DEPOSIT_AMOUNT / 2, "Sister vault should have half");
        assertEq(vault.balanceOf(user1), DEPOSIT_AMOUNT, "Share balance should not change after transfer");
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
}