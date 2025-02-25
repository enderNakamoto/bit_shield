// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Deploy.s.sol";

contract DeployMainnetScript is DeployScript {
    function run() override external {
        // Add additional safety checks for mainnet deployment
        console.log("MAINNET DEPLOYMENT STARTED - VERIFY ALL PARAMETERS CAREFULLY");
        
        // Check that an asset token address is provided for mainnet
        address assetToken = vm.envAddress("ASSET_TOKEN_ADDRESS");
        require(assetToken != address(0), "ERROR: Must provide a valid asset token address for mainnet deployment");
        
        // Run the deployment logic directly instead of using super.run()
        // Get private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Use the provided asset token
        console.log("Using existing asset token at:", assetToken);
        
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
        
        vm.stopBroadcast();
        
        // Output deployment information for verification
        console.log("Deployment completed!");
        console.log("Asset Token:", assetToken);
        console.log("MarketCreator:", marketCreatorAddress);
        console.log("Controller:", controllerAddress);
        console.log("IMPORTANT: You need to manually update the controller address in the MarketCreator contract.");
        
        console.log("MAINNET DEPLOYMENT COMPLETED");
        console.log("IMPORTANT: Verify all contracts on Etherscan after deployment");
        console.log("IMPORTANT: Ensure proper ownership transfer for all contracts");
    }
} 