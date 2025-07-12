// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/EscrowSrc.sol";
import "../../contracts/interfaces/IBaseEscrow.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "../../test/utils/libraries/CrossChainTestLib.sol";
import "../../test/utils/libraries/TimelocksSettersLib.sol";
import "../../contracts/libraries/TimelocksLib.sol";

contract ExecuteSwapSrc is Script {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    // Sepolia addresses - our deployed escrow
    address constant ESCROW_SRC = 0x7E1b2371a2436b6a254f63FbFd42C5F747bE15F3;  // Updated to our new deployed address

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() external {
        // Set timelocks with exact values from deployment
        uint256 deploymentTime = block.timestamp - 90;  // Set deployment time 90 seconds ago
        uint256 withdrawal = 60;  // 1 minute for private withdrawal
        uint256 publicWithdrawal = 3600;  // 1 hour for public withdrawal
        uint256 cancellation = 86400;  // 24 hours for cancellation
        uint256 publicCancellation = 172800;  // 48 hours for public cancellation

        // Pack timelocks into a uint256
        uint256 timelockData = (deploymentTime << 224) | 
                              (withdrawal << 192) | 
                              (publicWithdrawal << 160) | 
                              (cancellation << 128) |
                              (publicCancellation << 96);
        
        Timelocks timelocksSrc = Timelocks.wrap(timelockData);

        // Create escrow immutables
        bytes32 orderHash = 0x89302931f6225e6e605f0aa3bd0d19dd55a437526813cc7f8237c1c30a07ab60;
        bytes32 secret = bytes32("secret");
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: hashlock,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksSrc
        });

        // Debug timelocks and timing
        console.log("\n=== Timelock Debug Information ===");
        console.log("Deployment time:", deploymentTime);
        console.log("Current block time:", block.timestamp);
        
        uint256 withdrawalStart = timelocksSrc.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 publicWithdrawalStart = timelocksSrc.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        uint256 cancellationStart = timelocksSrc.get(TimelocksLib.Stage.SrcCancellation);
        uint256 publicCancellationStart = timelocksSrc.get(TimelocksLib.Stage.SrcPublicCancellation);
        
        console.log("\nTimelock Windows:");
        console.log("Private Withdrawal starts at:", withdrawalStart);
        console.log("Public Withdrawal starts at:", publicWithdrawalStart);
        console.log("Private Cancellation starts at:", cancellationStart);
        console.log("Public Cancellation starts at:", publicCancellationStart);
        
        console.log("\nTime until windows:");
        if (block.timestamp < withdrawalStart) {
            console.log("Time until private withdrawal:", withdrawalStart - block.timestamp, "seconds");
        } else {
            console.log("Private withdrawal window is active");
        }
        
        if (block.timestamp < publicWithdrawalStart) {
            console.log("Time until public withdrawal:", publicWithdrawalStart - block.timestamp, "seconds");
        } else {
            console.log("Public withdrawal window is active");
        }
        
        if (block.timestamp < cancellationStart) {
            console.log("Time until private cancellation:", cancellationStart - block.timestamp, "seconds");
        } else {
            console.log("Private cancellation window is active");
        }

        // Ensure we're in the withdrawal window
        require(block.timestamp >= withdrawalStart, "Too early for withdrawal");
        require(block.timestamp < cancellationStart, "Too late for withdrawal");

        console.log("\nExecuting withdrawal...");
        
        vm.startBroadcast(MAKER_PRIVATE_KEY);

        // Execute withdraw on source escrow with the secret
        EscrowSrc(payable(ESCROW_SRC)).withdraw(secret, immutables);

        vm.stopBroadcast();

        console.log("Withdrawal executed successfully!");
        console.log("Secret used:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));
    }
} 