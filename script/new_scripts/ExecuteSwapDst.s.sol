// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/EscrowDst.sol";
import "../../contracts/interfaces/IBaseEscrow.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "../../test/utils/libraries/CrossChainTestLib.sol";
import "../../test/utils/libraries/TimelocksSettersLib.sol";
import "../../contracts/libraries/TimelocksLib.sol";

contract ExecuteSwapDst is Script {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    // Monad addresses - our deployed escrow
    address constant ESCROW_DST = 0xF1d33cd749cdba40ad0F9C6bcDD1b2A28281218e;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    error InvalidTimestamp(uint256 current, uint256 required);
    error WithdrawalFailed(string reason);

    function run() external {
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        bytes32 orderHash = 0x3545ec158819fdd4a6e8d907d395f4202ab9fdd22dcfa1e7d4799a5d34b8e711;
        bytes32 secret = bytes32("secret");
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks from deployment transaction
        uint256 deploymentTime = 0x68667c5e;
        uint256 withdrawal = 60;           // 1 minute - private withdrawal period
        uint256 publicWithdrawal = 12000;  // 200 minutes - public withdrawal period
        uint256 cancellation = 18000;      // 300 minutes - cancellation period

        // Pack timelocks into a uint256
        uint256 timelockData = (deploymentTime << 224) | (withdrawal << 192) | (publicWithdrawal << 160) | (cancellation << 128);
        Timelocks timelocksDst = Timelocks.wrap(timelockData);

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

        // Execute withdraw
        EscrowDst(payable(ESCROW_DST)).withdraw(secret, immutables);

        vm.stopBroadcast();
    }
} 