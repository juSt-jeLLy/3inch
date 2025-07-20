// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/mocks/ERC20True.sol";

contract DeployERC20True is Script {
    // Addresses and private keys
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    function run() external {
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Deploy ERC20True contract
        ERC20True token = new ERC20True();

        vm.stopBroadcast();

        // Print deployed address
        console.log("ERC20True deployed at:", address(token));
    }
} 