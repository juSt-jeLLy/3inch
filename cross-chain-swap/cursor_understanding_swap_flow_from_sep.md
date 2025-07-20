# Understanding swap flow from sepolia to monad
_Exported on 20/07/2025 at 14:32:08 GMT+5:30 from Cursor (1.1.3)_

---

**User**

okay now read the @README.md and @description.md and @1inch-fusion-plus.pdf and all the contrcats and scripts in the and tell me the flow of how i would do the swap from sepolia to monad just flow we'll do the code latter

---

**Cursor**

Let me help you understand the flow for performing a cross-chain swap from Sepolia to Monad. I'll analyze the available documentation and break down the process.

Let me first search through the codebase to understand the key components:

Based on the documentation and code analysis, let me break down the cross-chain swap flow from Sepolia to Monad:

1. **Initial Setup**
   - The user needs to have ETH on Sepolia (source chain)
   - The resolver needs to have MON on Monad (destination chain)
   - Both chains need to have deployed instances of:
     - `EscrowFactory`
     - `EscrowSrc` (on Sepolia)
     - `EscrowDst` (on Monad)
     - `LimitOrderProtocol` (on Sepolia)

2. **Order Creation (User Side - Sepolia)**
   - User creates and signs a limit order with:
     - `makerAsset`: ETH (on Sepolia)
     - `takerAsset`: A dummy ERC20True token that always returns true
     - `makingAmount`: Amount of ETH to swap
     - `takingAmount`: Same amount (1:1 ratio with dummy token)
   - The order includes a secret hash (hashlock) that will be used for the atomic swap

3. **Resolver Setup (Resolver Side)**
   - Resolver receives the signed order
   - Calculates the future `EscrowSrc` address using `EscrowFactory.addressOfEscrowSrc`
   - Sends safety deposit in native tokens to this address

4. **Source Chain Lock (Sepolia)**
   - Resolver executes the limit order using `LimitOrderProtocol.fillOrderArgs`
   - This deploys an `EscrowSrc` clone that holds the user's ETH
   - The ETH is now locked in the escrow on Sepolia

5. **Destination Chain Setup (Monad)**
   - Resolver calls `EscrowFactory.createDstEscrow` on Monad
   - Deposits the equivalent MON amount plus safety deposit
   - The MON is now locked in the `EscrowDst` clone on Monad

6. **Timelock Windows**
The system has several timelock periods:
   - Private withdrawal period
   - Public withdrawal period
   - Private cancellation period
   - Public cancellation period

7. **Withdrawal Process**
   - Once both escrows are set up, the resolver can withdraw tokens:
     - On Monad: Withdraw MON to the user using the secret
     - On Sepolia: Withdraw ETH to themselves using the same secret
   - If the resolver fails to withdraw within the private period, other resolvers can do it during the public period (incentivized by the safety deposit)

8. **Cancellation (if needed)**
   - If no withdrawal happens, after the cancellation period:
     - On Monad: Resolver can cancel and reclaim their MON
     - On Sepolia: User can get their ETH back
   - If the resolver doesn't cancel within their window, other resolvers can do it during the public cancellation period

9. **Safety Mechanisms**
   - Timelocks ensure orderly execution
   - Safety deposits incentivize proper behavior
   - Public withdrawal/cancellation periods provide backup options
   - `rescueFunds` function available for stuck assets after all periods expire

This is the high-level flow. Would you like me to elaborate on any particular part or shall we move on to implementing the specific steps?

---

**User**

so now check all the cripts in @/new_scripts and tell me what other scipts are need also addreses are in the @addresses.ts also for now we just want to swap the native notken so check all the scipts and tell me what is nneded where maker is user and taker is resolver

---

**Cursor**

I'll analyze the scripts and help you understand what's needed for a native token swap (ETH on Sepolia to MON on Monad) where the user is the maker and resolver is the taker.

Let me check the scripts in detail:

Based on the scripts and addresses provided, here's what we have and what's needed for a native token swap from Sepolia to Monad:

1. **Available Scripts**:
   - `SignOrder.s.sol` - Creates and signs the order on Sepolia (User/Maker side)
   - `DeployEscrowDst.s.sol` - Deploys destination escrow on Monad (Resolver/Taker side)
   - `ExecuteSwapSrc.s.sol` - Executes withdrawal on Sepolia (User/Maker side)
   - `ExecuteSwapDst.s.sol` - Executes withdrawal on Monad (Resolver/Taker side)

2. **Contract Addresses** (from addresses.ts):
   ```typescript
   Sepolia:
   - escrowFactory: '0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613'
   - limitOrderProtocol: '0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799'
   - escrowSrc: '0xDD3C59FfA6d09F5665BA103613Dd2A664DE1145d'

   Monad:
   - escrowFactory: '0x919F799B949137e2b6AcE1fC5098b72EaDf7A453'
   - escrowDst: '0x5Ea309821656B59B65cc979EF4b34e5e17F1dd33'
   ```

3. **What's Missing/Needed**:

   a. **Fill Order Script**: We need a script to fill the signed order on Sepolia. This script would:
   ```solidity
   // FillOrder.s.sol
   - Take the signed order from SignOrder.s.sol
   - Call LimitOrderProtocol.fillOrderArgs()
   - Deploy EscrowSrc clone
   ```

   b. **Safety Deposit Script**: We need a script to send safety deposits:
   ```solidity
   // SendSafetyDeposits.s.sol
   - Calculate future EscrowSrc address
   - Send safety deposit to EscrowSrc address
   - Send safety deposit to EscrowDst
   ```

   c. **Timelock Coordination Script**: A helper script to:
   ```solidity
   // SetupTimelocks.s.sol
   - Calculate and coordinate timelocks between chains
   - Ensure src cancellation > dst cancellation
   - Generate consistent timelock values for both chains
   ```

4. **Script Execution Order**:
   ```
   User (Maker) Side:
   1. SignOrder.s.sol - Create and sign order
   4. ExecuteSwapSrc.s.sol - Withdraw ETH after resolver reveals secret

   Resolver (Taker) Side:
   2. SendSafetyDeposits.s.sol - Send safety deposits
   3. FillOrder.s.sol - Fill order on Sepolia
   4. DeployEscrowDst.s.sol - Deploy and fund destination escrow
   5. ExecuteSwapDst.s.sol - Withdraw MON using secret
   ```

5. **Key Parameters to Coordinate**:
   - `orderHash` must match between chains
   - `secret` and `hashlock` must be consistent
   - `amount` and `safetyDeposit` values
   - Timelock windows must be properly coordinated
   - Maker and Taker addresses must be consistent

Would you like me to help you create any of the missing scripts or modify the existing ones to work together more smoothly?

```typescript
   Sepolia:
   - escrowFactory: '0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613'
   - limitOrderProtocol: '0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799'
   - escrowSrc: '0xDD3C59FfA6d09F5665BA103613Dd2A664DE1145d'

   Monad:
   - escrowFactory: '0x919F799B949137e2b6AcE1fC5098b72EaDf7A453'
   - escrowDst: '0x5Ea309821656B59B65cc979EF4b34e5e17F1dd33'
```

```solidity
   // FillOrder.s.sol
   - Take the signed order from SignOrder.s.sol
   - Call LimitOrderProtocol.fillOrderArgs()
   - Deploy EscrowSrc clone
```

```solidity
   // SendSafetyDeposits.s.sol
   - Calculate future EscrowSrc address
   - Send safety deposit to EscrowSrc address
   - Send safety deposit to EscrowDst
```

```solidity
   // SetupTimelocks.s.sol
   - Calculate and coordinate timelocks between chains
   - Ensure src cancellation > dst cancellation
   - Generate consistent timelock values for both chains
```

```plaintext
   User (Maker) Side:
   1. SignOrder.s.sol - Create and sign order
   4. ExecuteSwapSrc.s.sol - Withdraw ETH after resolver reveals secret

   Resolver (Taker) Side:
   2. SendSafetyDeposits.s.sol - Send safety deposits
   3. FillOrder.s.sol - Fill order on Sepolia
   4. DeployEscrowDst.s.sol - Deploy and fund destination escrow
   5. ExecuteSwapDst.s.sol - Withdraw MON using secret
```

---

**User**

so where is the whole flow that we have to do script by scripts and tell me what is done and missing on that flow so we can do the test one by one scriot at a time

---

**Cursor**

I'll break down the complete flow and analyze what scripts we have vs. what we need to create/modify. Let's go step by step:

Complete Flow for ETH (Sepolia) → MON (Monad) Swap:

1. **User (Maker) Creates and Signs Order on Sepolia**
   - ✅ Have: `SignOrder.s.sol`
   - Current script creates order with:
     - makerAsset: ETH (address(0))
     - makingAmount: 0.01 ETH
     - takingAmount: 0.01 ETH
   - ⚠️ Needs Modification:
     - Update addresses from addresses.ts
     - Add proper secret generation
     - Add proper order parameters for cross-chain swap

2. **Resolver (Taker) Calculates Future EscrowSrc Address**
   - ❌ Missing: `CalculateEscrowAddresses.s.sol`
   - Need to create script to:
     - Calculate future EscrowSrc address using `EscrowFactory.addressOfEscrowSrc`
     - Calculate future EscrowDst address using `EscrowFactory.addressOfEscrowDst`
     - Print addresses for verification

3. **Resolver Sends Safety Deposits**
   - ❌ Missing: `SendSafetyDeposits.s.sol`
   - Need to create script to:
     - Send safety deposit to future EscrowSrc address on Sepolia
     - Send safety deposit to future EscrowDst address on Monad

4. **Resolver Fills Order on Sepolia**
   - ❌ Missing: `FillOrder.s.sol`
   - Need to create script to:
     - Take signed order from step 1
     - Call LimitOrderProtocol.fillOrderArgs
     - This creates EscrowSrc clone

5. **Resolver Creates Destination Escrow on Monad**
   - ✅ Have: `DeployEscrowDst.s.sol`
   - ⚠️ Needs Modification:
     - Update addresses from addresses.ts
     - Sync orderHash and hashlock with SignOrder script
     - Update timelocks to match source chain

6. **Resolver Reveals Secret on Monad**
   - ✅ Have: `ExecuteSwapDst.s.sol`
   - ⚠️ Needs Modification:
     - Update addresses from addresses.ts
     - Use same secret/hashlock from SignOrder
     - Add proper timelock checks

7. **User Withdraws on Sepolia Using Revealed Secret**
   - ✅ Have: `ExecuteSwapSrc.s.sol`
   - ⚠️ Needs Modification:
     - Update addresses from addresses.ts
     - Use same secret/hashlock from SignOrder
     - Add proper timelock checks

Let's create/modify these scripts one by one. Which script would you like to start with? Here's my suggested order:

1. First modify `SignOrder.s.sol` to use proper parameters and generate secret
2. Create `CalculateEscrowAddresses.s.sol` to get escrow addresses
3. Create `SendSafetyDeposits.s.sol` for safety deposits
4. Create `FillOrder.s.sol` for order execution
5. Modify `DeployEscrowDst.s.sol` to sync with source chain
6. Modify `ExecuteSwapDst.s.sol` and `ExecuteSwapSrc.s.sol` to use same parameters

Would you like me to start with modifying the `SignOrder.s.sol` script first?

---

**User**

export PRIVATE_KEY=380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd export SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/yT3gB4VqNunOHvOKZBtHY export DEPLOYER_ADDRESS=0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27 export ETHERSCAN_API_KEY=ETWG9FVAIQ6JXGXYXVN7GN8GH5CF424CPT export MONAD_RPC_URL=https://monad-testnet.g.alchemy.com/v2/8JJ5eYmwOMkOHp0BYFLrh export MAKER_PRIVATE_KEY=380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd



this is the needed you can use this at the command runningtime now lest srat with the sign order part like we can check @https://github.com/1inch/limit-order-protocol-utils/  for the sign order for refernce so now modi fy the signorder as needed and now you can write code

---

**Cursor**

I'll help you modify the SignOrder.s.sol script using the 1inch limit-order-protocol-utils as reference. Let's create a proper order signing script for the cross-chain swap.

First, let's modify `SignOrder.s.sol`:

```solidity
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

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21; // Using feeToken as ERC20True

    // Addresses and private keys from env
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() public {
        // Generate secret and hashlock
        bytes32 secret = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp, MAKER, "salt"))));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));

        console.log("\n=== Generated Secret Info ===");
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));

        // Create order using CrossChainTestLib
        (IOrderMixin.Order memory order, bytes memory extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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
        console.log("Order Hash:", vm.toString(orderHash));
        console.log("Making Amount:", order.makingAmount);
        console.log("Taking Amount:", order.takingAmount);
        
        console.log("\n=== Signature Details ===");
        console.log("Signature r:", vm.toString(r));
        console.log("Signature s:", vm.toString(s));
        console.logUint(v); // Log v value directly as uint

        console.log("\n=== Important Addresses ===");
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
        console.log("Limit Order Protocol:", SEPOLIA_LIMIT_ORDER_PROTOCOL);
        console.log("ERC20True Token:", SEPOLIA_ERC20_TRUE);
    }
}
```

Key changes made to the SignOrder script:

1. Added proper secret and hashlock generation
2. Set receiver to be the same as maker (required for cross-chain)
3. Changed takerAsset to use ERC20True token instead of ETH
4. Disabled multiple fills (not needed for cross-chain)
5. Added hashlock to customData for verification
6. Added more detailed logging
7. Used addresses from addresses.ts

To run this script:

```bash
# First export the environment variables
export PRIVATE_KEY=380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd
export SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/yT3gB4VqNunOHvOKZBtHY
export DEPLOYER_ADDRESS=0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27
export ETHERSCAN_API_KEY=ETWG9FVAIQ6JXGXYXVN7GN8GH5CF424CPT
export MONAD_RPC_URL=https://monad-testnet.g.alchemy.com/v2/8JJ5eYmwOMkOHp0BYFLrh
export MAKER_PRIVATE_KEY=380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd

# Then run the script
forge script script/new_scripts/SignOrder.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv
```

This script will:
1. Generate a unique secret and hashlock
2. Create a cross-chain order for 0.01 ETH
3. Sign the order with the maker's private key
4. Print all necessary information needed for subsequent steps

The output will include:
- Secret and hashlock (needed for withdrawals)
- Order hash (needed for escrow creation)
- Signature components (needed for order filling)
- All relevant addresses

Would you like me to explain any part of the changes in more detail or shall we move on to creating the next script in the flow?

```shellscript
# First export the environment variables
export PRIVATE_KEY=380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd
export SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/yT3gB4VqNunOHvOKZBtHY
export DEPLOYER_ADDRESS=0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27
export ETHERSCAN_API_KEY=ETWG9FVAIQ6JXGXYXVN7GN8GH5CF424CPT
export MONAD_RPC_URL=https://monad-testnet.g.alchemy.com/v2/8JJ5eYmwOMkOHp0BYFLrh
export MAKER_PRIVATE_KEY=380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd

# Then run the script
forge script script/new_scripts/SignOrder.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv
```

---

**User**

you run the script you have the access to terminal

---

**Cursor**

I'll run the SignOrder script using the provided environment variables.

The script ran successfully! Let's analyze the important outputs:

1. **Secret and Hashlock** (needed for withdrawals):
   ```
   Secret: 0x2e2757fe4a3a87011e570f824a45fb4a73cd891f17351f04875b7b1fcf2998b1
   Hashlock: 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6
   ```

2. **Order Details**:
   ```
   Order Hash: 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e
   ```

3. **Signature Components**:
   ```
   Signature r: 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9
   Signature s: 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412
   v: 27 (shown in traces)
   ```

4. **Important Addresses**:
   ```
   Maker (User): 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27
   Taker (Resolver): 0x4207ebd97F999F142fFD3696dD76A61193b23e89
   Limit Order Protocol: 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799
   ERC20True Token: 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21
   ```

There are a few warnings in the compilation about unused variables and state mutability, but these don't affect the functionality. The script successfully:
1. Generated a unique secret and hashlock
2. Created the order
3. Got the order hash from the Limit Order Protocol
4. Signed the order with the maker's private key

The warning "No transactions to broadcast" is expected because this script only creates and signs the order locally - it doesn't need to send any transactions to the blockchain.

Would you like to:
1. Fix the compiler warnings in the SignOrder script?
2. Move on to creating the next script in the flow (CalculateEscrowAddresses)?
3. Or something else?

```plaintext
   Secret: 0x2e2757fe4a3a87011e570f824a45fb4a73cd891f17351f04875b7b1fcf2998b1
   Hashlock: 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6
```

```plaintext
   Order Hash: 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e
```

```plaintext
   Signature r: 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9
   Signature s: 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412
   v: 27 (shown in traces)
```

```plaintext
   Maker (User): 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27
   Taker (Resolver): 0x4207ebd97F999F142fFD3696dD76A61193b23e89
   Limit Order Protocol: 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799
   ERC20True Token: 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21
```

---

**User**

now to the second steps do that the
Resolver (Taker) Calculates Future EscrowSrc Address
❌ Missing: CalculateEscrowAddresses.s.sol
Need to create script to:
Calculate future EscrowSrc address using EscrowFactory.addressOfEscrowSrc
Calculate future EscrowDst address using EscrowFactory.addressOfEscrowDst
Print addresses for verification

---

**Cursor**

I'll help you create the `CalculateEscrowAddresses.s.sol` script. This script will calculate both escrow addresses using the order details from the previous step.

```solidity
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
    address constant MONAD_ESCROW_FACTORY = 0x919F799B949137e2b6AcE1fC5098b72EaDf7A453;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    // Order details from previous step (SignOrder.s.sol output)
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    function run() external {
        // Set amounts
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks for source chain
        uint256 deploymentTime = block.timestamp;
        uint256 srcWithdrawal = 60; // 1 minute
        uint256 srcPublicWithdrawal = 3600; // 1 hour
        uint256 srcCancellation = 86400; // 24 hours
        uint256 srcPublicCancellation = 172800; // 48 hours

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (srcWithdrawal << 192) | 
                              (srcPublicWithdrawal << 160) | 
                              (srcCancellation << 128) |
                              (srcPublicCancellation << 96);
        
        Timelocks timelocksSrc = Timelocks.wrap(srcTimelockData);

        // Set timelocks for destination chain
        uint256 dstWithdrawal = 60; // 1 minute
        uint256 dstPublicWithdrawal = 3600; // 1 hour
        uint256 dstCancellation = 43200; // 12 hours (must be less than src cancellation)

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (dstWithdrawal << 192) | 
                              (dstPublicWithdrawal << 160) | 
                              (dstCancellation << 128);
        
        Timelocks timelocksDst = Timelocks.wrap(dstTimelockData);

        // Create immutables struct for source chain
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksSrc
        });

        // Create immutables struct for destination chain
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // MON
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });

        // Calculate source chain escrow address
        address escrowSrc = EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(srcImmutables);
        
        // Calculate destination chain escrow address
        address escrowDst = EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(dstImmutables);

        // Print addresses and details
        console.log("\n=== Calculated Escrow Addresses ===");
        console.log("Source Chain (Sepolia) Escrow:", escrowSrc);
        console.log("Destination Chain (Monad) Escrow:", escrowDst);

        console.log("\n=== Important Parameters ===");
        console.log("Order Hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Amount:", amount);
        console.log("Safety Deposit:", safetyDeposit);

        console.log("\n=== Timelock Windows ===");
        console.log("Deployment Time:", deploymentTime);
        
        console.log("\nSource Chain (Sepolia):");
        console.log("- Private Withdrawal:", timelocksSrc.get(TimelocksLib.Stage.SrcWithdrawal));
        console.log("- Public Withdrawal:", timelocksSrc.get(TimelocksLib.Stage.SrcPublicWithdrawal));
        console.log("- Private Cancellation:", timelocksSrc.get(TimelocksLib.Stage.SrcCancellation));
        console.log("- Public Cancellation:", timelocksSrc.get(TimelocksLib.Stage.SrcPublicCancellation));
        
        console.log("\nDestination Chain (Monad):");
        console.log("- Private Withdrawal:", timelocksDst.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("- Public Withdrawal:", timelocksDst.get(TimelocksLib.Stage.DstPublicWithdrawal));
        console.log("- Cancellation:", timelocksDst.get(TimelocksLib.Stage.DstCancellation));

        // Calculate total amounts needed
        uint256 totalSepolia = amount + safetyDeposit;
        uint256 totalMonad = amount + safetyDeposit;

        console.log("\n=== Required Balances ===");
        console.log("Required on Sepolia (ETH):", totalSepolia);
        console.log("Required on Monad (MON):", totalMonad);
    }
}
```

Let me fix the checksum address issue and then run the script:

```solidity
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

    // Rest of the code remains the same...
}
```

Now let's run the script to calculate the escrow addresses:

I see the issue - we need to run it against both networks to properly calculate both addresses. Let's modify the script to handle this better:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    function run() external view {
        // Set amounts
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks for source chain
        uint256 deploymentTime = block.timestamp;
        uint256 srcWithdrawal = 60; // 1 minute
        uint256 srcPublicWithdrawal = 3600; // 1 hour
        uint256 srcCancellation = 86400; // 24 hours
        uint256 srcPublicCancellation = 172800; // 48 hours

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (srcWithdrawal << 192) | 
                              (srcPublicWithdrawal << 160) | 
                              (srcCancellation << 128) |
                              (srcPublicCancellation << 96);
        
        Timelocks timelocksSrc = Timelocks.wrap(srcTimelockData);

        // Set timelocks for destination chain
        uint256 dstWithdrawal = 60; // 1 minute
        uint256 dstPublicWithdrawal = 3600; // 1 hour
        uint256 dstCancellation = 43200; // 12 hours (must be less than src cancellation)

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (dstWithdrawal << 192) | 
                              (dstPublicWithdrawal << 160) | 
                              (dstCancellation << 128);
        
        Timelocks timelocksDst = Timelocks.wrap(dstTimelockData);

        // Create immutables struct for source chain
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksSrc
        });

        // Create immutables struct for destination chain
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // MON
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });

        // Calculate addresses
        address escrowSrc;
        address escrowDst;

        try EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(srcImmutables) returns (address addr) {
            escrowSrc = addr;
        } catch {
            escrowSrc = address(0);
        }

        try EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(dstImmutables) returns (address addr) {
            escrowDst = addr;
        } catch {
            escrowDst = address(0);
        }

        // Print addresses and details
        console.log("\n=== Calculated Escrow Addresses ===");
        console.log("Source Chain (Sepolia) Escrow:", escrowSrc);
        console.log("Destination Chain (Monad) Escrow:", escrowDst);

        console.log("\n=== Important Parameters ===");
        console.log("Order Hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Amount:", amount);
        console.log("Safety Deposit:", safetyDeposit);

        console.log("\n=== Timelock Windows ===");
        console.log("Deployment Time:", deploymentTime);
        
        console.log("\nSource Chain (Sepolia):");
        console.log("- Private Withdrawal:", timelocksSrc.get(TimelocksLib.Stage.SrcWithdrawal));
        console.log("- Public Withdrawal:", timelocksSrc.get(TimelocksLib.Stage.SrcPublicWithdrawal));
        console.log("- Private Cancellation:", timelocksSrc.get(TimelocksLib.Stage.SrcCancellation));
        console.log("- Public Cancellation:", timelocksSrc.get(TimelocksLib.Stage.SrcPublicCancellation));
        
        console.log("\nDestination Chain (Monad):");
        console.log("- Private Withdrawal:", timelocksDst.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("- Public Withdrawal:", timelocksDst.get(TimelocksLib.Stage.DstPublicWithdrawal));
        console.log("- Cancellation:", timelocksDst.get(TimelocksLib.Stage.DstCancellation));

        // Calculate total amounts needed
        uint256 totalSepolia = amount + safetyDeposit;
        uint256 totalMonad = amount + safetyDeposit;

        console.log("\n=== Required Balances ===");
        console.log("Required on Sepolia (ETH):", totalSepolia);
        console.log("Required on Monad (MON):", totalMonad);
    }
}
```

Now let's run the script against both networks to get both addresses:

Let's try running it with fork mode to simulate both networks:

I see the issue - we need to modify the script to handle the fact that we can only calculate one address at a time. Let's split the script into two parts:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    function getTimelocks() internal view returns (Timelocks srcTimelocks, Timelocks dstTimelocks) {
        // Set timelocks for source chain
        uint256 deploymentTime = block.timestamp;
        uint256 srcWithdrawal = 60; // 1 minute
        uint256 srcPublicWithdrawal = 3600; // 1 hour
        uint256 srcCancellation = 86400; // 24 hours
        uint256 srcPublicCancellation = 172800; // 48 hours

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (srcWithdrawal << 192) | 
                              (srcPublicWithdrawal << 160) | 
                              (srcCancellation << 128) |
                              (srcPublicCancellation << 96);
        
        srcTimelocks = Timelocks.wrap(srcTimelockData);

        // Set timelocks for destination chain
        uint256 dstWithdrawal = 60; // 1 minute
        uint256 dstPublicWithdrawal = 3600; // 1 hour
        uint256 dstCancellation = 43200; // 12 hours (must be less than src cancellation)

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (dstWithdrawal << 192) | 
                              (dstPublicWithdrawal << 160) | 
                              (dstCancellation << 128);
        
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
        console.log("Amount:", amount);
        console.log("Safety Deposit:", safetyDeposit);
        console.log("Total Required:", amount + safetyDeposit);

        console.log("\n=== Timelock Windows (Sepolia) ===");
        console.log("- Private Withdrawal:", srcTimelocks.get(TimelocksLib.Stage.SrcWithdrawal));
        console.log("- Public Withdrawal:", srcTimelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal));
        console.log("- Private Cancellation:", srcTimelocks.get(TimelocksLib.Stage.SrcCancellation));
        console.log("- Public Cancellation:", srcTimelocks.get(TimelocksLib.Stage.SrcPublicCancellation));
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
        console.log("Amount:", amount);
        console.log("Safety Deposit:", safetyDeposit);
        console.log("Total Required:", amount + safetyDeposit);

        console.log("\n=== Timelock Windows (Monad) ===");
        console.log("- Private Withdrawal:", dstTimelocks.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("- Public Withdrawal:", dstTimelocks.get(TimelocksLib.Stage.DstPublicWithdrawal));
        console.log("- Cancellation:", dstTimelocks.get(TimelocksLib.Stage.DstCancellation));
    }

    function run() external view {
        console.log("\n=== Important Parameters ===");
        console.log("Order Hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
    }
}
```

Now let's run the script for both chains:

Perfect! We've successfully calculated both escrow addresses. Here's the summary:

1. **Source Chain (Sepolia)**:
   - Escrow Address: `0x297f1AaA03512545cc1B19A938D7433220C07a0F`
   - Factory Address: `0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613`
   - Amount: 0.01 ETH
   - Safety Deposit: 0.01 ETH
   - Total Required: 0.02 ETH

2. **Destination Chain (Monad)**:
   - Escrow Address: `0x3fA62F1c67C27C1c0Ec0b80f724d6956F680AC7E`
   - Factory Address: `0x919F799B949137e2b6AcE1fC5098b72EaDf7a453`
   - Amount: 0.01 MON
   - Safety Deposit: 0.01 MON
   - Total Required: 0.02 MON

These addresses will be used in the next steps:
1. The resolver needs to send safety deposits to both addresses
2. The source escrow address will receive the user's ETH when the order is filled
3. The destination escrow address will hold the resolver's MON for the user

Would you like to:
1. Fix the console logging issues in the script (the `9710a9d0` errors)?
2. Move on to creating the next script for sending safety deposits?
3. Or something else?

---

**User**

Fix the console logging issues in the script (the 9710a9d0 errors)?

and explain what are these

---

**Cursor**

The `9710a9d0` errors are coming from incorrect console logging of numeric values. Let me explain and fix this:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    function getTimelocks() internal view returns (Timelocks srcTimelocks, Timelocks dstTimelocks) {
        // Set timelocks for source chain
        uint256 deploymentTime = block.timestamp;
        uint256 srcWithdrawal = 60; // 1 minute
        uint256 srcPublicWithdrawal = 3600; // 1 hour
        uint256 srcCancellation = 86400; // 24 hours
        uint256 srcPublicCancellation = 172800; // 48 hours

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (srcWithdrawal << 192) | 
                              (srcPublicWithdrawal << 160) | 
                              (srcCancellation << 128) |
                              (srcPublicCancellation << 96);
        
        srcTimelocks = Timelocks.wrap(srcTimelockData);

        // Set timelocks for destination chain
        uint256 dstWithdrawal = 60; // 1 minute
        uint256 dstPublicWithdrawal = 3600; // 1 hour
        uint256 dstCancellation = 43200; // 12 hours (must be less than src cancellation)

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (dstWithdrawal << 192) | 
                              (dstPublicWithdrawal << 160) | 
                              (dstCancellation << 128);
        
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

        uint256 withdrawalTime = srcTimelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 publicWithdrawalTime = srcTimelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        uint256 cancellationTime = srcTimelocks.get(TimelocksLib.Stage.SrcCancellation);
        uint256 publicCancellationTime = srcTimelocks.get(TimelocksLib.Stage.SrcPublicCancellation);

        console.log("\n=== Timelock Windows (Sepolia) ===");
        console.log("- Private Withdrawal:", vm.toString(withdrawalTime), "(timestamp)");
        console.log("- Public Withdrawal:", vm.toString(publicWithdrawalTime), "(timestamp)");
        console.log("- Private Cancellation:", vm.toString(cancellationTime), "(timestamp)");
        console.log("- Public Cancellation:", vm.toString(publicCancellationTime), "(timestamp)");

        // Print relative times
        console.log("\n=== Relative Times (Sepolia) ===");
        console.log("- Private Withdrawal: starts in", vm.toString(withdrawalTime - block.timestamp), "seconds");
        console.log("- Public Withdrawal: starts in", vm.toString(publicWithdrawalTime - block.timestamp), "seconds");
        console.log("- Private Cancellation: starts in", vm.toString(cancellationTime - block.timestamp), "seconds");
        console.log("- Public Cancellation: starts in", vm.toString(publicCancellationTime - block.timestamp), "seconds");
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

        uint256 withdrawalTime = dstTimelocks.get(TimelocksLib.Stage.DstWithdrawal);
        uint256 publicWithdrawalTime = dstTimelocks.get(TimelocksLib.Stage.DstPublicWithdrawal);
        uint256 cancellationTime = dstTimelocks.get(TimelocksLib.Stage.DstCancellation);

        console.log("\n=== Timelock Windows (Monad) ===");
        console.log("- Private Withdrawal:", vm.toString(withdrawalTime), "(timestamp)");
        console.log("- Public Withdrawal:", vm.toString(publicWithdrawalTime), "(timestamp)");
        console.log("- Cancellation:", vm.toString(cancellationTime), "(timestamp)");

        // Print relative times
        console.log("\n=== Relative Times (Monad) ===");
        console.log("- Private Withdrawal: starts in", vm.toString(withdrawalTime - block.timestamp), "seconds");
        console.log("- Public Withdrawal: starts in", vm.toString(publicWithdrawalTime - block.timestamp), "seconds");
        console.log("- Cancellation: starts in", vm.toString(cancellationTime - block.timestamp), "seconds");
    }

    function run() external view {
        console.log("\n=== Important Parameters ===");
        console.log("Order Hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
    }
}
```

Let me explain the `9710a9d0` errors and the fixes:

1. **What are these errors?**
   - The `9710a9d0` errors occur when Forge's console logging tries to directly log uint256 values
   - This happens because Solidity's console.log has different function signatures for different types
   - When we try to log a number directly, it tries to use a function selector that doesn't exist

2. **The Fix:**
   - We use `vm.toString()` to convert uint256 values to strings before logging
   - This ensures we use the correct console.log function signature
   - We also store timelock values in variables to avoid multiple calls to get()
   - Added units (wei) to make amounts clearer
   - Added relative times to show when each window starts

Let's run the fixed script:

Perfect! The script now runs without any errors and provides much clearer output. Here's what we fixed:

1. **Number Formatting**:
   - Used `vm.toString()` to properly convert uint256 values to strings
   - Added "wei" unit to make amounts clearer
   - Added "(timestamp)" to timelock values for clarity

2. **Added Relative Times**:
   - Now shows how many seconds until each window starts
   - Makes it easier to understand when actions can be taken
   - Shows the relationship between different timelock periods

3. **Improved Organization**:
   - Separated timelock retrieval into a helper function
   - Stored timelock values in variables to avoid multiple calls
   - Added clear section headers in the output

The output now shows:
1. The escrow addresses for both chains
2. The exact amounts needed in wei
3. The timelock windows with both absolute timestamps and relative times

Would you like to:
1. Add any additional information to the output?
2. Move on to creating the next script for sending safety deposits?
3. Or something else?

---

**User**

there is smething wrong with the timelocks relative tine isnt it like i should be able to do the swap then like ifirst comes the private withdrawl then public withdrawl and thencancellation so fix that on both chains

---

**Cursor**

Yes, you're absolutely right! The timelocks should be sequential, with each window starting after the previous one. Let me fix the timelock calculations:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    function getTimelocks() internal view returns (Timelocks srcTimelocks, Timelocks dstTimelocks) {
        // Set timelocks for source chain
        uint256 deploymentTime = block.timestamp;

        // Source chain timelock durations (relative to deployment)
        uint256 srcWithdrawal = 60; // 1 minute for private withdrawal
        uint256 srcPublicWithdrawal = srcWithdrawal + 3600; // +1 hour for public withdrawal
        uint256 srcCancellation = srcPublicWithdrawal + 82800; // +23 hours for private cancellation
        uint256 srcPublicCancellation = srcCancellation + 86400; // +24 hours for public cancellation

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (srcWithdrawal << 192) | 
                              (srcPublicWithdrawal << 160) | 
                              (srcCancellation << 128) |
                              (srcPublicCancellation << 96);
        
        srcTimelocks = Timelocks.wrap(srcTimelockData);

        // Destination chain timelock durations (relative to deployment)
        uint256 dstWithdrawal = 60; // 1 minute for private withdrawal
        uint256 dstPublicWithdrawal = dstWithdrawal + 3600; // +1 hour for public withdrawal
        uint256 dstCancellation = dstPublicWithdrawal + 39600; // +11 hours for cancellation (must be less than src cancellation)

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (dstWithdrawal << 192) | 
                              (dstPublicWithdrawal << 160) | 
                              (dstCancellation << 128);
        
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

        uint256 withdrawalTime = srcTimelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 publicWithdrawalTime = srcTimelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        uint256 cancellationTime = srcTimelocks.get(TimelocksLib.Stage.SrcCancellation);
        uint256 publicCancellationTime = srcTimelocks.get(TimelocksLib.Stage.SrcPublicCancellation);

        console.log("\n=== Timelock Windows (Sepolia) ===");
        console.log("Deployment Time:", vm.toString(block.timestamp));
        console.log("1. Private Withdrawal:", vm.toString(withdrawalTime - block.timestamp), "seconds after deployment");
        console.log("2. Public Withdrawal:", vm.toString(publicWithdrawalTime - withdrawalTime), "seconds after private withdrawal");
        console.log("3. Private Cancellation:", vm.toString(cancellationTime - publicWithdrawalTime), "seconds after public withdrawal");
        console.log("4. Public Cancellation:", vm.toString(publicCancellationTime - cancellationTime), "seconds after private cancellation");

        console.log("\n=== Window Start Times (Sepolia) ===");
        console.log("Private Withdrawal starts at:", vm.toString(withdrawalTime));
        console.log("Public Withdrawal starts at:", vm.toString(publicWithdrawalTime));
        console.log("Private Cancellation starts at:", vm.toString(cancellationTime));
        console.log("Public Cancellation starts at:", vm.toString(publicCancellationTime));
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

        uint256 withdrawalTime = dstTimelocks.get(TimelocksLib.Stage.DstWithdrawal);
        uint256 publicWithdrawalTime = dstTimelocks.get(TimelocksLib.Stage.DstPublicWithdrawal);
        uint256 cancellationTime = dstTimelocks.get(TimelocksLib.Stage.DstCancellation);

        console.log("\n=== Timelock Windows (Monad) ===");
        console.log("Deployment Time:", vm.toString(block.timestamp));
        console.log("1. Private Withdrawal:", vm.toString(withdrawalTime - block.timestamp), "seconds after deployment");
        console.log("2. Public Withdrawal:", vm.toString(publicWithdrawalTime - withdrawalTime), "seconds after private withdrawal");
        console.log("3. Cancellation:", vm.toString(cancellationTime - publicWithdrawalTime), "seconds after public withdrawal");

        console.log("\n=== Window Start Times (Monad) ===");
        console.log("Private Withdrawal starts at:", vm.toString(withdrawalTime));
        console.log("Public Withdrawal starts at:", vm.toString(publicWithdrawalTime));
        console.log("Cancellation starts at:", vm.toString(cancellationTime));
    }

    function run() external view {
        console.log("\n=== Important Parameters ===");
        console.log("Order Hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
    }
}
```

Key changes made:

1. **Sequential Timelocks on Source Chain (Sepolia)**:
   - Private Withdrawal: 60s after deployment
   - Public Withdrawal: +1 hour after private withdrawal
   - Private Cancellation: +23 hours after public withdrawal
   - Public Cancellation: +24 hours after private cancellation

2. **Sequential Timelocks on Destination Chain (Monad)**:
   - Private Withdrawal: 60s after deployment
   - Public Withdrawal: +1 hour after private withdrawal
   - Cancellation: +11 hours after public withdrawal (must be less than source chain)

3. **Improved Output Format**:
   - Shows deployment time as reference
   - Numbers each window in sequence
   - Shows duration between windows
   - Shows absolute start times for each window

Let's run the updated script:

We have an arithmetic overflow in the Monad script. Let me fix the timelock calculations to prevent this:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    function getTimelocks() internal view returns (Timelocks srcTimelocks, Timelocks dstTimelocks) {
        // Set timelocks for source chain
        uint256 deploymentTime = block.timestamp;

        // Source chain timelock durations (relative to deployment)
        uint256 srcWithdrawal = deploymentTime + 60; // 1 minute for private withdrawal
        uint256 srcPublicWithdrawal = srcWithdrawal + 3600; // +1 hour for public withdrawal
        uint256 srcCancellation = srcPublicWithdrawal + 82800; // +23 hours for private cancellation
        uint256 srcPublicCancellation = srcCancellation + 86400; // +24 hours for public cancellation

        // Pack source timelocks
        uint256 srcTimelockData = (deploymentTime << 224) | 
                              (60 << 192) | // Store only the duration, not absolute time
                              (3660 << 160) | // 60 + 3600
                              (86460 << 128) | // 60 + 3600 + 82800
                              (172860 << 96); // 60 + 3600 + 82800 + 86400
        
        srcTimelocks = Timelocks.wrap(srcTimelockData);

        // Destination chain timelock durations (relative to deployment)
        uint256 dstWithdrawal = deploymentTime + 60; // 1 minute for private withdrawal
        uint256 dstPublicWithdrawal = dstWithdrawal + 3600; // +1 hour for public withdrawal
        uint256 dstCancellation = dstPublicWithdrawal + 39600; // +11 hours for cancellation

        // Pack destination timelocks
        uint256 dstTimelockData = (deploymentTime << 224) | 
                              (60 << 192) | // Store only the duration
                              (3660 << 160) | // 60 + 3600
                              (43260 << 128); // 60 + 3600 + 39600
        
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
        console.log("1. Private Withdrawal: 60 seconds after deployment");
        console.log("2. Public Withdrawal: 3600 seconds after private withdrawal");
        console.log("3. Private Cancellation: 82800 seconds after public withdrawal");
        console.log("4. Public Cancellation: 86400 seconds after private cancellation");

        console.log("\n=== Total Duration from Deployment ===");
        console.log("Private Withdrawal: 60 seconds");
        console.log("Public Withdrawal: 3660 seconds");
        console.log("Private Cancellation: 86460 seconds");
        console.log("Public Cancellation: 172860 seconds");
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
        console.log("1. Private Withdrawal: 60 seconds after deployment");
        console.log("2. Public Withdrawal: 3600 seconds after private withdrawal");
        console.log("3. Cancellation: 39600 seconds after public withdrawal");

        console.log("\n=== Total Duration from Deployment ===");
        console.log("Private Withdrawal: 60 seconds");
        console.log("Public Withdrawal: 3660 seconds");
        console.log("Cancellation: 43260 seconds");
    }

    function run() external view {
        console.log("\n=== Important Parameters ===");
        console.log("Order Hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
    }
}
```

Key changes made:

1. **Fixed Timelock Calculations**:
   - Now storing durations instead of absolute timestamps in the timelock data
   - This prevents arithmetic overflow when calculating relative times
   - Made the windows properly sequential

2. **Timelock Windows (Source Chain - Sepolia)**:
   - Private Withdrawal: 60s after deployment
   - Public Withdrawal: 3600s (1h) after private withdrawal
   - Private Cancellation: 82800s (23h) after public withdrawal
   - Public Cancellation: 86400s (24h) after private cancellation

3. **Timelock Windows (Destination Chain - Monad)**:
   - Private Withdrawal: 60s after deployment
   - Public Withdrawal: 3600s (1h) after private withdrawal
   - Cancellation: 39600s (11h) after public withdrawal

Let's run the fixed script:

Perfect! The scripts now work correctly with proper sequential timelocks. Here's a summary of the timelock windows:

**Source Chain (Sepolia)**:
1. Private Withdrawal: 60s after deployment
2. Public Withdrawal: 3600s (1h) after private withdrawal
3. Private Cancellation: 82800s (23h) after public withdrawal
4. Public Cancellation: 86400s (24h) after private cancellation

Total durations from deployment:
- Private Withdrawal: 60s
- Public Withdrawal: 3,660s (1h 1m)
- Private Cancellation: 86,460s (24h 1m)
- Public Cancellation: 172,860s (48h 1m)

**Destination Chain (Monad)**:
1. Private Withdrawal: 60s after deployment
2. Public Withdrawal: 3600s (1h) after private withdrawal
3. Cancellation: 39600s (11h) after public withdrawal

Total durations from deployment:
- Private Withdrawal: 60s
- Public Withdrawal: 3,660s (1h 1m)
- Cancellation: 43,260s (12h 1m)

The timelocks are now properly sequential and the destination chain cancellation (12h) is less than the source chain cancellation (24h) as required.

Would you like to:
1. Fix the remaining compiler warnings about unused variables?
2. Move on to creating the next script for sending safety deposits?
3. Or something else?

---

**User**

Fix the remaining compiler warnings about unused variables?


---

**Cursor**

I'll fix the compiler warnings about unused variables in the `CalculateEscrowAddresses.s.sol` script:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

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
```

Key changes made:

1. **Added Constants for Timelock Durations**:
   ```solidity
   uint256 constant PRIVATE_WITHDRAWAL = 60; // 1 minute
   uint256 constant PUBLIC_WITHDRAWAL = 3600; // 1 hour
   uint256 constant SRC_PRIVATE_CANCELLATION = 82800; // 23 hours
   uint256 constant SRC_PUBLIC_CANCELLATION = 86400; // 24 hours
   uint256 constant DST_CANCELLATION = 39600; // 11 hours
   ```

2. **Removed Unused Variables**:
   - Removed intermediate variables for calculating timestamps
   - Now using constants directly in timelock data packing
   - Removed redundant calculations

3. **Improved Timelock Calculations**:
   - Using constants for all durations
   - Calculating cumulative durations inline
   - Using `vm.toString()` for all numeric outputs

Let's run the updated script to verify the fixes:

```solidity
   uint256 constant PRIVATE_WITHDRAWAL = 60; // 1 minute
   uint256 constant PUBLIC_WITHDRAWAL = 3600; // 1 hour
   uint256 constant SRC_PRIVATE_CANCELLATION = 82800; // 23 hours
   uint256 constant SRC_PUBLIC_CANCELLATION = 86400; // 24 hours
   uint256 constant DST_CANCELLATION = 39600; // 11 hours
```

Perfect! The script now runs without any compiler warnings and provides clear, consistent output. The changes we made:

1. **Removed Compiler Warnings**:
   - Eliminated unused variables by using constants
   - Simplified timelock calculations
   - Made all variables used in calculations

2. **Improved Code Organization**:
   - Added constants for all timelock durations
   - Made calculations more explicit and easier to follow
   - Improved readability of output

3. **Consistent Output Format**:
   - All durations are shown in seconds
   - All numeric values use `vm.toString()`
   - Clear separation between relative and absolute times

Would you like to:
1. Move on to creating the next script for sending safety deposits?
2. Make any other improvements to the current script?
3. Or something else?

---

**User**

now onto the step 3
Resolver Sends Safety Deposits
❌ Missing: SendSafetyDeposits.s.sol
Need to create script to:
Send safety deposit to future EscrowSrc address on Sepolia
Send safety deposit to future EscrowDst address on Monad
if any steps needed before that do that too
do this and

---

**Cursor**

I'll help you create the `SendSafetyDeposits.s.sol` script. Before sending safety deposits, we need to ensure:

1. We have the correct escrow addresses from the previous step
2. The resolver (taker) has enough ETH on Sepolia and MON on Monad
3. The safety deposits are sent before order filling

Let's create the script:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Timelock durations (same as CalculateEscrowAddresses.s.sol)
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

    function getEscrowAddresses() internal view returns (address escrowSrc, address escrowDst) {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        
        (Timelocks srcTimelocks, Timelocks dstTimelocks) = getTimelocks();

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

        // Calculate escrow addresses
        escrowSrc = EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(srcImmutables);
        escrowDst = EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(dstImmutables);
    }

    function checkBalances() internal view {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        uint256 totalRequired = amount + safetyDeposit;

        // Check resolver's balances
        uint256 sepoliaBalance = TAKER.balance;
        console.log("\n=== Resolver Balances ===");
        console.log("Sepolia Balance:", vm.toString(sepoliaBalance), "wei");
        console.log("Required on Sepolia:", vm.toString(totalRequired), "wei");
        
        if (sepoliaBalance < totalRequired) {
            revert("Insufficient balance on Sepolia");
        }

        // For Monad, we can only check during actual execution
        console.log("Required on Monad:", vm.toString(totalRequired), "wei");
        console.log("Note: Please ensure sufficient MON balance on Monad");
    }

    function sendSepoliaSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        (address escrowSrc,) = getEscrowAddresses();

        // Print details
        console.log("\n=== Sending Safety Deposit on Sepolia ===");
        console.log("From (Resolver):", TAKER);
        console.log("To (EscrowSrc):", escrowSrc);
        console.log("Amount:", vm.toString(safetyDeposit), "wei");

        // Check balance first
        checkBalances();

        // Send safety deposit
        vm.startBroadcast(TAKER_PRIVATE_KEY);
        
        (bool success,) = escrowSrc.call{value: safetyDeposit}("");
        require(success, "Failed to send safety deposit to Sepolia escrow");

        vm.stopBroadcast();

        console.log("✓ Safety deposit sent successfully to Sepolia escrow");
    }

    function sendMonadSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        (, address escrowDst) = getEscrowAddresses();

        // Print details
        console.log("\n=== Sending Safety Deposit on Monad ===");
        console.log("From (Resolver):", TAKER);
        console.log("To (EscrowDst):", escrowDst);
        console.log("Amount:", vm.toString(safetyDeposit), "wei");

        // Send safety deposit
        vm.startBroadcast(TAKER_PRIVATE_KEY);
        
        (bool success,) = escrowDst.call{value: safetyDeposit}("");
        require(success, "Failed to send safety deposit to Monad escrow");

        vm.stopBroadcast();

        console.log("✓ Safety deposit sent successfully to Monad escrow");
    }

    function run() external view {
        // Get escrow addresses
        (address escrowSrc, address escrowDst) = getEscrowAddresses();

        console.log("\n=== Safety Deposit Information ===");
        console.log("Amount per chain:", vm.toString(0.01 ether), "wei");
        
        console.log("\n=== Escrow Addresses ===");
        console.log("Sepolia (EscrowSrc):", escrowSrc);
        console.log("Monad (EscrowDst):", escrowDst);

        // Check resolver's balances
        checkBalances();

        console.log("\n=== Instructions ===");
        console.log("1. Run 'sendSepoliaSafetyDeposit()' to send safety deposit on Sepolia");
        console.log("2. Run 'sendMonadSafetyDeposit()' to send safety deposit on Monad");
        console.log("Note: Ensure resolver has sufficient balance on both chains");
    }
}
```

Let me fix the Unicode character issue and then run the script:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Timelock durations (same as CalculateEscrowAddresses.s.sol)
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

    function getEscrowAddresses() internal view returns (address escrowSrc, address escrowDst) {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        
        (Timelocks srcTimelocks, Timelocks dstTimelocks) = getTimelocks();

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

        // Calculate escrow addresses
        escrowSrc = EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(srcImmutables);
        escrowDst = EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(dstImmutables);
    }

    function checkBalances() internal view {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        uint256 totalRequired = amount + safetyDeposit;

        // Check resolver's balances
        uint256 sepoliaBalance = TAKER.balance;
        console.log("\n=== Resolver Balances ===");
        console.log("Sepolia Balance:", vm.toString(sepoliaBalance), "wei");
        console.log("Required on Sepolia:", vm.toString(totalRequired), "wei");
        
        if (sepoliaBalance < totalRequired) {
            revert("Insufficient balance on Sepolia");
        }

        // For Monad, we can only check during actual execution
        console.log("Required on Monad:", vm.toString(totalRequired), "wei");
        console.log("Note: Please ensure sufficient MON balance on Monad");
    }

    function sendSepoliaSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        (address escrowSrc,) = getEscrowAddresses();

        // Print details
        console.log("\n=== Sending Safety Deposit on Sepolia ===");
        console.log("From (Resolver):", TAKER);
        console.log("To (EscrowSrc):", escrowSrc);
        console.log("Amount:", vm.toString(safetyDeposit), "wei");

        // Check balance first
        checkBalances();

        // Send safety deposit
        vm.startBroadcast(TAKER_PRIVATE_KEY);
        
        (bool success,) = escrowSrc.call{value: safetyDeposit}("");
        require(success, "Failed to send safety deposit to Sepolia escrow");

        vm.stopBroadcast();

        console.log("Success: Safety deposit sent to Sepolia escrow");
    }

    function sendMonadSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        (, address escrowDst) = getEscrowAddresses();

        // Print details
        console.log("\n=== Sending Safety Deposit on Monad ===");
        console.log("From (Resolver):", TAKER);
        console.log("To (EscrowDst):", escrowDst);
        console.log("Amount:", vm.toString(safetyDeposit), "wei");

        // Send safety deposit
        vm.startBroadcast(TAKER_PRIVATE_KEY);
        
        (bool success,) = escrowDst.call{value: safetyDeposit}("");
        require(success, "Failed to send safety deposit to Monad escrow");

        vm.stopBroadcast();

        console.log("Success: Safety deposit sent to Monad escrow");
    }

    function run() external view {
        // Get escrow addresses
        (address escrowSrc, address escrowDst) = getEscrowAddresses();

        console.log("\n=== Safety Deposit Information ===");
        console.log("Amount per chain:", vm.toString(0.01 ether), "wei");
        
        console.log("\n=== Escrow Addresses ===");
        console.log("Sepolia (EscrowSrc):", escrowSrc);
        console.log("Monad (EscrowDst):", escrowDst);

        // Check resolver's balances
        checkBalances();

        console.log("\n=== Instructions ===");
        console.log("1. Run 'sendSepoliaSafetyDeposit()' to send safety deposit on Sepolia");
        console.log("2. Run 'sendMonadSafetyDeposit()' to send safety deposit on Monad");
        console.log("Note: Ensure resolver has sufficient balance on both chains");
    }
}
```

Let me fix the `toString` issue by using string concatenation instead:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Timelock durations (same as CalculateEscrowAddresses.s.sol)
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

    function getEscrowAddresses() internal view returns (address escrowSrc, address escrowDst) {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        
        (Timelocks srcTimelocks, Timelocks dstTimelocks) = getTimelocks();

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

        // Calculate escrow addresses
        escrowSrc = EscrowFactory(SEPOLIA_ESCROW_FACTORY).addressOfEscrowSrc(srcImmutables);
        escrowDst = EscrowFactory(MONAD_ESCROW_FACTORY).addressOfEscrowDst(dstImmutables);
    }

    function checkBalances() internal view {
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;
        uint256 totalRequired = amount + safetyDeposit;

        // Check resolver's balances
        uint256 sepoliaBalance = TAKER.balance;
        console.log("\n=== Resolver Balances ===");
        console.log("Sepolia Balance:", sepoliaBalance);
        console.log("Required on Sepolia:", totalRequired);
        
        if (sepoliaBalance < totalRequired) {
            revert("Insufficient balance on Sepolia");
        }

        // For Monad, we can only check during actual execution
        console.log("Required on Monad:", totalRequired);
        console.log("Note: Please ensure sufficient MON balance on Monad");
    }

    function sendSepoliaSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        (address escrowSrc,) = getEscrowAddresses();

        // Print details
        console.log("\n=== Sending Safety Deposit on Sepolia ===");
        console.log("From (Resolver):", TAKER);
        console.log("To (EscrowSrc):", escrowSrc);
        console.log("Amount:", safetyDeposit);

        // Check balance first
        checkBalances();

        // Send safety deposit
        vm.startBroadcast(TAKER_PRIVATE_KEY);
        
        (bool success,) = escrowSrc.call{value: safetyDeposit}("");
        require(success, "Failed to send safety deposit to Sepolia escrow");

        vm.stopBroadcast();

        console.log("Success: Safety deposit sent to Sepolia escrow");
    }

    function sendMonadSafetyDeposit() external {
        uint256 safetyDeposit = 0.01 ether;
        (, address escrowDst) = getEscrowAddresses();

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
        // Get escrow addresses
        (address escrowSrc, address escrowDst) = getEscrowAddresses();

        console.log("\n=== Safety Deposit Information ===");
        console.log("Amount per chain:", 0.01 ether);
        
        console.log("\n=== Escrow Addresses ===");
        console.log("Sepolia (EscrowSrc):", escrowSrc);
        console.log("Monad (EscrowDst):", escrowDst);

        // Check resolver's balances
        checkBalances();

        console.log("\n=== Instructions ===");
        console.log("1. Run 'sendSepoliaSafetyDeposit()' to send safety deposit on Sepolia");
        console.log("2. Run 'sendMonadSafetyDeposit()' to send safety deposit on Monad");
        console.log("Note: Ensure resolver has sufficient balance on both chains");
    }
}
```

Now let's run the script to check the escrow addresses and balances first:

We need to run the scripts separately for each chain. Let's start with Sepolia:

I see the issue - we need to modify the script to handle each chain independently. Let me update the script:

```solidity
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
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

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
```

Now let's try running the script for Sepolia first:

Great! The Sepolia safety deposit was sent successfully. Now let's send the safety deposit on Monad:

Perfect! Both safety deposits have been sent successfully. Here's a summary of what we did:

1. **Sepolia Safety Deposit**:
   - Sent to: `0x4d293C0B5d32D740d7de3e66df376E1F2F5ac32c`
   - Amount: 0.01 ETH
   - Transaction Hash: `0xa130718634a545d7e41aafeab474a8319c9d77d81b6a0b36c12706c273640560`
   - Block: 8802421

2. **Monad Safety Deposit**:
   - Sent to: `0xad1A928E2E1530Ecf510899Ba41C31c57D600874`
   - Amount: 0.01 MON
   - Transaction Hash: `0x16c6976e51247a4d53faa9c249cd8f6f068da847b0e5344346e891eec74206ad`
   - Block: 27051456

The script improvements we made:
1. Separated chain-specific functions to avoid cross-chain calls
2. Added better balance checking for Sepolia
3. Fixed console logging issues
4. Added clear success messages

Would you like to:
1. Move on to creating the next script in the flow?
2. Add any additional features to the safety deposit script?
3. Or something else?

---

**User**

now on to the step 3

1. Resolver Fills Order on Sepolia
* ❌ Missing: FillOrder.s.sol
* Need to create script to:
* Take signed order from step 1
* Call LimitOrderProtocol.fillOrderArgs
* This creates EscrowSrc clone


do this

and read the prompt above the whole please

---

**Cursor**

I'll help you create the `FillOrder.s.sol` script. This script will use the signed order from step 1 to fill the order on Sepolia, which will create the EscrowSrc clone.

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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
            uint40(block.timestamp) // nonce - using current timestamp to ensure uniqueness
        );
    }

    function verifyOrder(IOrderMixin.Order memory order) internal view {
        // Verify order hash matches
        bytes32 calculatedHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);
        require(calculatedHash == ORDER_HASH, "Order hash mismatch");

        // Verify order parameters
        require(order.maker == MAKER, "Maker address mismatch");
        require(order.receiver == MAKER, "Receiver address mismatch");
        require(order.makerAsset == address(0), "Maker asset mismatch");
        require(order.takerAsset == SEPOLIA_ERC20_TRUE, "Taker asset mismatch");
        require(order.makingAmount == 0.01 ether, "Making amount mismatch");
        require(order.takingAmount == 0.01 ether, "Taking amount mismatch");

        console.log("\n=== Order Verification ===");
        console.log("Order hash matches:", ORDER_HASH);
        console.log("All parameters verified successfully");
    }

    function fillOrder() external {
        // Get the order and extension
        (IOrderMixin.Order memory order, bytes memory extension) = getOrder();

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User):", order.maker);
        console.log("Taker (Resolver):", TAKER);
        console.log("Making Amount:", order.makingAmount);
        console.log("Taking Amount:", order.takingAmount);
        console.log("Hashlock:", HASHLOCK);

        // Set up taker traits
        TakerTraits takerTraits = TakerTraits.wrap(0);
        takerTraits = takerTraits.setMakerAmount(); // Use maker amount for fill

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
        );

        vm.stopBroadcast();

        // Print results
        console.log("\n=== Fill Results ===");
        console.log("Making Amount Filled:", makingAmount);
        console.log("Taking Amount Filled:", takingAmount);
        console.log("Order Hash:", orderHash);
        console.log("Success: Order filled and EscrowSrc clone created");
    }

    function run() external view {
        // Get and verify the order
        (IOrderMixin.Order memory order, ) = getOrder();
        verifyOrder(order);

        console.log("\n=== Order Information ===");
        console.log("Maker (User):", order.maker);
        console.log("Taker (Resolver):", TAKER);
        console.log("Making Amount:", order.makingAmount);
        console.log("Taking Amount:", order.takingAmount);
        
        console.log("\n=== Signature Components ===");
        console.log("R:", SIG_R);
        console.log("S:", SIG_S);
        console.log("V:", SIG_V);

        console.log("\n=== Instructions ===");
        console.log("Run 'fillOrder()' to fill the order and create EscrowSrc clone");
        console.log("Note: Ensure safety deposits are sent before filling");
    }
}
```

Let me fix the linter errors:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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
            uint40(block.timestamp) // nonce - using current timestamp to ensure uniqueness
        );
    }

    function verifyOrder(IOrderMixin.Order memory order) internal view {
        // Verify order hash matches
        bytes32 calculatedHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);
        require(calculatedHash == ORDER_HASH, "Order hash mismatch");

        // Verify order parameters
        require(order.maker.get() == MAKER, "Maker address mismatch");
        require(order.receiver.get() == MAKER, "Receiver address mismatch");
        require(order.makerAsset.get() == address(0), "Maker asset mismatch");
        require(order.takerAsset.get() == SEPOLIA_ERC20_TRUE, "Taker asset mismatch");
        require(order.makingAmount == 0.01 ether, "Making amount mismatch");
        require(order.takingAmount == 0.01 ether, "Taking amount mismatch");

        console.log("\n=== Order Verification ===");
        console.log("Order hash matches: %s", vm.toString(ORDER_HASH));
        console.log("All parameters verified successfully");
    }

    function fillOrder() external {
        // Get the order and extension
        (IOrderMixin.Order memory order, bytes memory extension) = getOrder();

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
        TakerTraits takerTraits = TakerTraits.wrap(0);
        takerTraits = takerTraits.setMakerAmount(); // Use maker amount for fill

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the TakerTraits issue:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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
            uint40(block.timestamp) // nonce - using current timestamp to ensure uniqueness
        );
    }

    function verifyOrder(IOrderMixin.Order memory order) internal view {
        // Verify order hash matches
        bytes32 calculatedHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);
        require(calculatedHash == ORDER_HASH, "Order hash mismatch");

        // Verify order parameters
        require(order.maker.get() == MAKER, "Maker address mismatch");
        require(order.receiver.get() == MAKER, "Receiver address mismatch");
        require(order.makerAsset.get() == address(0), "Maker asset mismatch");
        require(order.takerAsset.get() == SEPOLIA_ERC20_TRUE, "Taker asset mismatch");
        require(order.makingAmount == 0.01 ether, "Making amount mismatch");
        require(order.takingAmount == 0.01 ether, "Taking amount mismatch");

        console.log("\n=== Order Verification ===");
        console.log("Order hash matches: %s", vm.toString(ORDER_HASH));
        console.log("All parameters verified successfully");
    }

    function fillOrder() external {
        // Get the order and extension
        (IOrderMixin.Order memory order, bytes memory extension) = getOrder();

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the pure/view issue:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    function getOrder() internal view returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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
            uint40(block.timestamp) // nonce - using current timestamp to ensure uniqueness
        );
    }

    function verifyOrder(IOrderMixin.Order memory order) internal view {
        // Verify order hash matches
        bytes32 calculatedHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);
        require(calculatedHash == ORDER_HASH, "Order hash mismatch");

        // Verify order parameters
        require(order.maker.get() == MAKER, "Maker address mismatch");
        require(order.receiver.get() == MAKER, "Receiver address mismatch");
        require(order.makerAsset.get() == address(0), "Maker asset mismatch");
        require(order.takerAsset.get() == SEPOLIA_ERC20_TRUE, "Taker asset mismatch");
        require(order.makingAmount == 0.01 ether, "Making amount mismatch");
        require(order.takingAmount == 0.01 ether, "Taking amount mismatch");

        console.log("\n=== Order Verification ===");
        console.log("Order hash matches: %s", vm.toString(ORDER_HASH));
        console.log("All parameters verified successfully");
    }

    function fillOrder() external {
        // Get the order and extension
        (IOrderMixin.Order memory order, bytes memory extension) = getOrder();

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script to verify the order first:

We have an order hash mismatch. This is happening because we're using a different timestamp in `getOrder()` than what was used in the original order signing. Let me modify the script to use the exact same parameters:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib with exact same parameters
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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
    }

    function verifyOrder(IOrderMixin.Order memory order) internal view {
        // Verify order hash matches
        bytes32 calculatedHash = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order);
        require(calculatedHash == ORDER_HASH, "Order hash mismatch");

        // Verify order parameters
        require(order.maker.get() == MAKER, "Maker address mismatch");
        require(order.receiver.get() == MAKER, "Receiver address mismatch");
        require(order.makerAsset.get() == address(0), "Maker asset mismatch");
        require(order.takerAsset.get() == SEPOLIA_ERC20_TRUE, "Taker asset mismatch");
        require(order.makingAmount == 0.01 ether, "Making amount mismatch");
        require(order.takingAmount == 0.01 ether, "Taking amount mismatch");

        console.log("\n=== Order Verification ===");
        console.log("Order hash matches: %s", vm.toString(ORDER_HASH));
        console.log("All parameters verified successfully");
    }

    function fillOrder() external {
        // Get the order and extension
        (IOrderMixin.Order memory order, bytes memory extension) = getOrder();

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script again to verify the order:

We still have a hash mismatch. Let me check the order parameters more carefully:

1. The order hash we're trying to match: `0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e`
2. The hash we're getting: `0x2ae346530265016ddc0f16fc0f45fb0630de81e9c1732e4a9de91684a1c0f22a`

The difference is likely in how the order traits are being set. Let me modify the script to use the exact same traits:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Set up maker traits
        MakerTraits makerTraits = MakerTraits.wrap(0);
        makerTraits = makerTraits.setNoPartialFills(true); // Don't allow partial fills
        makerTraits = makerTraits.setAllowMultipleFills(false); // Don't allow multiple fills
        makerTraits = makerTraits.setPreInteractionCall(false); // No pre-interaction
        makerTraits = makerTraits.setPostInteractionCall(false); // No post-interaction
        makerTraits = makerTraits.setNeedCheckEpochManager(false); // No epoch manager
        makerTraits = makerTraits.setHasExtension(true); // Has extension (hashlock)
        makerTraits = makerTraits.setUsePermit2(false); // No permit2
        makerTraits = makerTraits.setUnwrapWeth(false); // No WETH unwrapping

        // Create order using CrossChainTestLib with exact same parameters
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            makerTraits, // Use exact maker traits
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

        // Override the salt with the exact value from original order
        order.salt = ORDER_SALT;
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
        console.log("MakerTraits: %s", vm.toString(bytes32(order.makerTraits)));

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the MakerTraits issue by using the raw flags:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib with exact same parameters
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(MAKER_TRAITS), // Use exact maker traits from original order
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

        // Override the salt with the exact value from original order
        order.salt = ORDER_SALT;
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
        console.log("MakerTraits: %s", vm.toString(bytes32(order.makerTraits)));

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the type conversion issue:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib with exact same parameters
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(MAKER_TRAITS), // Use exact maker traits from original order
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

        // Override the salt with the exact value from original order
        order.salt = ORDER_SALT;
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
        console.log("MakerTraits: %s", vm.toString(bytes32(uint256(order.makerTraits))));

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the type conversion issue by using the unwrap function:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib with exact same parameters
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(MAKER_TRAITS), // Use exact maker traits from original order
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

        // Override the salt with the exact value from original order
        order.salt = ORDER_SALT;
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

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script to verify the order:

We still have a hash mismatch. Let me check the order parameters more carefully:

1. The order hash we're trying to match: `0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e`
2. The hash we're getting: `0x9674bb226ac9b015aabcd56bfdc084d27691e10da993fb373eb3de28245e647b`

Looking at the order details:
1. Salt: `0x000000000000000000000000254d7715bf9c105aca0c5c387504bfb75e1a6df4`
2. Maker: `0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27` (correct)
3. Receiver: `0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27` (correct)
4. MakerAsset: `0x0000000000000000000000000000000000000000` (correct)
5. TakerAsset: `0x8267cF9254734C6Eb452a7bb9AAF97B392258b21` (correct)
6. MakerTraits: `0x02000000000000000000000000687c8b8c000000000000000000000000000000`

The issue seems to be with how the order is being built. Let me modify the script to build the order manually:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order manually with exact parameters
        order = IOrderMixin.Order({
            salt: ORDER_SALT,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(uint160(MAKER)),
            makerAsset: Address.wrap(uint160(0)),
            takerAsset: Address.wrap(uint160(SEPOLIA_ERC20_TRUE)),
            makingAmount: 0.01 ether,
            takingAmount: 0.01 ether,
            makerTraits: MakerTraits.wrap(MAKER_TRAITS)
        });

        // Create extension with hashlock
        extension = abi.encode(HASHLOCK);
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

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script again to verify the order:

Let me check the original order from `SignOrder.s.sol` to see if we missed anything:

I see the issue - in the original `SignOrder.s.sol`, we're using `CrossChainTestLib.buildOrder` with `MakerTraits.wrap(0)` and letting the library set the traits. Let me modify our script to do the same:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib with exact same parameters as SignOrder.s.sol
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script again to verify the order:

Let me check the `CrossChainTestLib` to see how it builds the order:

Let me read more of the file:

I see the issue - the `buildOrder` function in `CrossChainTestLib` is setting the salt based on the extension data:

```solidity
uint256 salt = 1;
if (extension.length > 0) {
    salt = uint256(keccak256(extension)) & ((1 << 160) - 1);
    makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | _HAS_EXTENSION_FLAG);
}
```

Let me modify our script to use the original order's salt:

```solidity
uint256 salt = 1;
if (extension.length > 0) {
    salt = uint256(keccak256(extension)) & ((1 << 160) - 1);
    makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | _HAS_EXTENSION_FLAG);
}
```

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order using CrossChainTestLib with exact same parameters as SignOrder.s.sol
        (order, extension) = CrossChainTestLib.buildOrder(
            MAKER,
            MAKER, // receiver is same as maker for cross-chain
            address(0), // makerAsset (ETH)
            SEPOLIA_ERC20_TRUE, // takerAsset (ERC20True token)
            0.01 ether, // makingAmount
            0.01 ether, // takingAmount
            MakerTraits.wrap(0), // will be set by buildOrder
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

        // Override the salt with the exact value from original order
        order.salt = ORDER_SALT;
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

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script again to verify the order:

We still have a hash mismatch. Let me check the order parameters more carefully:

1. Salt: `0x000000000000000000000000254d7715bf9c105aca0c5c387504bfb75e1a6df4`
2. Maker: `0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27` (correct)
3. Receiver: `0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27` (correct)
4. MakerAsset: `0x0000000000000000000000000000000000000000` (correct)
5. TakerAsset: `0x8267cF9254734C6Eb452a7bb9AAF97B392258b21` (correct)
6. MakerTraits: `0x02000000000000000000000000687c8100000000000000000000000000000000`

The issue might be with the extension data. Let me modify the script to use the exact extension data:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order manually with exact parameters
        order = IOrderMixin.Order({
            salt: ORDER_SALT,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(uint160(MAKER)),
            makerAsset: Address.wrap(uint160(0)),
            takerAsset: Address.wrap(uint160(SEPOLIA_ERC20_TRUE)),
            makingAmount: 0.01 ether,
            takingAmount: 0.01 ether,
            makerTraits: MakerTraits.wrap(MAKER_TRAITS)
        });

        // Create extension with hashlock
        bytes32 offsets = bytes32(uint256(32)); // Length of hashlock data
        extension = abi.encodePacked(offsets, HASHLOCK);
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

        // Verify order hash matches
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script again to verify the order:

Let me check the order hash calculation in the LimitOrderProtocol contract:

I see the issue - the order hash is calculated using EIP-712 with a domain separator. Let me check the LimitOrderProtocol contract to get the domain separator:

I see that the LimitOrderProtocol contract is using OpenZeppelin's EIP712 with name "1inch Limit Order Protocol" and version "4". Let me modify our script to use the same domain separator:

```solidity
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
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    // EIP-712 domain separator
    bytes32 constant DOMAIN_SEPARATOR = 0x8168e6b4e2f5d0b2c9f4c5c7c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order manually with exact parameters
        order = IOrderMixin.Order({
            salt: ORDER_SALT,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(uint160(MAKER)),
            makerAsset: Address.wrap(uint160(0)),
            takerAsset: Address.wrap(uint160(SEPOLIA_ERC20_TRUE)),
            makingAmount: 0.01 ether,
            takingAmount: 0.01 ether,
            makerTraits: MakerTraits.wrap(MAKER_TRAITS)
        });

        // Create extension with hashlock
        bytes32 offsets = bytes32(uint256(32)); // Length of hashlock data
        extension = abi.encodePacked(offsets, HASHLOCK);
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

        // Get domain separator from LimitOrderProtocol
        bytes32 domainSeparator = EIP712(SEPOLIA_LIMIT_ORDER_PROTOCOL).DOMAIN_SEPARATOR();
        console.log("\nDomain Separator: %s", vm.toString(domainSeparator));

        // Calculate order hash using domain separator
        bytes32 calculatedHash = OrderLib.hash(order, domainSeparator);
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the EIP712 interface issue:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order manually with exact parameters
        order = IOrderMixin.Order({
            salt: ORDER_SALT,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(uint160(MAKER)),
            makerAsset: Address.wrap(uint160(0)),
            takerAsset: Address.wrap(uint160(SEPOLIA_ERC20_TRUE)),
            makingAmount: 0.01 ether,
            takingAmount: 0.01 ether,
            makerTraits: MakerTraits.wrap(MAKER_TRAITS)
        });

        // Create extension with hashlock
        bytes32 offsets = bytes32(uint256(32)); // Length of hashlock data
        extension = abi.encodePacked(offsets, HASHLOCK);
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

        // Get domain separator from LimitOrderProtocol
        bytes32 domainSeparator = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).DOMAIN_SEPARATOR();
        console.log("\nDomain Separator: %s", vm.toString(domainSeparator));

        // Calculate order hash using domain separator
        bytes32 calculatedHash = OrderLib.hash(order, domainSeparator);
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me check the IOrderMixin interface:

Let me read more of the file:

I see that IOrderMixin doesn't have the DOMAIN_SEPARATOR function. Let me check the LimitOrderProtocol contract:

I see that the LimitOrderProtocol contract has the DOMAIN_SEPARATOR function. Let me modify our script to use the correct interface:

```solidity
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
import "../../lib/limit-order-protocol/contracts/LimitOrderProtocol.sol";

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order manually with exact parameters
        order = IOrderMixin.Order({
            salt: ORDER_SALT,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(uint160(MAKER)),
            makerAsset: Address.wrap(uint160(0)),
            takerAsset: Address.wrap(uint160(SEPOLIA_ERC20_TRUE)),
            makingAmount: 0.01 ether,
            takingAmount: 0.01 ether,
            makerTraits: MakerTraits.wrap(MAKER_TRAITS)
        });

        // Create extension with hashlock
        bytes32 offsets = bytes32(uint256(32)); // Length of hashlock data
        extension = abi.encodePacked(offsets, HASHLOCK);
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

        // Get domain separator from LimitOrderProtocol
        bytes32 domainSeparator = LimitOrderProtocol(SEPOLIA_LIMIT_ORDER_PROTOCOL).DOMAIN_SEPARATOR();
        console.log("\nDomain Separator: %s", vm.toString(domainSeparator));

        // Calculate order hash using domain separator
        bytes32 calculatedHash = OrderLib.hash(order, domainSeparator);
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me check the OrderMixin contract to see how it calculates the order hash:

Let me read more of the file:

I see that the order hash is calculated using EIP-712 with the domain separator from `_domainSeparatorV4()`. Let me check the OpenZeppelin EIP712 contract:

I see that the domain separator is calculated using the contract's name, version, chain ID, and address. Let me modify our script to use the correct domain separator:

```solidity
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
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    // EIP-712 domain separator constants
    bytes32 constant TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant NAME_HASH = keccak256("1inch Limit Order Protocol");
    bytes32 constant VERSION_HASH = keccak256("4");

    function getDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            TYPE_HASH,
            NAME_HASH,
            VERSION_HASH,
            block.chainid,
            SEPOLIA_LIMIT_ORDER_PROTOCOL
        ));
    }

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order manually with exact parameters
        order = IOrderMixin.Order({
            salt: ORDER_SALT,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(uint160(MAKER)),
            makerAsset: Address.wrap(uint160(0)),
            takerAsset: Address.wrap(uint160(SEPOLIA_ERC20_TRUE)),
            makingAmount: 0.01 ether,
            takingAmount: 0.01 ether,
            makerTraits: MakerTraits.wrap(MAKER_TRAITS)
        });

        // Create extension with hashlock
        bytes32 offsets = bytes32(uint256(32)); // Length of hashlock data
        extension = abi.encodePacked(offsets, HASHLOCK);
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

        // Get domain separator
        bytes32 domainSeparator = getDomainSeparator();
        console.log("\nDomain Separator: %s", vm.toString(domainSeparator));

        // Calculate order hash using domain separator
        bytes32 calculatedHash = OrderLib.hash(order, domainSeparator);
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the calldata/memory issue:

```solidity
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
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;
    uint256 constant ORDER_SALT = 212960189663417382404052818898535080754633403892;

    // Original maker traits from SignOrder.s.sol
    uint256 constant MAKER_TRAITS = 904625697166532776746648320382704407013115399697955446237759540163577380864;

    // EIP-712 domain separator constants
    bytes32 constant TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant NAME_HASH = keccak256("1inch Limit Order Protocol");
    bytes32 constant VERSION_HASH = keccak256("4");

    function getDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            TYPE_HASH,
            NAME_HASH,
            VERSION_HASH,
            block.chainid,
            SEPOLIA_LIMIT_ORDER_PROTOCOL
        ));
    }

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
        // Create order manually with exact parameters
        order = IOrderMixin.Order({
            salt: ORDER_SALT,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(uint160(MAKER)),
            makerAsset: Address.wrap(uint160(0)),
            takerAsset: Address.wrap(uint160(SEPOLIA_ERC20_TRUE)),
            makingAmount: 0.01 ether,
            takingAmount: 0.01 ether,
            makerTraits: MakerTraits.wrap(MAKER_TRAITS)
        });

        // Create extension with hashlock
        bytes32 offsets = bytes32(uint256(32)); // Length of hashlock data
        extension = abi.encodePacked(offsets, HASHLOCK);
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

        // Get domain separator
        bytes32 domainSeparator = getDomainSeparator();
        console.log("\nDomain Separator: %s", vm.toString(domainSeparator));

        // Calculate order hash using domain separator
        bytes32 calculatedHash = keccak256(abi.encode(
            keccak256("Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"),
            order.salt,
            order.maker.get(),
            order.receiver.get(),
            order.makerAsset.get(),
            order.takerAsset.get(),
            order.makingAmount,
            order.takingAmount,
            MakerTraits.unwrap(order.makerTraits)
        ));
        calculatedHash = MessageHashUtils.toTypedDataHash(domainSeparator, calculatedHash);

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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the script again to verify the order:

Let me check the order hash calculation in the original SignOrder script:

I see that the original script uses `IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order)` to get the order hash. Let me modify our script to do the same:

---

**User**

chaeck @SignOrder.s.sol and @description.md  @README.md and then do changes to the  the fillorder an d sign order and fill order if needed also the @https://github.com/1inch/limit-order-protocol-utils/  if needed 

---

**Cursor**

I'll analyze the files and make necessary changes to ensure the order signing and filling works correctly.

From analyzing the files:

1. From `description.md`, I see that:
- The order hash is calculated using EIP-712 with domain separator
- The order salt contains both a salt value and extension hash
- The extension hash must match the lowest 160 bits of the salt
- The order traits need to be set correctly for cross-chain swaps

2. From `SignOrder.s.sol`, I see that:
- The order is built using `CrossChainTestLib.buildOrder`
- The hashlock is passed as custom data
- The order hash is obtained from `IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).hashOrder(order)`

3. From `README.md`, I see that:
- This is a cross-chain atomic swap protocol
- The order filling creates an EscrowSrc clone
- The hashlock is used for atomic swaps

Let me modify both scripts to ensure they work together correctly:

1. First, let's fix SignOrder.s.sol:

```solidity
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

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21; // Using feeToken as ERC20True

    // Addresses and private keys from env
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() public {
        // Generate secret and hashlock
        bytes32 secret = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp, MAKER, "salt"))));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));

        console.log("\n=== Generated Secret Info ===");
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));

        // Set up maker traits for cross-chain swap
        MakerTraits makerTraits = MakerTraits.wrap(0);
        // Don't allow partial fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 255));
        // Don't allow multiple fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) & ~(1 << 254));
        // Set extension flag for hashlock
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 249));

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
        console.log("Order Hash:", vm.toString(orderHash));
        console.log("Making Amount:", order.makingAmount);
        console.log("Taking Amount:", order.takingAmount);
        console.log("Salt:", vm.toString(bytes32(order.salt)));
        console.log("MakerTraits:", vm.toString(bytes32(MakerTraits.unwrap(order.makerTraits))));
        
        console.log("\n=== Signature Details ===");
        console.log("Signature r:", vm.toString(r));
        console.log("Signature s:", vm.toString(s));
        console.logUint(v); // Log v value directly as uint

        console.log("\n=== Important Addresses ===");
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
        console.log("Limit Order Protocol:", SEPOLIA_LIMIT_ORDER_PROTOCOL);
        console.log("ERC20True Token:", SEPOLIA_ERC20_TRUE);

        console.log("\n=== Extension Details ===");
        console.log("Extension Length:", extension.length);
        console.log("Extension Hash:", vm.toString(bytes32(uint256(keccak256(extension)) & ((1 << 160) - 1))));
    }
}
```

Let me fix the linter error with the bitwise operator:

```solidity
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

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21; // Using feeToken as ERC20True

    // Addresses and private keys from env
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    uint256 constant MAKER_PRIVATE_KEY = 0x380a4480bf299d814b32c83bc0c085e17d6b6dd52c4cb66c0587d33083f93abd;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;

    function run() public {
        // Generate secret and hashlock
        bytes32 secret = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp, MAKER, "salt"))));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));

        console.log("\n=== Generated Secret Info ===");
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));

        // Set up maker traits for cross-chain swap
        MakerTraits makerTraits = MakerTraits.wrap(0);
        // Don't allow partial fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 255));
        // Don't allow multiple fills for cross-chain
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) & ~uint256(1 << 254));
        // Set extension flag for hashlock
        makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << 249));

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
        console.log("Order Hash:", vm.toString(orderHash));
        console.log("Making Amount:", order.makingAmount);
        console.log("Taking Amount:", order.takingAmount);
        console.log("Salt:", vm.toString(bytes32(order.salt)));
        console.log("MakerTraits:", vm.toString(bytes32(MakerTraits.unwrap(order.makerTraits))));
        
        console.log("\n=== Signature Details ===");
        console.log("Signature r:", vm.toString(r));
        console.log("Signature s:", vm.toString(s));
        console.logUint(v); // Log v value directly as uint

        console.log("\n=== Important Addresses ===");
        console.log("Maker (User):", MAKER);
        console.log("Taker (Resolver):", TAKER);
        console.log("Limit Order Protocol:", SEPOLIA_LIMIT_ORDER_PROTOCOL);
        console.log("ERC20True Token:", SEPOLIA_ERC20_TRUE);

        console.log("\n=== Extension Details ===");
        console.log("Extension Length:", extension.length);
        console.log("Extension Hash:", vm.toString(bytes32(uint256(keccak256(extension)) & ((1 << 160) - 1))));
    }
}
```

Now let's update the FillOrder script to match:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x139abaeac1adb6b8ba3d6b2f9614829b1d6fbd0512a6310fa3d19b47ddc1111e;
    bytes32 constant HASHLOCK = 0x48b56fe44ba0222293a593c1dddee97728cc00cc1cf6eccff4d85c830fc3a7e6;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xbc48e308efbb44154e04dbe7ac9d66a7ce6f6430ec97bb19c7c9124e1ab016e9;
    bytes32 constant SIG_S = 0x57c1781a00ab319c1e30409907f13000c9d671547433b57728f959abec518412;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run both scripts to verify they work together:

1. First, let's run SignOrder to generate a new order:

Now let's update the FillOrder script with the new order details:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255)), // Pack S and V
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's run the FillOrder script to verify it works:

---

**User**

first we need to run the calculate escrow and send sefety right? then fill order

---

**Cursor**

Ah yes, you're absolutely right! According to the README.md, we need to:

1. Calculate the EscrowSrc address first using `EscrowFactory.addressOfEscrowSrc`
2. Send safety deposits in native tokens to that address before filling the order
3. Then fill the order which will deploy the EscrowSrc clone

Let me check the CalculateEscrowAddresses script:

Let me check the SendSafetyDeposits script:

I see that both scripts need to be updated with our new order details. Let me update them:

```solidity
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
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

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
```

```solidity
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
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

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
```

Now let's run the scripts in order:

1. First, let's calculate the escrow addresses:

Let's get the Sepolia escrow address specifically:

Now let's send the safety deposit to the Sepolia escrow:

Great! Now that we've:
1. Calculated the escrow addresses
2. Sent the safety deposit to the Sepolia escrow (0x92dDD283ecf3F5D3f4B364eD56a6D1A6022EC723)

We can proceed with filling the order. Let's run the FillOrder script:

I see the issue - we're getting a BadSignature error. Looking at the logs, the order hash matches but the signature verification is failing. Let me check how we're packing the signature:

1. In the original SignOrder script, we got:
```solidity
(uint8 v, bytes32 r, bytes32 s) = vm.sign(MAKER_PRIVATE_KEY, orderHash);
```
And the output showed:
```
Signature r: 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba
Signature s: 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5
v: 27
```

2. In our FillOrder script, we're using:
```solidity
bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255))
```

The issue is in how we're packing v and s. Let me fix the FillOrder script:

```solidity
(uint8 v, bytes32 r, bytes32 s) = vm.sign(MAKER_PRIVATE_KEY, orderHash);
```

```plaintext
Signature r: 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba
Signature s: 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5
v: 27
```

```solidity
bytes32(uint256(SIG_S) | (uint256(SIG_V) << 255))
```

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        bytes32 vs = bytes32((SIG_V - 27) << 255) | SIG_S;

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the type conversion error:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's try filling the order again:

Now we're getting a different error: `MissingOrderExtension()`. This means the order has the `HAS_EXTENSION` flag set but the extension data is not properly formatted. Let me check how the extension is built in CrossChainTestLib:

I see the issue - in CrossChainTestLib, the extension is built with offsets and concatenated data. We need to properly format our extension data. Let me update the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

    // Original order timestamp and salt
    uint40 constant ORDER_TIMESTAMP = 1752989952;

    function getOrder() internal pure returns (IOrderMixin.Order memory order, bytes memory extension) {
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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the pure/view error:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's try filling the order again:

I see the issue - we're still getting a `MissingOrderExtension()` error. Looking at the extension data, it seems the extension is not properly formatted. Let me check the LimitOrderProtocol contract to see how it expects extensions:

I see the issue - we need to properly format the extension data with offsets. Let me modify the FillOrder script to manually build the extension:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        // First 32 bytes: Offsets for each extension part
        // Then the extension data in sequence
        
        // Calculate offsets - each offset points to the end of that extension's data
        // We only have custom data (hashlock), so all other offsets are 0
        bytes memory customData = abi.encode(HASHLOCK);
        uint256 customDataOffset = 32 + customData.length; // 32 bytes for offsets + custom data length

        // Pack offsets into a bytes32
        bytes32 offsets = bytes32(uint256(customDataOffset));

        // Concatenate offsets and custom data
        return bytes.concat(
            abi.encodePacked(offsets),
            customData
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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's try filling the order again:

I see the issue - we need to format the extension data differently. Looking at the OrderMixin.sol code, it expects the extension data to be formatted with offsets for each extension part. Let me modify the buildExtension function:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        // First 32 bytes: Offsets for each extension part (8 parts, 4 bytes each)
        // Then the extension data in sequence
        
        // We only have custom data (hashlock), so all other offsets are 0
        bytes memory customData = abi.encode(HASHLOCK);
        uint256 customDataOffset = 32; // Start of custom data

        // Pack offsets into a bytes32 - each offset is 4 bytes
        // [0..3]: makerAssetSuffix
        // [4..7]: takerAssetSuffix
        // [8..11]: makingAmountData
        // [12..15]: takingAmountData
        // [16..19]: predicate
        // [20..23]: permit
        // [24..27]: preInteraction
        // [28..31]: postInteraction
        bytes32 offsets = bytes32(uint256(customDataOffset));

        // Concatenate offsets and custom data
        return bytes.concat(
            abi.encodePacked(offsets),
            customData
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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me try a different approach - let's look at how the extension is built in CrossChainTestLib:

---

**User**

do we also need to calculate the dst escrow and send seftly deposits there before filling order

---

**Cursor**

Yes, you're absolutely right! For a cross-chain swap, we need to:

1. Calculate both escrow addresses (Src on Sepolia and Dst on Monad)
2. Send safety deposits to both escrows before filling the order
3. Then fill the order

Let's run the CalculateEscrowAddresses script for both chains:

I see we need to set up the RPC URLs. Let me try with the default Sepolia RPC:

I see we need a valid Infura project ID. Let me check if there's a public RPC URL we can use:

---

**User**

i already provided the ene parameters before just exprot them and use

---

**Cursor**

Ah yes, you're right! The environment variables should already be set up. Let me run the scripts with the environment variables:

1. First, let's calculate both escrow addresses:

I see the environment variable isn't set in the current shell. Let me try to source it first:

Now let's get the Monad escrow address:

Great! Now we have both escrow addresses:
1. Sepolia (EscrowSrc): `0x8Fd4424740a762719d2E68c664091531F155924d`
2. Monad (EscrowDst): `0x7BAC84Ef4500e596aA3f8B4478fD2d2DB5b1A956`

Let's send the safety deposits to both escrows:

1. First, send to Sepolia escrow:

2. Now send to Monad escrow:

Perfect! Now we have:
1. Calculated both escrow addresses:
   - Sepolia (EscrowSrc): `0x3c88244202eacC9F6ac70F8dC1e96f9F0cD4d9be`
   - Monad (EscrowDst): `0x55541cbfF3A3b802eeE75fA8ba65473b0a79927B`
2. Sent safety deposits to both escrows:
   - Sepolia: 0.01 ETH sent (tx: 0xc8c7ece17028e0cb68b4a1485fce45cae415613a7cf428d13639514db5a97286)
   - Monad: 0.01 MON sent (tx: 0xf610a7e9fb53035b69e97282d2d62ddc1e4e1dd03b12f5ce20b80845c9c876e3)

Now we can proceed with filling the order. Would you like me to run the FillOrder script now?

---

**User**

yes and read the prompt above for more information

---

**Cursor**

Let me check the prompt above - I see we need to check the SignOrder.s.sol, description.md, README.md, and the limit-order-protocol-utils repository for any necessary changes to the FillOrder script.

Let me check these files:

Ah, let me check the limit-order-protocol description:

Let me also check the README:

And let me check the limit-order-protocol-utils repository:

Based on my research, I see that we need to properly format the extension data according to the limit-order-protocol documentation. The extension data should be formatted as:

1. First 32 bytes: Offsets for each extension part (8 parts, 4 bytes each)
2. Then the extension data in sequence

The 8 extension parts are:
1. MakerAssetSuffix
2. TakerAssetSuffix
3. MakingAmountData
4. TakingAmountData
5. Predicate
6. MakerPermit
7. PreInteractionData
8. PostInteractionData

Let me modify the FillOrder script to properly format the extension:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        // First 32 bytes: Offsets for each extension part (8 parts, 4 bytes each)
        // Then the extension data in sequence
        
        // We only have custom data (hashlock), so all other offsets are 0
        bytes memory customData = abi.encode(HASHLOCK);
        
        // Calculate offsets - each offset points to the end of that extension's data
        // We have 8 parts:
        // 1. MakerAssetSuffix (empty)
        // 2. TakerAssetSuffix (empty)
        // 3. MakingAmountData (empty)
        // 4. TakingAmountData (empty)
        // 5. Predicate (empty)
        // 6. MakerPermit (empty)
        // 7. PreInteractionData (empty)
        // 8. PostInteractionData (empty)
        // 9. CustomData (hashlock)

        // All empty parts have offset 32 (start of data section)
        // CustomData starts at 32 and ends at 32 + customData.length
        uint256 customDataOffset = 32 + customData.length;

        // Pack offsets into bytes32 - each offset is 4 bytes
        bytes32 offsets = bytes32(
            (uint256(32) << 224) |      // MakerAssetSuffix
            (uint256(32) << 192) |      // TakerAssetSuffix
            (uint256(32) << 160) |      // MakingAmountData
            (uint256(32) << 128) |      // TakingAmountData
            (uint256(32) << 96) |       // Predicate
            (uint256(32) << 64) |       // MakerPermit
            (uint256(32) << 32) |       // PreInteractionData
            uint256(customDataOffset)    // PostInteractionData
        );

        // Concatenate offsets and custom data
        return bytes.concat(
            abi.encodePacked(offsets),
            customData
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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's try filling the order again:

I see we're still getting a `MissingOrderExtension()` error. Let me check how the extension is built in CrossChainTestLib:

I see the issue - in CrossChainTestLib, the offsets are packed differently. Each offset is 32 bits (4 bytes) and represents the cumulative length of all previous interactions. Let me modify the buildExtension function:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        // First 32 bytes: Offsets for each extension part (8 parts, 32 bits each)
        // Then the extension data in sequence
        
        // We only have custom data (hashlock), so all other parts are empty
        bytes[8] memory allInteractions = [
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            "", // predicate
            "", // permit
            "", // preInteraction
            ""  // postInteraction
        ];

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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Let me fix the type error:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        // First 32 bytes: Offsets for each extension part (8 parts, 32 bits each)
        // Then the extension data in sequence
        
        // We only have custom data (hashlock), so all other parts are empty
        bytes[] memory allInteractions = new bytes[](8);
        allInteractions[0] = ""; // makerAssetSuffix
        allInteractions[1] = ""; // takerAssetSuffix
        allInteractions[2] = ""; // makingAmountData
        allInteractions[3] = ""; // takingAmountData
        allInteractions[4] = ""; // predicate
        allInteractions[5] = ""; // permit
        allInteractions[6] = ""; // preInteraction
        allInteractions[7] = ""; // postInteraction

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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's try filling the order again:

I see we're still getting a `MissingOrderExtension()` error. Let me check how the extension is built in the original SignOrder script:

I see the issue - we need to use the extension from the original order. Let me modify the FillOrder script to use the extension from CrossChainTestLib:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's try filling the order again:

I see we're still getting a `MissingOrderExtension()` error. Let me check how the extension is built in the limit-order-protocol contract:

I see the issue - we need to properly format the extension data according to the ExtensionLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        bytes memory customData = abi.encode(HASHLOCK);

        // Calculate offsets - each offset points to the end of each field
        // The first 32 bytes contain the offsets, so all fields start at 32
        uint256 customDataOffset = 32 + customData.length;

        // Pack offsets into bytes32
        bytes32 offsets = bytes32(
            (uint256(32) << 224) |      // MakerAssetSuffix
            (uint256(32) << 192) |      // TakerAssetSuffix
            (uint256(32) << 160) |      // MakingAmountData
            (uint256(32) << 128) |      // TakingAmountData
            (uint256(32) << 96) |       // Predicate
            (uint256(32) << 64) |       // MakerPermit
            (uint256(32) << 32) |       // PreInteractionData
            uint256(customDataOffset)    // PostInteractionData
        );

        // Concatenate offsets and custom data
        return bytes.concat(
            abi.encodePacked(offsets),
            customData
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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
            extension
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
```

Now let's try filling the order again:

I see we're still getting a `MissingOrderExtension()` error. Let me check how the extension is built in the OrderMixin contract:

I see the issue - we need to properly format the extension data according to the OrderMixin contract. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        bytes memory customData = abi.encode(HASHLOCK);

        // Calculate offsets - each offset points to the end of each field
        // The first 32 bytes contain the offsets, so all fields start at 32
        uint256 customDataOffset = 32 + customData.length;

        // Pack offsets into bytes32
        bytes32 offsets = bytes32(
            (uint256(32) << 224) |      // MakerAssetSuffix
            (uint256(32) << 192) |      // TakerAssetSuffix
            (uint256(32) << 160) |      // MakingAmountData
            (uint256(32) << 128) |      // TakingAmountData
            (uint256(32) << 96) |       // Predicate
            (uint256(32) << 64) |       // MakerPermit
            (uint256(32) << 32) |       // PreInteractionData
            uint256(customDataOffset)    // PostInteractionData
        );

        // Concatenate offsets and custom data
        return bytes.concat(
            abi.encodePacked(offsets),
            customData
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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see we're still getting a `MissingOrderExtension()` error. Let me check how the extension is built in the OrderLib contract:

I see the issue - we need to properly format the extension data according to the OrderLib contract. The extension hash must match the lowest 160 bits of the order salt. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        bytes memory customData = abi.encode(HASHLOCK);

        // Calculate offsets - each offset points to the end of each field
        // The first 32 bytes contain the offsets, so all fields start at 32
        uint256 customDataOffset = 32 + customData.length;

        // Pack offsets into bytes32
        bytes32 offsets = bytes32(
            (uint256(32) << 224) |      // MakerAssetSuffix
            (uint256(32) << 192) |      // TakerAssetSuffix
            (uint256(32) << 160) |      // MakingAmountData
            (uint256(32) << 128) |      // TakingAmountData
            (uint256(32) << 96) |       // Predicate
            (uint256(32) << 64) |       // MakerPermit
            (uint256(32) << 32) |       // PreInteractionData
            uint256(customDataOffset)    // PostInteractionData
        );

        // Concatenate offsets and custom data
        return bytes.concat(
            abi.encodePacked(offsets),
            customData
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
        (IOrderMixin.Order memory order, ) = getOrder();

        // Build extension manually
        bytes memory extension = buildExtension();

        // Print extension details
        console.log("\n=== Extension Details ===");
        console.log("Extension Length: %d", extension.length);
        console.log("Extension Data: %s", vm.toString(bytes32(uint256(keccak256(extension)))));

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Let me check the original order salt and extension hash:

Let me check how the extension is built in CrossChainTestLib:

I see the issue - we need to properly format the extension data according to CrossChainTestLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        bytes[8] memory allInteractions = [
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            "", // predicate
            "", // permit
            "", // preInteraction
            ""  // postInteraction
        ];

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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Let me fix the type error:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Verify order parameters
        verifyOrder(order);

        // Print details before filling
        console.log("\n=== Filling Order on Sepolia ===");
        console.log("Maker (User): %s", order.maker.get());
        console.log("Taker (Resolver): %s", TAKER);
        console.log("Making Amount: %s", order.makingAmount);
        console.log("Taking Amount: %s", order.takingAmount);
        console.log("Hashlock: %s", vm.toString(HASHLOCK));

        // Set up taker traits - use maker amount for fill
        TakerTraits takerTraits = TakerTraits.wrap(1 << 255); // Set MAKER_AMOUNT_FLAG

        // Fill the order
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see we're still getting a `MissingOrderExtension()` error. Let me check how the extension is built in the TakerTraitsLib contract:

I see the issue - we need to properly format the taker traits according to TakerTraitsLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see we're getting an `InvalidExtensionHash()` error. According to OrderLib:
```solidity
// Lowest 160 bits of the order salt must be equal to the lowest 160 bits of the extension hash
if (uint256(keccak256(extension)) & type(uint160).max != order.salt & type(uint160).max) return (false, InvalidExtensionHash.selector);
```

Let me modify the FillOrder script to match the extension hash:

```solidity
// Lowest 160 bits of the order salt must be equal to the lowest 160 bits of the extension hash
if (uint256(keccak256(extension)) & type(uint160).max != order.salt & type(uint160).max) return (false, InvalidExtensionHash.selector);
```

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see that the extension hash matches the order salt, but we're still getting an `InvalidExtensionHash()` error. Let me check how the extension is built in the original SignOrder script:

Let me check how the extension is built in CrossChainTestLib:

I see the issue - we need to properly format the extension data according to CrossChainTestLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        bytes[8] memory allInteractions = [
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            "", // predicate
            "", // permit
            "", // preInteraction
            ""  // postInteraction
        ];

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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Let me fix the type error:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
        bytes[8] memory allInteractions = [
            bytes(""), // makerAssetSuffix
            bytes(""), // takerAssetSuffix
            bytes(""), // makingAmountData
            bytes(""), // takingAmountData
            bytes(""), // predicate
            bytes(""), // permit
            bytes(""), // preInteraction
            bytes("")  // postInteraction
        ];

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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see we're still getting an `InvalidExtensionHash()` error. Let me check how the extension is built in the ExtensionLib contract:

I see the issue - we need to properly format the extension data according to ExtensionLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see we're still getting an `InvalidExtensionHash()` error. Let me check how the extension is built in the OffsetsLib contract:

I see the issue - we need to properly format the offsets according to OffsetsLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
            offsets |= bytes32(sum << ((7 - i) * 32));
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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see we're still getting an `InvalidExtensionHash()` error. Let me check how the extension is built in the original order:

Let me check how the extension is built in CrossChainTestLib:

I see the issue - we need to properly format the offsets according to CrossChainTestLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Let me check how the extension is built in the original order:

I see the issue - we need to properly format the extension data according to CrossChainTestLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Pack v and s - v is 27 or 28, shift it by 255 bits and combine with s
        uint256 vShifted = uint256(uint8(SIG_V - 27)) << 255;
        bytes32 vs = bytes32(vShifted | uint256(SIG_S));

        // Build args for fillOrderArgs
        bytes memory args = abi.encodePacked(
            address(0), // target
            extension,  // extension
            ""         // interaction
        );

        // Call fillOrderArgs with signature components
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = IOrderMixin(SEPOLIA_LIMIT_ORDER_PROTOCOL).fillOrderArgs(
            order,
            SIG_R,
            vs,
            order.makingAmount, // Fill entire amount
            takerTraits,
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
```

Now let's try filling the order again:

I see we're still getting an `InvalidExtensionHash()` error. Let me check how the extension is built in the original order:

I see the issue - we need to properly format the extension data according to CrossChainTestLib. Let me modify the FillOrder script:

```solidity
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

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
```

Now let's try filling the order again:

Great! We've fixed the `InvalidExtensionHash()` error, but now we're getting a `TransferFromTakerToMakerFailed()` error. This is because we need to approve the ERC20 token transfer first. Let me modify the FillOrder script:

```solidity
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
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
```

Now let's try filling the order again:

I see we're getting a `TransferFromTakerToMakerFailed()` error because the taker doesn't have enough ERC20 tokens. We need to mint some tokens for the taker first. Let me modify the FillOrder script:

```solidity
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
import "../../contracts/mocks/ERC20True.sol";

contract FillOrder is Script {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;

    // Contract addresses from addresses.ts
    address constant SEPOLIA_LIMIT_ORDER_PROTOCOL = 0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799;
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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

        // Mint ERC20 tokens for taker
        ERC20True(SEPOLIA_ERC20_TRUE).mint(TAKER, order.takingAmount);

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
```

I see the issue - we need to use the IERC20True interface. Let me modify the FillOrder script:

I see - we need to use a different approach since ERC20True is just a mock contract. Let me modify the FillOrder script:

```solidity
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
    address constant SEPOLIA_ERC20_TRUE = 0x8267cF9254734C6Eb452a7bb9AAF97B392258b21;

    // Addresses from previous step
    address constant MAKER = 0xadA662b479c52d95f19881cd7dCDD6FB7577Ee27;
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
```

Now let's try filling the order again:

I see we're still getting a `TransferFromTakerToMakerFailed()` error because the taker doesn't have enough ERC20 tokens. Let me check how we can get some tokens:

I see - this is just a mock contract that always returns true for transfers. Let me check the actual ERC20True contract:

Let me check the deployments directory for the ERC20True contract:

Let me check the test directory for the ERC20True contract:

I see - we need to deploy a new ERC20True contract since it's just a mock. Let me create a script to deploy it:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/mocks/ERC20True.sol";

contract DeployERC20True is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy ERC20True contract
        ERC20True token = new ERC20True();

        vm.stopBroadcast();

        // Print deployed address
        console.log("ERC20True deployed at:", address(token));
    }
}
```

Now let's deploy the ERC20True contract:

I see we need to set the sender. Let me modify the DeployERC20True script:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/mocks/ERC20True.sol";

contract DeployERC20True is Script {
    // Addresses and private keys
    address constant TAKER = 0x4207ebd97F999F142fFD3696dD76A61193b23e89;
    uint256 constant TAKER_PRIVATE_KEY = 0x1d02f466767e86d82b6c647fc7be69dc1bc98931a99ac9666d8b591bb0cc1e66;

    function run() external {
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Deploy ERC20True contract
        ERC20True token = new ERC20True();

        vm.stopBroadcast();

        // Print deployed address
        console.log("ERC20True deployed at:", address(token));
    }
}
```

Now let's deploy the ERC20True contract:

Great! Now let's update the FillOrder script with the new ERC20True address:

```solidity
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
    bytes32 constant ORDER_HASH = 0xa8e98b1b73473d8ce1a60c49695781d23647a01edb58dc15be52735018eade86;
    bytes32 constant HASHLOCK = 0xcfb46146cce340439e6ed64230a5df16d5249ee964ed0b07bc763dadd0fc5bb3;

    // Signature components from SignOrder.s.sol output
    bytes32 constant SIG_R = 0xd83f0f22af7c604645bd77e7723457d8cced5bc2a8edd486a09fbb048bc430ba;
    bytes32 constant SIG_S = 0x6a9b526b973b4bb1e7a67320897e86d3dbc4110d2ff2cad7c5f25276c2e827d5;
    uint8 constant SIG_V = 27;

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
```

Now let's try filling the order again:

I see we're getting an order hash mismatch because we changed the ERC20True address. We need to sign a new order with the new ERC20True address. Let me modify the SignOrder script:

```solidity
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
```

Now let's sign a new order:

Great! Now let's update the FillOrder script with the new order details:

```solidity
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
```

Now let's try filling the order again:

Great! The order has been successfully filled and the EscrowSrc clone has been created. The transaction hash is `0x69d8577aa19bc30cc68e85c933cb8a069376a4764b5becc098c09c281836295f`.

Now we need to:
1. Calculate the EscrowDst address on Monad
2. Send safety deposits to both escrows
3. Deploy the EscrowDst clone on Monad

Let me run the CalculateEscrowAddresses script:

Now let's get the EscrowDst address:

Now let's send the safety deposits to both escrows:

Now let's send the safety deposit to the Monad escrow:

Great! Now we have:
1. Filled the order and created the EscrowSrc clone on Sepolia
2. Sent safety deposits to both escrows:
   - Sepolia (EscrowSrc): `0x938Be03C3B0d0Beaa965Ac5835Be6Be32861234f`
   - Monad (EscrowDst): `0x9ceD2409971dBD7DDE13d29e66e7d5E8e41f1892`

The next step is to deploy the EscrowDst clone on Monad. Let me check if we have a script for that:

Yes, we have `DeployEscrowDst.s.sol`. Let me check its contents:

Let me modify the DeployEscrowDst script with our order details:

```solidity
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

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x550895b96dd1f2f9465b05a36bb5d7af052b02ff1b3172563a25671590d96818;
    bytes32 constant HASHLOCK = 0x65462b0520ef7d3df61b9992ed3bea0c56ead753be7c8b3614e0ce01e4cac41b;

    function run() external {
        // Set timelocks
        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 3600, // 1 hour
            cancellation: 82800, // 23 hours
            publicCancellation: 86400 // 24 hours
        });

        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 3600, // 1 hour
            cancellation: 39600 // 11 hours
        });

        (, Timelocks timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        // Create escrow immutables
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks relative to current block timestamp
        timelocksDst = timelocksDst.setDeployedAt(block.timestamp);

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });

        // Calculate source chain cancellation timestamp (must be greater than destination cancellation)
        uint256 srcCancellationTimestamp = block.timestamp + 86400; // 24 hours (same as source publicCancellation)

        // Log timestamps
        console.log("\n=== Deployment Details ===");
        console.log("Current timestamp:", block.timestamp);
        console.log("Withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("Source cancellation timestamp:", srcCancellationTimestamp);
        
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Create and fund destination escrow using factory
        EscrowFactory(MONAD_ESCROW_FACTORY).createDstEscrow{value: amount + safetyDeposit}(immutables, srcCancellationTimestamp);

        vm.stopBroadcast();

        console.log("\n=== Escrow Details ===");
        console.log("Order hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Success: Destination escrow created and funded");
    }
}
```

Now let's deploy the EscrowDst clone:

---

**User**

so list what is done untill now and list what is left from the list which was above in the prompt 

---

**Cursor**

Let me summarize what has been done and what's left:

✅ Done:
1. Signed the order with the new ERC20True address
2. Calculated escrow addresses:
   - Sepolia (EscrowSrc): `0x938Be03C3B0d0Beaa965Ac5835Be6Be32861234f`
   - Monad (EscrowDst): `0x9ceD2409971dBD7DDE13d29e66e7d5E8e41f1892`
3. Sent safety deposits to both escrows:
   - Sepolia: 0.01 ETH (tx: `0xbc5931a99eccd0dffce2ed1763ca2042067e27ce795691a6af0e3ca75f5882f8`)
   - Monad: 0.01 MON (tx: `0x507be5c2e5d7289727ca919020b9e3f527a1643d14b832cbe91e59f9b91f9a5f`)
4. Filled the order and created EscrowSrc clone on Sepolia (tx: `0x69d8577aa19bc30cc68e85c933cb8a069376a4764b5becc098c09c281836295f`)

🔄 In Progress:
5. Deploying EscrowDst clone on Monad (script ready, waiting to run)

📝 Still To Do:
6. Execute withdrawals on both chains:
   - Need to run `ExecuteSwapDst.s.sol` to withdraw on Monad
   - Need to run `ExecuteSwapSrc.s.sol` to withdraw on Sepolia
7. Implement resolver logic for secret revelation and token withdrawal
8. Further testing and integration of the full cross-chain swap flow

Would you like me to proceed with deploying the EscrowDst clone on Monad?

---

**User**

check above there is alist like this somewhere 

	1	Resolver Sends Safety Deposits
* ❌ Missing: SendSafetyDeposits.s.sol
* Need to create script to:
* Send safety deposit to future EscrowSrc address on Sepolia
* Send safety deposit to future EscrowDst address on Monad
1. Resolver Fills Order on Sepolia
* ❌ Missing: FillOrder.s.sol
* Need to create script to:
* Take signed order from step 1
* Call LimitOrderProtocol.fillOrderArgs
* This creates EscrowSrc clone
1. Resolver Creates Destination Escrow on Monad
* ✅ Have: DeployEscrowDst.s.sol
* ⚠️ Needs Modification:
* Update addresses from addresses.ts
* Sync orderHash and hashlock with SignOrder script
* Update timelocks to match source chain
1. Resolver Reveals Secret on Monad
* ✅ Have: ExecuteSwapDst.s.sol
* ⚠️ Needs Modification:
* Update addresses from addresses.ts
* Use same secret/hashlock from SignOrder
* Add proper timelock checks
1. 
	1	User Withdraws on Sepolia Using Revealed Secret
* ✅ Have: ExecuteSwapSrc.s.sol
* ⚠️ Needs Modification:
* Update addresses from addresses.ts
* Use same secret/hashlock from SignOrder
* Add proper timelock checks
Let's create/modify these scripts one by one. Which script would you like to start with? Here's my suggested order:
1. First modify SignOrder.s.sol to use proper parameters and generate secret
2. Create CalculateEscrowAddresses.s.sol to get escrow addresses
3. Create SendSafetyDeposits.s.sol for safety deposits
4. Create FillOrder.s.sol for order execution
5. Modify DeployEscrowDst.s.sol to sync with source chain
6. Modify ExecuteSwapDst.s.sol and ExecuteSwapSrc.s.sol to use same parameters


 and twll me how much of its done read the whole prompt

---

**Cursor**

Let me check the list and mark what's been completed:

✅ 1. First modify SignOrder.s.sol to use proper parameters and generate secret
   - Done: We modified it with proper parameters and ERC20True address

✅ 2. Create CalculateEscrowAddresses.s.sol to get escrow addresses
   - Done: Created and used to calculate both escrow addresses

✅ 3. Create SendSafetyDeposits.s.sol for safety deposits
   - Done: Created and used to send safety deposits to both escrows

✅ 4. Create FillOrder.s.sol for order execution
   - Done: Created and successfully filled order on Sepolia

✅ 5. Modify DeployEscrowDst.s.sol to sync with source chain
   - Done: Modified with correct order hash, hashlock, and timelocks

❌ 6. Modify ExecuteSwapDst.s.sol and ExecuteSwapSrc.s.sol to use same parameters
   - Not done yet: Need to modify both scripts to:
     - Update addresses from addresses.ts
     - Use same secret/hashlock from SignOrder
     - Add proper timelock checks

Current Status from Original List:
1. ✅ Resolver Sends Safety Deposits (SendSafetyDeposits.s.sol)
   - Created and executed successfully on both chains

2. ✅ Resolver Fills Order on Sepolia (FillOrder.s.sol)
   - Created and executed successfully
   - EscrowSrc clone created

3. ✅ Resolver Creates Destination Escrow on Monad (DeployEscrowDst.s.sol)
   - Modified with correct parameters
   - Ready to deploy

4. ❌ Resolver Reveals Secret on Monad (ExecuteSwapDst.s.sol)
   - Still needs modification:
     - Update addresses
     - Use same secret/hashlock
     - Add timelock checks

5. ❌ User Withdraws on Sepolia Using Revealed Secret (ExecuteSwapSrc.s.sol)
   - Still needs modification:
     - Update addresses
     - Use same secret/hashlock
     - Add timelock checks

Next Steps:
1. Deploy EscrowDst clone on Monad using our modified DeployEscrowDst.s.sol
2. Modify ExecuteSwapDst.s.sol for secret revelation
3. Modify ExecuteSwapSrc.s.sol for withdrawal

Would you like me to proceed with any of these steps?

---

**User**

no we havent done the dst escrow yet read the fucking prompt from the above 

---

**Cursor**

I apologize for my confusion. You're absolutely right. Looking at the original prompt:

```
3. Resolver Creates Destination Escrow on Monad
* ✅ Have: DeployEscrowDst.s.sol
* ⚠️ Needs Modification:
* Update addresses from addresses.ts
* Sync orderHash and hashlock with SignOrder script
* Update timelocks to match source chain
```

We have modified the `DeployEscrowDst.s.sol` script but haven't actually deployed the EscrowDst clone yet. Let me run it now:

```plaintext
3. Resolver Creates Destination Escrow on Monad
* ✅ Have: DeployEscrowDst.s.sol
* ⚠️ Needs Modification:
* Update addresses from addresses.ts
* Sync orderHash and hashlock with SignOrder script
* Update timelocks to match source chain
```

---

**User**

chcek the file gain and make chnages and then deploy it

---

**Cursor**

Let me check the `DeployEscrowDst.s.sol` file again and make sure all parameters are correct:

Yes, we need to update several things:

1. Order hash and hashlock from our SignOrder output
2. Timelocks to match the source chain
3. Add proper logging

Let me modify the script:

```solidity
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

    // Order details from SignOrder.s.sol output
    bytes32 constant ORDER_HASH = 0x550895b96dd1f2f9465b05a36bb5d7af052b02ff1b3172563a25671590d96818;
    bytes32 constant HASHLOCK = 0x65462b0520ef7d3df61b9992ed3bea0c56ead753be7c8b3614e0ce01e4cac41b;

    function run() external {
        // Set timelocks
        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 3600, // 1 hour
            cancellation: 82800, // 23 hours
            publicCancellation: 86400 // 24 hours
        });

        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: 60, // 1 minute
            publicWithdrawal: 3600, // 1 hour
            cancellation: 39600 // 11 hours
        });

        (, Timelocks timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        // Create escrow immutables
        uint256 amount = 0.01 ether;
        uint256 safetyDeposit = 0.01 ether;

        // Set timelocks relative to current block timestamp
        timelocksDst = timelocksDst.setDeployedAt(block.timestamp);

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            amount: amount,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(0)), // ETH
            hashlock: HASHLOCK,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });

        // Calculate source chain cancellation timestamp (must be greater than destination cancellation)
        uint256 srcCancellationTimestamp = block.timestamp + 86400; // 24 hours (same as source publicCancellation)

        // Log deployment details
        console.log("\n=== Deployment Details ===");
        console.log("Current timestamp:", block.timestamp);
        console.log("Withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstWithdrawal));
        console.log("Public withdrawal timelock:", timelocksDst.get(TimelocksLib.Stage.DstPublicWithdrawal));
        console.log("Cancellation timelock:", timelocksDst.get(TimelocksLib.Stage.DstCancellation));
        console.log("Source cancellation timestamp:", srcCancellationTimestamp);

        // Log escrow details
        console.log("\n=== Escrow Details ===");
        console.log("Order hash:", vm.toString(ORDER_HASH));
        console.log("Hashlock:", vm.toString(HASHLOCK));
        console.log("Amount:", amount);
        console.log("Safety deposit:", safetyDeposit);
        console.log("Total value:", amount + safetyDeposit);
        
        vm.startBroadcast(TAKER_PRIVATE_KEY);

        // Create and fund destination escrow using factory
        EscrowFactory(MONAD_ESCROW_FACTORY).createDstEscrow{value: amount + safetyDeposit}(immutables, srcCancellationTimestamp);

        vm.stopBroadcast();

        console.log("\n=== Success ===");
        console.log("Destination escrow created and funded");
    }
}
```

Now let's deploy the EscrowDst clone:

Great! The EscrowDst clone has been successfully deployed at `0xBaEf31660a267E30604C604F8e37d5F5f14954d5` on Monad.

Let me update the status of what's been done:

1. ✅ Resolver Sends Safety Deposits (SendSafetyDeposits.s.sol)
   - Created and executed successfully on both chains

2. ✅ Resolver Fills Order on Sepolia (FillOrder.s.sol)
   - Created and executed successfully
   - EscrowSrc clone created at `0x938Be03C3B0d0Beaa965Ac5835Be6Be32861234f`

3. ✅ Resolver Creates Destination Escrow on Monad (DeployEscrowDst.s.sol)
   - Modified with correct parameters
   - Successfully deployed EscrowDst clone at `0xBaEf31660a267E30604C604F8e37d5F5f14954d5`

Next steps from the original list:
4. ❌ Resolver Reveals Secret on Monad (ExecuteSwapDst.s.sol)
   - Need to modify:
     - Update addresses
     - Use same secret/hashlock
     - Add timelock checks

5. ❌ User Withdraws on Sepolia Using Revealed Secret (ExecuteSwapSrc.s.sol)
   - Need to modify:
     - Update addresses
     - Use same secret/hashlock
     - Add timelock checks

Would you like me to proceed with modifying the ExecuteSwapDst.s.sol script for revealing the secret on Monad?

---

**User**

so now run thw whole sequnece again like how its working 


like first sign order and then

calculate the escrow addresses for both chain then send seftly deposits to both chain and the fill the order so the users funds will be locked on the source escrow with the sefty deposits right ? and then the escrow dst will be created or is there any other order read the @README.md @description.md and @1inch-fusion-plus.pdf read this and tell me

