// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../../contracts/EscrowFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEscrowFactorySepolia is Script {
    uint32 public constant RESCUE_DELAY = 691200; // 8 days
    
    address public constant LOP = 0x111111125421cA6dc452d289314280a0f8842A65; // Sepolia Limit Order Protocol
    address public constant ACCESS_TOKEN = 0xACCe550000159e70908C0499a1119D04e7039C28; // All chains
    address public constant DAI = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21; // Sepolia DAI

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;

    function run() external {
        vm.startBroadcast(MAKER_PRIVATE_KEY);

        EscrowFactory escrowFactory = new EscrowFactory(
            LOP,
            IERC20(DAI),
            IERC20(ACCESS_TOKEN),
            MAKER, // feeBankOwner
            RESCUE_DELAY,
            RESCUE_DELAY
        );

        vm.stopBroadcast();

        console.log("EscrowFactory deployed at:", address(escrowFactory));
    }
} 