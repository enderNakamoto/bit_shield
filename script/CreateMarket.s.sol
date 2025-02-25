// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";

contract CreateMarketScript is Script {
    function run() external {
        // Get private key and addresses from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketCreatorAddress = vm.envAddress("MARKET_CREATOR_ADDRESS");
        
        require(marketCreatorAddress != address(0), "Market Creator address must be provided");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the market creator contract
        MarketCreator marketCreator = MarketCreator(marketCreatorAddress);
        
        // Create a new market
        (uint256 marketId, address riskVault, address hedgeVault) = marketCreator.createMarketVaults();
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Output results
        console.log("Market created successfully!");
        console.log("Market ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
    }
} 