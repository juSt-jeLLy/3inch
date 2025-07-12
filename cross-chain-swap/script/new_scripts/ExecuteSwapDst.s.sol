// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { Timelocks, TimelocksLib } from "../../contracts/libraries/TimelocksLib.sol";
import { EscrowDst } from "../../contracts/EscrowDst.sol";
import { IBaseEscrow } from "../../contracts/interfaces/IBaseEscrow.sol";
import { EscrowFactory } from "../../contracts/EscrowFactory.sol";

contract ExecuteSwapDst is Script {
    using TimelocksLib for Timelocks;

    event Debug(string name, uint256 value);

    // Monad addresses
    address constant MONAD_ESCROW_FACTORY = 0x919F799B949137e2b6AcE1fC5098b72EaDf7A453;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    function run() external {
        // Get the current block timestamp
        uint256 currentTime = block.timestamp;
        console.log("\n=== Current State ===");
        console.log("Current block time:", currentTime);

        // Create escrow immutables
        bytes32 orderHash = 0x89302931f6225e6e605f0aa3bd0d19dd55a437526813cc7f8237c1c30a07ab60;
        bytes32 secret = bytes32("secret");
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks with the exact values from deployment transaction
        uint256 deploymentTime = 0x68729cd1;  // Actual deployment timestamp from transaction
        uint256 withdrawal = 0x3c;  // 60 seconds for private withdrawal
        uint256 publicWithdrawal = 0x0e10;  // 3600 seconds (1 hour) for public withdrawal
        uint256 cancellation = 0x15180;  // 86400 seconds (24 hours) for cancellation

        // Pack timelocks into a uint256:
        // - Deployment time in highest 32 bits (224-255)
        // - DstWithdrawal in bits 192-223
        // - DstPublicWithdrawal in bits 160-191
        // - DstCancellation in bits 128-159
        uint256 timelockData = (deploymentTime << 224) | 
                              (withdrawal << 192) | 
                              (publicWithdrawal << 160) | 
                              (cancellation << 128);
        
        Timelocks timelocksDst = Timelocks.wrap(timelockData);

        // Create immutables struct with exact values from deployment
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });

        // Calculate escrow address
        address escrowDst = EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(immutables);
        console.log("\n=== Escrow Address ===");
        console.log("Calculated escrow address:", escrowDst);

        // Calculate actual timelock windows
        uint256 withdrawalStart = timelocksDst.get(TimelocksLib.Stage.DstWithdrawal);
        uint256 publicWithdrawalStart = timelocksDst.get(TimelocksLib.Stage.DstPublicWithdrawal);
        uint256 cancellationStart = timelocksDst.get(TimelocksLib.Stage.DstCancellation);
        
        console.log("\n=== Timelock Configuration ===");
        console.log("Deployment time (hex):", vm.toString(bytes32(deploymentTime)));
        console.log("Deployment time (dec):", deploymentTime);
        console.log("Private withdrawal period:", withdrawal, "seconds");
        console.log("Public withdrawal period:", publicWithdrawal, "seconds");
        console.log("Cancellation period:", cancellation, "seconds");
        
        console.log("\n=== Timelock Windows ===");
        console.log("Private Withdrawal:", withdrawalStart, "(deployment + 60s)");
        console.log("Public Withdrawal:", publicWithdrawalStart, "(deployment + 1h)");
        console.log("Cancellation:", cancellationStart, "(deployment + 24h)");
        
        console.log("\n=== Current Status ===");
        console.log("Time since deployment:", currentTime - deploymentTime, "seconds");
        
        if (currentTime < withdrawalStart) {
            console.log("Status: Too early for withdrawal");
            console.log("Need to wait:", withdrawalStart - currentTime, "more seconds");
        } else if (currentTime >= cancellationStart) {
            console.log("Status: Too late for withdrawal");
            console.log("Cancellation period started", currentTime - cancellationStart, "seconds ago");
        } else {
            console.log("Status: WITHDRAWAL WINDOW ACTIVE");
            if (currentTime >= publicWithdrawalStart) {
                console.log("Public withdrawal is also available");
            }
        }

        // Ensure we're in the withdrawal window
        require(currentTime >= withdrawalStart, "Too early for withdrawal");
        require(currentTime < cancellationStart, "Too late for withdrawal");

        console.log("\nExecuting withdrawal...");
        
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Execute withdraw using calculated address
        EscrowDst(escrowDst).withdraw(secret, immutables);

        vm.stopBroadcast();
        
        console.log("Withdrawal executed successfully!");
    }
}