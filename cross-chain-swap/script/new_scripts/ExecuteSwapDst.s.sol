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
    address constant ESCROW_DST = 0x3B0fCae8e976F1febb4c42A360868f586A848d20;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    function run() external {
        // Create escrow immutables
        bytes32 orderHash = 0x3545ec158819fdd4a6e8d907d395f4202ab9fdd22dcfa1e7d4799a5d34b8e711;
        bytes32 secret = bytes32("secret");
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks from deployment transaction
        uint256 deploymentTime = 0x68667390;
        uint256 withdrawal = 0xb4;
        uint256 publicWithdrawal = 0x78;
        uint256 cancellation = 0x3c;

        // Pack timelocks into a uint256:
        // - Deployment time in highest 32 bits
        // - DstWithdrawal in bits 192-223
        // - DstPublicWithdrawal in bits 160-191
        // - DstCancellation in bits 128-159
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

        // Get current block timestamp
        uint256 timestamp = block.timestamp;
        console.log("Current timestamp:", timestamp);
        console.log("Deployment timestamp:", deploymentTime);
        console.log("Withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("Public withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstPublicWithdrawal));
        console.log("Cancellation timelock:", timelocksDst.get(TimelocksLib.Stage.DstCancellation));
        
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Execute withdraw on destination escrow with the secret
        try EscrowDst(payable(ESCROW_DST)).withdraw(secret, immutables) {
            console.log("Withdrawal executed successfully!");
        } catch Error(string memory reason) {
            console.log("Withdrawal failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Withdrawal failed with low level error. Data:", vm.toString(lowLevelData));
        }

        vm.stopBroadcast();

        console.log("Withdrawal execution attempt completed");
        console.log("Secret revealed:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));
    }
}