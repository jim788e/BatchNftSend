// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/BatchNftSend.sol";

contract DeployBatchNftSend is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BatchNftSend batchNftSend = new BatchNftSend(0.1 ether);

        console.log("BatchNftSend deployed at:", address(batchNftSend));

        vm.stopBroadcast();
    }
}

