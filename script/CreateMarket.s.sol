// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";

contract CreateMarketScript is Script {
    // Constants for time intervals
    uint256 constant HOUR = 3600; // seconds in an hour
    uint256 constant MINUTE = 60; // seconds in a minute
    
    function run() external {
        // Get private key and addresses from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        
        require(controllerAddress != address(0), "Controller address must be provided");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the controller contract
        Controller controller = Controller(controllerAddress);
        
        // Current time
        uint256 currentTime = block.timestamp;
        
        // Set concrete Unix timestamps - can be overridden with environment variables
        // Default: start time = 2 hours from now, end time = 2 hours and 30 minutes from now
        uint256 startTime = vm.envOr("START_TIME", currentTime + 2 * HOUR);
        uint256 endTime = vm.envOr("END_TIME", currentTime + 2 * HOUR + 30 * MINUTE);
        uint256 triggerPrice = vm.envOr("TRIGGER_PRICE", uint256(20));
        
        console.log("Creating market with parameters:");
        console.log("- Current time:", currentTime, "(unix timestamp)");
        console.log("- Start time:", startTime, "(unix timestamp)");
        console.log("- End time:", endTime, "(unix timestamp)");
        console.log("- Trigger price:", triggerPrice);
        
        // Create a new market through the controller with all required parameters
        (uint256 marketId, address riskVault, address hedgeVault) = controller.createMarket(
            startTime,
            endTime,
            triggerPrice
        );
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Output results
        console.log("Market created successfully!");
        console.log("Market ID:", marketId);
        console.log("Risk Vault:", riskVault);
        console.log("Hedge Vault:", hedgeVault);
        
        // Print human-readable time information
        console.log("Time until market start:", startTime - currentTime, "seconds");
        console.log("Market duration:", endTime - startTime, "seconds");
    }
} 