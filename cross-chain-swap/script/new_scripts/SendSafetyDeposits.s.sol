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

contract SendSafetyDeposits is Script {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_ESCROW_FACTORY = 0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613;
    address constant MONAD_ESCROW_FACTORY = 0x919F799B949137e2b6AcE1fC5098b72EaDf7a453;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from previous step (SignOrder.s.sol output)
    bytes32 constant ORDER_HASH = 0x550895b96dd1f2f9465b05a36bb5d7af052b02ff1b3172563a25671590d96818;
    bytes32 constant HASHLOCK = 0x65462b0520ef7d3df61b9992ed3bea0c56ead753be7c8b3614e0ce01e4cac41b;

    // Timelock durations (same as CalculateEscrowAddresses.s.sol)
    uint256 constant PRIVATE_WITHDRAWAL = 60; // 1 minute
    uint256 constant PUBLIC_WITHDRAWAL = 3600; // 1 hour
    uint256 constant SRC_PRIVATE_CANCELLATION = 82800; // 23 hours
    uint256 constant SRC_PUBLIC_CANCELLATION = 86400; // 24 hours
    uint256 constant DST_CANCELLATION = 39600; // 11 hours

    function getSepoliaTimelocks() internal view returns (Timelocks srcTimelocks) {
        uint256 deploymentTime = block.timestamp;

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (PRIVATE_WITHDRAWAL << 192) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL) << 160) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + SRC_PRIVATE_CANCELLATION) << 128) |
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + SRC_PRIVATE_CANCELLATION + SRC_PUBLIC_CANCELLATION) << 96);
        
        srcTimelocks = Timelocks.wrap(srcTimelockData);
    }

    function getMonadTimelocks() internal view returns (Timelocks dstTimelocks) {
        uint256 deploymentTime = block.timestamp;

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (PRIVATE_WITHDRAWAL << 192) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL) << 160) | 
                              ((PRIVATE_WITHDRAWAL + PUBLIC_WITHDRAWAL + DST_CANCELLATION) << 128);
        
        dstTimelocks = Timelocks.wrap(dstTimelockData);
    }

    function getSepoliaEscrowAddress() internal view returns (address escrowSrc) {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        
        Timelocks srcTimelocks = getSepoliaTimelocks();

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
        escrowSrc = EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(srcImmutables);
    }

    function getMonadEscrowAddress() internal view returns (address escrowDst) {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        
        Timelocks dstTimelocks = getMonadTimelocks();

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
        escrowDst = EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(dstImmutables);
    }

    function checkSepoliaBalance() internal view {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        uint256 totalRequired = amount + safetyDeposit;

        // Check resolver's balances
        uint256 sepoliaBalance = TAKER.balance;
        console.log("\n=== Resolver Balance (Sepolia) ===");
        console.log("Current Balance:", sepoliaBalance);
        console.log("Required Balance:", totalRequired);
        
        if (sepoliaBalance < totalRequired) {
            revert("Insufficient balance on Sepolia");
        }
    }

    function sendSepoliaSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        address escrowSrc = getSepoliaEscrowAddress();

        // Print details
        console.log("\n=== Sending Safety Deposit on Sepolia ===");
        console.log("From (Resolver):", TAKER);
        console.log("To (EscrowSrc):", escrowSrc);
        console.log("Amount:", safetyDeposit);

        // Check balance first
        checkSepoliaBalance();

        // Send safety deposit
        vm.startBroadcast(TAKER_PRIVATE_KEY);
        
        (bool success,) = escrowSrc.call{value: safetyDeposit}("");
        require(success, "Failed to send safety deposit to Sepolia escrow");

        vm.stopBroadcast();

        console.log("Success: Safety deposit sent to Sepolia escrow");
    }

    function sendMonadSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        address escrowDst = getMonadEscrowAddress();

        // Print details
        console.log("\n=== Sending Safety Deposit on Monad ===");
        console.log("From (Resolver):", TAKER);
        console.log("To (EscrowDst):", escrowDst);
        console.log("Amount:", safetyDeposit);

        // Send safety deposit
        vm.startBroadcast(TAKER_PRIVATE_KEY);
        
        (bool success,) = escrowDst.call{value: safetyDeposit}("");
        require(success, "Failed to send safety deposit to Monad escrow");

        vm.stopBroadcast();

        console.log("Success: Safety deposit sent to Monad escrow");
    }

    function run() external view {
        console.log("\n=== Safety Deposit Information ===");
        console.log("Amount per chain:", 0.01 ether);
        
        console.log("\n=== Escrow Addresses ===");
        console.log("Sepolia (EscrowSrc):", getSepoliaEscrowAddress());
        console.log("Monad (EscrowDst):", getMonadEscrowAddress());

        console.log("\n=== Instructions ===");
        console.log("1. Run 'sendSepoliaSafetyDeposit()' to send safety deposit on Sepolia");
        console.log("2. Run 'sendMonadSafetyDeposit()' to send safety deposit on Monad");
        console.log("Note: Ensure resolver has sufficient balance on both chains");
    }
} 