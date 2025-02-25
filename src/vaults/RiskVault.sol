// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RiskVault is ERC4626 {
    address public immutable controller;
    address public sisterVault;
    uint256 public immutable betId;
    
    modifier onlyController() {
        require(msg.sender == controller, "Only controller can call this function");
        _;
    }
    
    constructor(
        IERC20 asset_,
        address controller_,
        address hedgeVault_,
        uint256 betId_
    ) ERC20(
        string.concat("Risk Vault ", Strings.toString(betId_)),
        string.concat("rVault", Strings.toString(betId_))
    ) ERC4626(asset_) {
        require(controller_ != address(0), "Invalid controller address");
        require(hedgeVault_ != address(0), "Invalid hedge vault address");
        controller = controller_;
        sisterVault = hedgeVault_;
        betId = betId_;
    }
    
    function transferAssets(address to, uint256 amount) external onlyController {
        require(to == sisterVault, "Can only transfer to sister vault");
        IERC20(asset()).transfer(to, amount);
    }
}
