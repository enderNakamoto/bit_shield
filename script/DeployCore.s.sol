// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";

contract DeployCoreScript is Script {
    function run() virtual external {
        // Get deployment parameters
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address assetToken = vm.envAddress("ASSET_TOKEN_ADDRESS");
        
        require(assetToken != address(0), "Asset token address must be provided");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the Controller (no parameters needed now)
        Controller controller = new Controller();
        address controllerAddress = address(controller);
        console.log("Deployed Controller at:", controllerAddress);
        
        // Deploy MarketCreator
        MarketCreator marketCreator = new MarketCreator(
            controllerAddress,
            assetToken
        );
        address marketCreatorAddress = address(marketCreator);
        console.log("Deployed MarketCreator at:", marketCreatorAddress);
        
        // Set the MarketCreator in the Controller
        controller.setMarketCreator(marketCreatorAddress);
        console.log("Set MarketCreator in Controller");
        
        vm.stopBroadcast();
        
        // Output deployment information
        console.log("Core Deployment completed!");
        console.log("Asset Token:", assetToken);
        console.log("Controller:", controllerAddress);
        console.log("MarketCreator:", marketCreatorAddress);
    }
} 