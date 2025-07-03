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

    function run() external {
        // Set timelocks
        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 120, // 2 minutes
            cancellation: 180, // 3 minutes
            publicCancellation: 240 // 4 minutes
        });

        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 120, // 2 minutes
            cancellation: 180 // 3 minutes
        });

        (, Timelocks timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        // Create escrow immutables
        bytes32 orderHash = 0x3545ec158819fdd4a6e8d907d395f4202ab9fdd22dcfa1e7d4799a5d34b8e711;
        bytes32 secret = bytes32("secret");
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks relative to current block timestamp
        timelocksDst = timelocksDst.setDeployedAt(block.timestamp);

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: hashlock,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });

        // Calculate source chain cancellation timestamp (must be greater than destination cancellation)
        uint256 srcCancellationTimestamp = block.timestamp + 240; // 4 minutes (same as source publicCancellation)

        // Log timestamps
        console.log("Current timestamp:", block.timestamp);
        console.log("Withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("Source cancellation timestamp:", srcCancellationTimestamp);
        
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Create and fund destination escrow using factory
        EscrowFactory(MONAD_ESCROW_FACTORY).createDstEscrow{value: amount + safetyDeposit}(immutables, srcCancellationTimestamp);

        vm.stopBroadcast();

        console.log("Destination escrow created and funded");
        console.log("Order hash:", vm.toString(orderHash));
        console.log("Hashlock:", vm.toString(hashlock));
    }
} 