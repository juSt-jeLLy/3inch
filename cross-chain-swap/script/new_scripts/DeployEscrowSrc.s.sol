// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../../contracts/EscrowFactory.sol";
import "../../contracts/EscrowSrc.sol";
import "../../contracts/interfaces/IBaseEscrow.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "../../test/utils/libraries/CrossChainTestLib.sol";
import "../../test/utils/libraries/TimelocksSettersLib.sol";
import "../../contracts/libraries/TimelocksLib.sol";

contract DeployEscrowSrc is Script {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    // Sepolia addresses
    address constant SEPOLIA_ESCROW_FACTORY = 0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() external {
        // Set timelocks
        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 12000, // 2 minutes
            cancellation: 18000, // 3 minutes
            publicCancellation: 24000 // 4 minutes
        });

        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 12000, // 2 minutes
            cancellation: 18000 // 3 minutes
        });

        (Timelocks timelocksSrc, ) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        // Create escrow immutables
        bytes32 orderHash = 0x3545ec158819fdd4a6e8d907d395f4202ab9fdd22dcfa1e7d4799a5d34b8e711;
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

        // Get escrow source address
        address escrowSrc = EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(immutables);
        console.log("EscrowSrc will be deployed at:", escrowSrc);
        
        vm.startBroadcast(MAKER_PRIVATE_KEY);

        // Send ETH to escrow source
        (bool success, ) = escrowSrc.call{value: amount + safetyDeposit}("");
        require(success, "Failed to send ETH");

        vm.stopBroadcast();

        console.log("EscrowSrc funded with:", amount + safetyDeposit, "ETH");
        console.log("Order hash:", vm.toString(orderHash));
        console.log("Hashlock:", vm.toString(hashlock));
    }
} 