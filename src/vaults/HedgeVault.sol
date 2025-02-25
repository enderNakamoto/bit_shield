// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract HedgeVault is ERC4626 {
    address public immutable controller;
    address public sisterVault;
    uint256 public immutable marketId;
    address public owner;
    
    modifier onlyController() {
        require(msg.sender == controller, "Only controller can call this function");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(
        IERC20 asset_,
        address controller_,
        uint256 marketId_
    ) ERC20(
        string.concat("Hedge Vault ", Strings.toString(marketId_)),
        string.concat("hVault", Strings.toString(marketId_))
    ) ERC4626(asset_) {
        require(controller_ != address(0), "Invalid controller address");
        controller = controller_;
        marketId = marketId_;
        owner = msg.sender;
    }

    function setSisterVault(address riskVault_) external onlyOwner {
        require(sisterVault == address(0), "Sister vault already set");
        require(riskVault_ != address(0), "Invalid sister vault address");
        sisterVault = riskVault_;
    }
    
    function transferAssets(address to, uint256 amount) external {
        require(to == sisterVault, "Can only transfer to sister vault");
        IERC20(asset()).transfer(to, amount);
    }
}