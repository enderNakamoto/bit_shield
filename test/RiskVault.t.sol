// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";

contract RiskVaultTest is Test {
    RiskVault public vault;
    MockToken public token;
    address public controller;
    address public user1;
    address public user2;
    address public hedgeVault;
    
    uint256 constant INITIAL_MINT = 1000000 * 10**18; // 1M tokens
    uint256 constant DEPOSIT_AMOUNT = 100 * 10**18;   // 100 tokens
    
    function setUp() public {
        controller = makeAddr("controller");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        hedgeVault = makeAddr("hedgeVault");
        
        token = new MockToken();
        vault = new RiskVault(IERC20(address(token)), controller, hedgeVault, 1);
        
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
        
        vm.prank(controller);
        vault.transferAssets(hedgeVault, DEPOSIT_AMOUNT / 2);
        
        assertEq(token.balanceOf(address(vault)), DEPOSIT_AMOUNT / 2);
        assertEq(token.balanceOf(hedgeVault), DEPOSIT_AMOUNT / 2);
    }

    function test_TransferToNonSisterReverts() public {
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, user1);
        
        address nonSister = makeAddr("nonSister");
        vm.prank(controller);
        vm.expectRevert("Can only transfer to sister vault");
        vault.transferAssets(nonSister, DEPOSIT_AMOUNT);
    }
}