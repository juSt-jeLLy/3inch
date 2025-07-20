// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/EscrowFactory.sol";
import "../../contracts/interfaces/IBaseEscrow.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "../../test/utils/libraries/CrossChainTestLib.sol";
import "../../test/utils/libraries/TimelocksSettersLib.sol";
import "../../contracts/libraries/TimelocksLib.sol";

contract CalculateEscrowAddresses is Script {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_ESCROW_FACTORY = 0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613;
    address constant MONAD_ESCROW_FACTORY = 0x919F799B949137e2b6AcE1fC5098b72EaDf7a453;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    // Order details from previous step (SignOrder.s.sol output)
    bytes32 constant ORDER_HASH = 0x550895b96dd1f2f9465b05a36bb5d7af052b02ff1b3172563a25671590d96818;
    bytes32 constant HASHLOCK = 0x65462b0520ef7d3df61b9992ed3bea0c56ead753be7c8b3614e0ce01e4cac41b;

    // Timelock durations
    uint256 constant PRIVATE_WITHDRAWAL = 60; // 1 minute
    uint256 constant PUBLIC_WITHDRAWAL = 3600; // 1 hour
    uint256 constant SRC_PRIVATE_CANCELLATION = 82800; // 23 hours
    uint256 constant SRC_PUBLIC_CANCELLATION = 86400; // 24 hours
    uint256 constant DST_CANCELLATION = 39600; // 11 hours

    function getTimelocks() internal view returns (Timelocks srcTimelocks, Timelocks dstTimelocks) {
        uint256 deploymentTime = block.timestamp;

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (PRIVATE_WITHDRAWAL << 192) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL) << 160) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + SRC_PRIVATE_CANCELLATION) << 128) |
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + SRC_PRIVATE_CANCELLATION + SRC_PUBLIC_CANCELLATION) << 96);
        
        srcTimelocks = Timelocks.wrap(srcTimelockData);

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (PRIVATE_WITHDRAWAL << 192) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL) << 160) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + DST_CANCELLATION) << 128);
        
        dstTimelocks = Timelocks.wrap(dstTimelockData);
    }

    function calculateSrcAddress() external view {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        
        (Timelocks srcTimelocks, ) = getTimelocks();

        // Create immutables struct for source chain
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: srcTimelocks
        });

        // Calculate source chain escrow address
        address escrowSrc = EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(srcImmutables);

        // Print addresses and details
        console.log("\n=== Source Chain (Sepolia) Details ===");
        console.log("Escrow Address:", escrowSrc);
        console.log("Factory Address:", SEPOLIA_ESCROW_FACTORY);
        console.log("Amount:", vm.toString(amount), "wei");
        console.log("Safety Deposit:", vm.toString(safetyDeposit), "wei");
        console.log("Total Required:", vm.toString(amount + safetyDeposit), "wei");

        console.log("\n=== Timelock Windows (Sepolia) ===");
        console.log("Deployment Time:", vm.toString(block.timestamp));
        console.log("1. Private Withdrawal:", vm.toString(PRIVATE_WITHDRAWAL), "seconds after deployment");
        console.log("2. Public Withdrawal:", vm.toString(PUBLIC_WITHDRAWAL), "seconds after private withdrawal");
        console.log("3. Private Cancellation:", vm.toString(SRC_PRIVATE_CANCELLATION), "seconds after public withdrawal");
        console.log("4. Public Cancellation:", vm.toString(SRC_PUBLIC_CANCELLATION), "seconds after private cancellation");

        console.log("\n=== Total Duration from Deployment ===");
        console.log("Private Withdrawal:", vm.toString(PRIVATE_WITHDRAWAL), "seconds");
        console.log("Public Withdrawal:", vm.toString(PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL), "seconds");
        console.log("Private Cancellation:", vm.toString(PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + SRC_PRIVATE_CANCELLATION), "seconds");
        console.log("Public Cancellation:", vm.toString(PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + SRC_PRIVATE_CANCELLATION + SRC_PUBLIC_CANCELLATION), "seconds");
    }

    function calculateDstAddress() external view {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        
        (, Timelocks dstTimelocks) = getTimelocks();

        // Create immutables struct for destination chain
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // MON
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: dstTimelocks
        });

        // Calculate destination chain escrow address
        address escrowDst = EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(dstImmutables);

        // Print addresses and details
        console.log("\n=== Destination Chain (Monad) Details ===");
        console.log("Escrow Address:", escrowDst);
        console.log("Factory Address:", MONAD_ESCROW_FACTORY);
        console.log("Amount:", vm.toString(amount), "wei");
        console.log("Safety Deposit:", vm.toString(safetyDeposit), "wei");
        console.log("Total Required:", vm.toString(amount + safetyDeposit), "wei");

        console.log("\n=== Timelock Windows (Monad) ===");
        console.log("Deployment Time:", vm.toString(block.timestamp));
        console.log("1. Private Withdrawal:", vm.toString(PRIVATE_WITHDRAWAL), "seconds after deployment");
        console.log("2. Public Withdrawal:", vm.toString(PUBLIC_WITHDRAWAL), "seconds after private withdrawal");
        console.log("3. Cancellation:", vm.toString(DST_CANCELLATION), "seconds after public withdrawal");

        console.log("\n=== Total Duration from Deployment ===");
        console.log("Private Withdrawal:", vm.toString(PRIVATE_WITHDRAWAL), "seconds");
        console.log("Public Withdrawal:", vm.toString(PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL), "seconds");
        console.log("Cancellation:", vm.toString(PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + DST_CANCELLATION), "seconds");
    }

    function run() external view {
        console.log("\n=== Important Parameters ===");
        console.log("Order Hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
    }
} 