// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Deploy.s.sol";

contract DeployMainnetScript is DeployScript {
    function run() external {
        // Add additional safety checks for mainnet deployment
        console.log("MAINNET DEPLOYMENT STARTED - VERIFY ALL PARAMETERS CAREFULLY");
        
        // Check that an asset token address is provided for mainnet
        address assetToken = vm.envAddress("ASSET_TOKEN_ADDRESS");
        require(assetToken != address(0), "ERROR: Must provide a valid asset token address for mainnet deployment");
        
        // Run the base deployment script
        super.run();
        
        console.log("MAINNET DEPLOYMENT COMPLETED");
        console.log("IMPORTANT: Verify all contracts on Etherscan after deployment");
        console.log("IMPORTANT: Ensure proper ownership transfer for all contracts");
    }
} 