// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { console } from "forge-std/console.sol";

contract DeployAccessToken is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast();
        TokenMock accessToken = new TokenMock("1inch Access Token", "1ACCESS");
        vm.stopBroadcast();

        console.log("AccessToken deployed at: ", address(accessToken));
    }
} 