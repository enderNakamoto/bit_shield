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
        
        // First deploy the interim controller
        Controller interimController = new Controller(address(0)); // Temporary value
        address interimControllerAddress = address(interimController);
        
        // Then deploy MarketCreator with interim controller
        MarketCreator marketCreator = new MarketCreator(
            interimControllerAddress, 
            assetToken
        );
        address marketCreatorAddress = address(marketCreator);
        console.log("Deployed MarketCreator at:", marketCreatorAddress);
        
        // Finally deploy the real Controller with MarketCreator address
        Controller controller = new Controller(marketCreatorAddress);
        address controllerAddress = address(controller);
        console.log("Deployed Controller at:", controllerAddress);
        
        // Important: Set up markets if needed, but this must be done through 
        // a separate process after updating the controller address in MarketCreator
        
        vm.stopBroadcast();
        
        // Output deployment information for verification
        console.log("Deployment completed!");
        console.log("Asset Token:", assetToken);
        console.log("MarketCreator:", marketCreatorAddress);
        console.log("Controller:", controllerAddress);
        console.log("IMPORTANT: You need to manually update the controller address in the MarketCreator contract.");
    }
} 