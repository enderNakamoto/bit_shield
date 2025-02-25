// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Deploy.s.sol";

contract DeployTestnetScript is DeployScript {
    function run() external {
        console.log("Deploying Risk Hedge Protocol to testnet...");
        super.run();
        
        // Testnet-specific steps could be added here
        console.log("Testnet deployment completed!");
        console.log("Note: On testnet, you may need to get test tokens for the asset token.");
    }
} 