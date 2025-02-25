// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";

contract ManageMarketScript is Script {
    enum Action {
        CREATE,
        START,
        MATURE,
        LIQUIDATE
    }

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddr = vm.envAddress("CONTROLLER");
        
        // Market creation parameters
        uint256 marketId = 0;
        uint256 eventStartTime = 0;
        uint256 eventEndTime = 0;
        uint256 marketTriggerPrice = 0;
        
        Action action;
        string memory actionStr = vm.envString("ACTION");
        
        if (keccak256(abi.encodePacked(actionStr)) == keccak256(abi.encodePacked("create"))) {
            action = Action.CREATE;
            eventStartTime = vm.envUint("EVENT_START_TIME");
            eventEndTime = vm.envUint("EVENT_END_TIME");
            marketTriggerPrice = vm.envOr("TRIGGER_PRICE", uint256(1000)); // Default to 1000 if not provided
            
            require(eventStartTime > block.timestamp, "Event start time must be in the future");
            require(eventEndTime > eventStartTime, "Event end time must be after start time");
            require(marketTriggerPrice > 0, "Trigger price must be greater than zero");
        } else {
            marketId = vm.envUint("MARKET_ID");
            require(marketId > 0, "Market ID must be provided");
            
            if (keccak256(abi.encodePacked(actionStr)) == keccak256(abi.encodePacked("start"))) {
                action = Action.START;
            } else if (keccak256(abi.encodePacked(actionStr)) == keccak256(abi.encodePacked("mature"))) {
                action = Action.MATURE;
            } else if (keccak256(abi.encodePacked(actionStr)) == keccak256(abi.encodePacked("liquidate"))) {
                action = Action.LIQUIDATE;
            } else {
                revert("Invalid action: must be 'create', 'start', 'mature', or 'liquidate'");
            }
        }
        
        // Start broadcast
        vm.startBroadcast(privateKey);
        
        if (action == Action.CREATE) {
            // Create a new market with specified timing parameters
            require(controllerAddr != address(0), "Controller address is required");
            Controller controller = Controller(controllerAddr);
            
            console.log("Creating a new market with:");
            console.log("- Event Start Time:", eventStartTime);
            console.log("- Event End Time:", eventEndTime);
            console.log("- Trigger Price:", marketTriggerPrice);
            
            (uint256 newMarketId, address riskVault, address hedgeVault) = controller.createMarket(
                eventStartTime,
                eventEndTime,
                marketTriggerPrice
            );
            
            console.log("Market created successfully!");
            console.log("- Market ID:", newMarketId);
            console.log("- Risk Vault:", riskVault);
            console.log("- Hedge Vault:", hedgeVault);
            
            // Get and log the market state
            Controller.MarketState state = controller.marketStates(newMarketId);
            console.log("- Current State:", uint256(state));
            
            // Get and log timing information
            (uint256 startTime, uint256 endTime) = controller.getMarketTiming(newMarketId);
            console.log("- Event Start Time:", startTime);
            console.log("- Event End Time:", endTime);
            console.log("- Trigger Price:", controller.getMarketTriggerPrice(newMarketId));
        } else {
            // Manage an existing market
            require(controllerAddr != address(0), "Controller address is required");
            Controller controller = Controller(controllerAddr);
            
            // Log the current state before operation
            Controller.MarketState stateBefore = controller.marketStates(marketId);
            console.log("Market ID:", marketId);
            console.log("Current State:", uint256(stateBefore));
            
            // Get and log timing information
            (uint256 startTime, uint256 endTime) = controller.getMarketTiming(marketId);
            console.log("Event Start Time:", startTime);
            console.log("Event End Time:", endTime);
            console.log("Trigger Price:", controller.getMarketTriggerPrice(marketId));
            console.log("Current Time:", block.timestamp);
            
            if (action == Action.START) {
                console.log("Starting market...");
                controller.startMarket(marketId);
            } else if (action == Action.MATURE) {
                console.log("Maturing market...");
                controller.matureMarket(marketId);
            } else if (action == Action.LIQUIDATE) {
                console.log("Liquidating market...");
                // Instead of calling liquidateMarket directly, use processOracleData with a price below the trigger
                uint256 storedTriggerPrice = controller.getMarketTriggerPrice(marketId);
                uint256 forceLiquidationPrice = storedTriggerPrice > 1 ? storedTriggerPrice - 1 : 0;
                console.log("Using price below trigger:", forceLiquidationPrice);
                controller.processOracleData(marketId, forceLiquidationPrice, block.timestamp);
            }
            
            // Log the updated state after operation
            Controller.MarketState stateAfter = controller.marketStates(marketId);
            console.log("New State:", uint256(stateAfter));
        }
        
        vm.stopBroadcast();
    }
} 