// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketCreator.sol";
import "../src/Controller.sol";
import "../test/mocks/MockToken.sol"; // Only for testing, use real asset on production

contract DeployScript is Script {
    function run() virtual external {
        // Get private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address assetToken = vm.envAddress("ASSET_TOKEN_ADDRESS");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // If no asset token address is provided, deploy a mock token (for testing only)
        if (assetToken == address(0)) {
            MockToken mockToken = new MockToken();
            assetToken = address(mockToken);
            console.log("Deployed MockToken at:", assetToken);
        } else {
            console.log("Using existing asset token at:", assetToken);
        }
        
        // Deploy the Controller (no parameters needed now)
        Controller controller = new Controller();
        address controllerAddress = address(controller);
        console.log("Deployed Controller at:", controllerAddress);
        
        // Then deploy MarketCreator with controller address
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
        
        // Output deployment information for verification
        console.log("Deployment completed!");
        console.log("Asset Token:", assetToken);
        console.log("Controller:", controllerAddress);
        console.log("MarketCreator:", marketCreatorAddress);
    }
} 