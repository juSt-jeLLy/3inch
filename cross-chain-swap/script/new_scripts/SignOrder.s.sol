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
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x111111125421cA6dc452d289314280a0f8842A65;

    // Addresses and private keys
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() public {
        // Create order using CrossChainTestLib
        (IOrderMixin.Order memory order, bytes memory extension) = CrossChainTestLib.buildOrder(
            MAKER,
            address(0), // receiver
            address(0), // makerAsset (ETH)
            address(0), // takerAsset (ETH)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
            true, // allowMultipleFills
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
            "", // customData
            uint40(block.timestamp) // nonce - using current timestamp to ensure uniqueness
        );

        // Get order hash from LimitOrderProtocol
        bytes32 orderHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);

        // Sign order
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(MAKER_PRIVATE_KEY, orderHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Print order details
        console.log("Order Hash:", vm.toString(orderHash));
        console.log("Signature r:", vm.toString(r));
        console.log("Signature s:", vm.toString(s));
        console.logUint(v); // Log v value directly as uint

        // Print important addresses
        console.log("Limit Order Protocol:", SEPOLIA_LIMIT_ORDER_PROTOCOL);
    }
} 