// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";

contract ManageMarketScript is Script {
    function run() external {
        // Get private key and addresses from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address controllerAddress = vm.envAddress("CONTROLLER_ADDRESS");
        uint256 marketId = vm.envUint("MARKET_ID");
        string memory action = vm.envString("ACTION"); // "start", "mature", or "liquidate"
        
        require(controllerAddress != address(0), "Controller address must be provided");
        require(marketId > 0, "Market ID must be provided");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the controller contract
        Controller controller = Controller(controllerAddress);
        
        if (keccak256(abi.encodePacked(action)) == keccak256(abi.encodePacked("start"))) {
            // Start the market (set to InProgress)
            controller.startMarket(marketId);
            console.log("Market %s status set to InProgress", marketId);
        } else if (keccak256(abi.encodePacked(action)) == keccak256(abi.encodePacked("mature"))) {
            // Mature the market
            controller.matureMarket(marketId);
            console.log("Market %s has been matured", marketId);
        } else if (keccak256(abi.encodePacked(action)) == keccak256(abi.encodePacked("liquidate"))) {
            // Liquidate the market
            controller.liquidateMarket(marketId);
            console.log("Market %s has been liquidated", marketId);
        } else {
            console.log("Invalid action specified. Use 'start', 'mature', or 'liquidate'");
        }
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Get the current market state
        Controller.MarketState state = controller.marketStates(marketId);
        console.log("Current market state: %s", uint8(state));
        console.log("0=Open, 1=InProgress, 2=Matured, 3=Liquidated");
    }
} 