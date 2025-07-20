// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../lib/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "../../lib/limit-order-protocol/contracts/OrderLib.sol";
import "../../lib/solidity-utils/contracts/libraries/AddressLib.sol";
import "../../lib/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import "../../lib/limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import "../../test/utils/libraries/CrossChainTestLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x69070b8F6DC375E4876f045C17dB6013D1F93312;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x550895b96dd1f2f9465b05a36bb5d7af052b02ff1b3172563a25671590d96818;
    bytes32 constant HASHLOCK = 0x65462b0520ef7d3df61b9992ed3bea0c56ead753be7c8b3614e0ce01e4cac41b;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0x8f9bfa3d9f2da686e75927e7997e115b90dbd46cb7aa2e724d624f447a70de04;
    bytes32 constant SIG_S = 0x385c73864f868801aff142eee6174fa1a5da755eea7771dde70a4f0d908d29ad;
    uint8 constant SIG_V = 28;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal view returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Set up maker traits for cross-chain swap
        MakerTraits makerTraits = MakerTraits.wrap(0);
        // Don't allow partial fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 255));
        // Don't allow multiple fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) & ~uint256(1 << 254));
        // Set extension flag for hashlock
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 249));

        // Create order using CrossChainTestLib
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            makerTraits, // Use cross-chain traits
            false, // don't allow multiple fills for cross-chain
            CrossChainTestLib.InteractionParams({
                makerAssetSuffix: "",
                takerAssetSuffix: "",
                makingAmountData: "",
                takingAmountData: "",
                predicate: "",
                permit: "",
                preInteraction: "",
                postInteraction: ""
            }),
            abi.encode(HASHLOCK), // pass hashlock as custom data
            ORDER_TIMESTAMP // use exact timestamp from original order
        );

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));
    }

    function buildExtension() internal pure returns (bytes memory) {
        // Extension format:
        // First 32 bytes: Offsets for each field
        // Then the extension data in sequence
        
        // We only have custom data (hashlock), so all other fields are empty
        bytes[] memory allInteractions = new bytes[](8);
        allInteractions[0] = hex""; // makerAssetSuffix
        allInteractions[1] = hex""; // takerAssetSuffix
        allInteractions[2] = hex""; // makingAmountData
        allInteractions[3] = hex""; // takingAmountData
        allInteractions[4] = hex""; // predicate
        allInteractions[5] = hex""; // permit
        allInteractions[6] = hex""; // preInteraction
        allInteractions[7] = hex""; // postInteraction

        // Encode hashlock as custom data
        bytes memory customData = abi.encode(HASHLOCK);

        // Calculate offsets - each offset is 32 bits and represents the cumulative length
        bytes32 offsets = 0;
        uint256 sum = 0;
        for (uint256 i = 0; i < allInteractions.length; i++) {
            if (allInteractions[i].length > 0) {
                sum += allInteractions[i].length;
            }
            offsets |= bytes32(sum << (i * 32));
        }

        // Concatenate all parts
        bytes memory allInteractionsConcat = bytes.concat(
            allInteractions[0],
            allInteractions[1],
            allInteractions[2],
            allInteractions[3],
            allInteractions[4],
            allInteractions[5],
            allInteractions[6],
            allInteractions[7],
            customData
        );

        // Concatenate offsets and data
        return bytes.concat(
            abi.encodePacked(offsets),
            allInteractionsConcat
        );
    }

    function verifyOrder(IOrderMixin.Order memory order) internal view {
        // Print order details for debugging
        console.log("\n=== Order Details ===");
        console.log("Salt: %s", vm.toString(bytes32(order.salt)));
        console.log("Maker: %s", order.maker.get());
        console.log("Receiver: %s", order.receiver.get());
        console.log("MakerAsset: %s", order.makerAsset.get());
        console.log("TakerAsset: %s", order.takerAsset.get());
        console.log("MakingAmount: %s", order.makingAmount);
        console.log("TakingAmount: %s", order.takingAmount);
        console.log("MakerTraits: %s", vm.toString(bytes32(MakerTraits.unwrap(order.makerTraits))));

        // Get order hash from LimitOrderProtocol
        bytes32 calculatedHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);
        console.log("\nCalculated Hash: %s", vm.toString(calculatedHash));
        console.log("Expected Hash:   %s", vm.toString(ORDER_HASH));
        require(calculatedHash == ORDER_HASH, "Order hash mismatch");

        // Verify order parameters
        require(order.maker.get() == MAKER, "Maker address mismatch");
        require(order.receiver.get() == MAKER, "Receiver address mismatch");
        require(order.makerAsset.get() == address(0), "Maker asset mismatch");
        require(order.takerAsset.get() == SEPOLIA_ERC20_TRUE, "Taker asset mismatch");
        require(order.makingAmount == 0.01 ether, "Making amount mismatch");
        require(order.takingAmount == 0.01 ether, "Taking amount mismatch");

        console.log("\n=== Order Verification ===");
        console.log("All parameters verified successfully");
    }

    function fillOrder() external {
        // Get the order and extension
        (IOrderMixin.Order memory order, bytes memory extension) = getOrder();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Print extension hash and salt
        uint256 extensionHash = uint256(keccak256(extension)) & type(uint160).max;
        uint256 orderSalt = uint256(order.salt) & type(uint160).max;
        console.log("\n=== Extension Hash vs Salt ===");
        console.log("Extension Hash (160): %s", vm.toString(bytes32(extensionHash)));
        console.log("Order Salt (160): %s", vm.toString(bytes32(orderSalt)));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits
        uint256 takerTraitsData = 0;
        // Set MAKER_AMOUNT_FLAG - use maker amount for fill
        takerTraitsData |= (1 << 255);
        // Set extension length
        takerTraitsData |= (extension.length << 224);
        // Set interaction length
        takerTraitsData |= (0 << 200);
        // Set threshold amount
        takerTraitsData |= order.takingAmount;

        TakerTraits takerTraits = TakerTraits.wrap(takerTraitsData);

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Approve ERC20 token transfer
        IERC20(SEPOLIA_ERC20_TRUE).approve(SEPOLIA_LIMIT_ORDER_PROTOCOL, order.takingAmount);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        (TakerTraits traits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount - use maker amount for fill
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            extension, // extension
            "", // interaction
            order.takingAmount // threshold
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            traits,
            args
        );

        vm.stopBroadcast();

        // Print results
        console.log("\n=== Fill Results ===");
        console.log("Making Amount Filled: %s", makingAmount);
        console.log("Taking Amount Filled: %s", takingAmount);
        console.log("Order Hash: %s", vm.toString(orderHash));
        console.log("Success: Order filled and EscrowSrc clone created");
    }

    function run() external view {
        // Get and verify the order
        (IOrderMixin.Order memory order, ) = getOrder();
        verifyOrder(order);

        console.log("\n=== Order Information ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        
        console.log("\n=== Signature Components ===");
        console.log("R: %s", vm.toString(SIG_R));
        console.log("S: %s", vm.toString(SIG_S));
        console.log("V: %d", SIG_V);

        console.log("\n=== Instructions ===");
        console.log("Run 'fillOrder()' to fill the order and create EscrowSrc clone");
        console.log("Note: Ensure safety deposits are sent before filling");
    }
} 