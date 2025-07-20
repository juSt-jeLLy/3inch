// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/EscrowFactory.sol";
import "../../contracts/EscrowDst.sol";
import "../../contracts/interfaces/IBaseEscrow.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "../../test/utils/libraries/CrossChainTestLib.sol";
import "../../test/utils/libraries/TimelocksSettersLib.sol";
import "../../contracts/libraries/TimelocksLib.sol";

contract DeployEscrowDst is Script {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    // Monad addresses
    address constant MONAD_ESCROW_FACTORY = 0x919F799B949137e2b6AcE1fC5098b72EaDf7a453;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x550895b96dd1f2f9465b05a36bb5d7af052b02ff1b3172563a25671590d96818;
    bytes32 constant HASHLOCK = 0x65462b0520ef7d3df61b9992ed3bea0c56ead753be7c8b3614e0ce01e4cac41b;

    function run() external {
        // Set timelocks
        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 3600, // 1 hour
            cancellation: 82800, // 23 hours
            publicCancellation: 86400 // 24 hours
        });

        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 3600, // 1 hour
            cancellation: 39600 // 11 hours
        });

        (, Timelocks timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        // Create escrow immutables
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks relative to current block timestamp
        timelocksDst = timelocksDst.setDeployedAt(block.timestamp);

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });

        // Calculate source chain cancellation timestamp (must be greater than destination cancellation)
        uint256 srcCancellationTimestamp = block.timestamp + 86400; // 24 hours (same as source publicCancellation)

        // Log deployment details
        console.log("\n=== Deployment Details ===");
        console.log("Current timestamp:", block.timestamp);
        console.log("Withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("Public withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstPublicWithdrawal));
        console.log("Cancellation timelock:", timelocksDst.get(TimelocksLib.Stage.DstCancellation));
        console.log("Source cancellation timestamp:", srcCancellationTimestamp);

        // Log escrow details
        console.log("\n=== Escrow Details ===");
        console.log("Order hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Amount:", amount);
        console.log("Safety deposit:", safetyDeposit);
        console.log("Total value:", amount + safetyDeposit);
        
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Create and fund destination escrow using factory
        EscrowFactory(MONAD_ESCROW_FACTORY).createDstEscrow{value: amount + safetyDeposit}(immutables, srcCancellationTimestamp);

        vm.stopBroadcast();

        console.log("\n=== Success ===");
        console.log("Destination escrow created and funded");
    }
} 