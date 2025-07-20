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

contract SignOrderScript is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Sepolia addresses
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x69070b8F6DC375E4876f045C17dB6013D1F93312;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() public {
        // Set up maker traits for cross-chain swap
        MakerTraits makerTraits = MakerTraits.wrap(0);
        // Don't allow partial fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 255));
        // Don't allow multiple fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) & ~uint256(1 << 254));
        // Set extension flag for hashlock
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 249));

        // Generate hashlock
        bytes32 hashlock = keccak256(abi.encodePacked("secret"));

        // Create order using CrossChainTestLib
        (IOrderMixin.Order memory order, bytes memory extension) = CrossChainTestLib.buildOrder(
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
            abi.encode(hashlock), // pass hashlock as custom data
            uint40(block.timestamp) // nonce - using current timestamp to ensure uniqueness
        );

        // Get order hash from LimitOrderProtocol
        bytes32 orderHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);

        // Sign order
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(MAKER_PRIVATE_KEY, orderHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Print order details
        console.log("\n=== Order Details ===");
        console.log("Order Hash: %s", vm.toString(orderHash));
        console.log("Signature r: %s", vm.toString(r));
        console.log("Signature s: %s", vm.toString(s));
        console.log("v: %d", v);
        console.log("Hashlock: %s", vm.toString(hashlock));
        console.log("Timestamp: %d", block.timestamp);

        // Print important addresses
        console.log("\n=== Contract Addresses ===");
        console.log("Limit Order Protocol: %s", SEPOLIA_LIMIT_ORDER_PROTOCOL);
        console.log("ERC20True: %s", SEPOLIA_ERC20_TRUE);

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
    }
} 