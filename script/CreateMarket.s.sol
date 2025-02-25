// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";

contract CreateMarketScript is Script {
    function run() external {
        // Get private key and addresses from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        
        require(controllerAddress != address(0), "Controller address must be provided");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the controller contract
        Controller controller = Controller(controllerAddress);
        
        // Create a new market through the controller
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket();
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Output results
        console.log("Market created successfully!");
        console.log("Market ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
    }
} 