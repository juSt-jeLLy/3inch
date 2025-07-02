// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LimitOrderProtocol } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { IWETH } from "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";

contract DeployLimitOrderProtocol is Script {
    address public constant WETH = 0x4200000000000000000000000000000000000006; // Monad WETH

    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast();
        LimitOrderProtocol limitOrderProtocol = new LimitOrderProtocol(IWETH(WETH));
        vm.stopBroadcast();

        console.log("LimitOrderProtocol deployed at: ", address(limitOrderProtocol));
    }
} 