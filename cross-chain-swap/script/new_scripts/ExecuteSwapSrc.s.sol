// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
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
    address constant ESCROW_SRC = 0x8bCbA2B582677139e13848abd98deB18FE773f4c;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() external {
        // Set timelocks
        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 3600, // 1 hour
            publicWithdrawal: 7200, // 2 hours
            cancellation: 10800, // 3 hours
            publicCancellation: 14400 // 4 hours
        });

        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: 3600, // 1 hour
            publicWithdrawal: 7200, // 2 hours
            cancellation: 10800 // 3 hours
        });

        (Timelocks timelocksSrc, ) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        // Create escrow immutables
        bytes32 orderHash = 0x9157d5e77039a77d1d8c7864ead847f3f5a2076a0a845a7622b81d62a36061d4;
        bytes32 secret = bytes32("secret"); // Same secret used on both chains
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
        
        vm.startBroadcast(MAKER_PRIVATE_KEY);

        // Execute withdraw on source escrow with the secret
        EscrowSrc(payable(ESCROW_SRC)).withdraw(secret, immutables);

        vm.stopBroadcast();

        console.log("Withdrawal executed on source chain");
        console.log("Secret used:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));
    }
} 