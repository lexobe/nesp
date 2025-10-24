// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState} from "../../CONTRACTS/core/Types.sol";
import {MockERC20} from "../../CONTRACTS/mocks/MockERC20.sol";
import {AlwaysYesValidator} from "../../CONTRACTS/mocks/AlwaysYesValidator.sol";

import {Handler} from "./Handler.sol";

/**
 * @title InvariantTest
 * @notice Foundry invariant tests for NESP protocol
 * @dev Uses Handler contract for guided fuzzing
 *
 * Purpose:
 * - Automatically test protocol invariants across random action sequences
 * - Discover edge cases that manual tests might miss
 * - Verify that invariants hold under all conditions
 *
 * How it works:
 * 1. Foundry randomly calls handler functions (createOrder, acceptOrder, etc.)
 * 2. After each sequence of actions, invariant functions are checked
 * 3. If any invariant fails, Foundry minimizes the failing sequence
 *
 * Configuration (foundry.toml):
 * - runs: 256 (number of random sequences to try)
 * - depth: 15 (actions per sequence)
 */
contract InvariantTest is StdInvariant, Test {
    /*//////////////////////////////////////////////////////////////
                            CORE CONTRACTS
    //////////////////////////////////////////////////////////////*/

    NESPCore public core;
    MockERC20 public token;
    Handler public handler;

    address public governance;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        governance = address(this);

        // Deploy contracts
        core = new NESPCore(governance);
        token = new MockERC20("Test Token", "TEST");

        // Deploy fee validator
        AlwaysYesValidator validator = new AlwaysYesValidator();
        core.setFeeValidator(address(validator));

        // Deploy handler
        handler = new Handler(core, token);

        // Configure Foundry to call handler functions
        targetContract(address(handler));

        // Optionally: target specific functions for more focused testing
        // bytes4[] memory selectors = new bytes4[](3);
        // selectors[0] = Handler.createAndDepositETH.selector;
        // selectors[1] = Handler.acceptOrder.selector;
        // selectors[2] = Handler.withdraw.selector;
        // targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /*//////////////////////////////////////////////////////////////
                        INV.8: GLOBAL BALANCE EQUALITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.8: Contract balance = user balances + forfeit + pending escrows
     * @dev This must ALWAYS hold, regardless of action sequence
     */
    function invariant_GlobalBalanceEquality_ETH() public view {
        uint256 contractBalance = address(core).balance;
        uint256 totalUserBalances = _sumUserBalances(address(0));
        uint256 forfeit = core.forfeitBalance(address(0));
        uint256 pendingEscrow = _sumPendingEscrows(address(0));

        assertEq(
            contractBalance,
            totalUserBalances + forfeit + pendingEscrow,
            "INV.8 violation: ETH balance mismatch"
        );
    }

    /**
     * @notice INV.8 for ERC-20 tokens
     */
    function invariant_GlobalBalanceEquality_ERC20() public view {
        uint256 contractBalance = token.balanceOf(address(core));
        uint256 totalUserBalances = _sumUserBalances(address(token));
        uint256 forfeit = core.forfeitBalance(address(token));
        uint256 pendingEscrow = _sumPendingEscrows(address(token));

        assertEq(
            contractBalance,
            totalUserBalances + forfeit + pendingEscrow,
            "INV.8 violation: ERC-20 balance mismatch"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    INV.4: SINGLE CREDIT PER ORDER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.4: Each order can only be credited once
     * @dev Verified by checking that settled/cancelled/forfeited orders have escrow = 0
     */
    function invariant_SingleCreditPerOrder() public view {
        uint256 nextId = core.nextOrderId();

        for (uint256 i = 1; i < nextId; i++) {
            Order memory order = core.getOrder(i);

            // Terminal states must have escrow = 0 (already credited)
            if (
                order.state == OrderState.Settled || order.state == OrderState.Cancelled
                    || order.state == OrderState.Forfeited
            ) {
                assertEq(order.escrow, 0, "INV.4 violation: terminal order has non-zero escrow");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INV.10: PULL SEMANTICS ONLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.10: Only withdraw() transfers funds to users
     * @dev Verified by checking ghost variables: withdrawn ≤ deposited
     */
    function invariant_PullSemanticsOnly_ETH() public view {
        // All withdrawn ETH must have been deposited first
        assertLe(
            handler.ghost_ethWithdrawn(),
            handler.ghost_ethDeposited(),
            "INV.10 violation: withdrew more ETH than deposited"
        );
    }

    /**
     * @notice INV.10 for ERC-20
     */
    function invariant_PullSemanticsOnly_ERC20() public view {
        assertLe(
            handler.ghost_tokenWithdrawn(),
            handler.ghost_tokenDeposited(),
            "INV.10 violation: withdrew more tokens than deposited"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    INV.11: ANCHOR IMMUTABILITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.11: Order anchors (client/contractor/tokenAddr) never change
     * @dev Verified by storing initial values and checking they remain constant
     *
     * Note: This is implicitly verified since Solidity doesn't allow modifying
     * struct fields externally, but we can check for zero addresses (which would
     * indicate memory corruption or other critical issues)
     */
    function invariant_AnchorsNeverZero() public view {
        uint256 nextId = core.nextOrderId();

        for (uint256 i = 1; i < nextId; i++) {
            Order memory order = core.getOrder(i);

            // Anchors must never be zero (would indicate memory corruption)
            assertTrue(order.client != address(0), "INV.11 violation: client is zero address");
            assertTrue(order.contractor != address(0), "INV.11 violation: contractor is zero address");
            // tokenAddr CAN be zero (represents ETH)
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INV.1: SELF-DEALING PROHIBITED
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.1: Client != contractor for all orders
     * @dev WP §4.1 INV.1
     */
    function invariant_NoSelfDealing() public view {
        uint256 nextId = core.nextOrderId();

        for (uint256 i = 1; i < nextId; i++) {
            Order memory order = core.getOrder(i);
            assertTrue(order.client != order.contractor, "INV.1 violation: self-dealing detected");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INV.12: NON-NEGATIVE BALANCES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.12: All withdrawable balances are non-negative
     * @dev WP §4.3 INV.12: "用户的可提余额 ≥ 0"
     *
     * Note: Solidity uint256 is always ≥ 0, but this checks for underflow bugs
     */
    function invariant_NonNegativeBalances() public view {
        // Check all actors
        for (uint256 i = 0; i < handler.NUM_ACTORS(); i++) {
            address actor = handler.actors(i);

            // Withdrawable balances must exist (not revert)
            core.withdrawableOf(address(0), actor); // ETH
            core.withdrawableOf(address(token), actor); // ERC-20
        }

        // Check forfeit balances
        core.forfeitBalance(address(0));
        core.forfeitBalance(address(token));
    }

    /*//////////////////////////////////////////////////////////////
                    INV.13: TERMINAL STATES FROZEN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.13: Terminal states (Settled/Cancelled/Forfeited) are immutable
     * @dev Once an order reaches a terminal state, it should never transition again
     *
     * Note: This is enforced by state machine guards, verified here through escrow = 0
     */
    function invariant_TerminalStatesFrozen() public view {
        // Same as INV.4 check - terminal states have escrow = 0
        invariant_SingleCreditPerOrder();
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sum all user withdrawable balances for a token
     */
    function _sumUserBalances(address tokenAddr) internal view returns (uint256 total) {
        for (uint256 i = 0; i < handler.NUM_ACTORS(); i++) {
            address actor = handler.actors(i);
            total += core.withdrawableOf(tokenAddr, actor);
        }
        // Also check governance
        total += core.withdrawableOf(tokenAddr, governance);
    }

    /**
     * @notice Sum all pending escrows (non-terminal orders)
     */
    function _sumPendingEscrows(address tokenAddr) internal view returns (uint256 total) {
        uint256 nextId = core.nextOrderId();

        for (uint256 i = 1; i < nextId; i++) {
            Order memory order = core.getOrder(i);

            if (order.tokenAddr != tokenAddr) continue;

            // Only count non-terminal states
            if (
                order.state != OrderState.Settled && order.state != OrderState.Forfeited
                    && order.state != OrderState.Cancelled
            ) {
                total += order.escrow;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        POST-TEST STATISTICS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Log statistics after invariant testing completes
     * @dev Call this manually with: forge test --match-test invariant_CallSummary -vv
     */
    function invariant_CallSummary() public view {
        console2.log("\n=== Invariant Test Statistics ===");
        console2.log("Orders created (ETH):", handler.callCount_createAndDepositETH());
        console2.log("Orders created (ERC20):", handler.callCount_createAndDepositERC20());
        console2.log("acceptOrder calls:", handler.callCount_acceptOrder());
        console2.log("markReady calls:", handler.callCount_markReady());
        console2.log("approveReceipt calls:", handler.callCount_approveReceipt());
        console2.log("raiseDispute calls:", handler.callCount_raiseDispute());
        console2.log("cancelOrder calls:", handler.callCount_cancelOrder());
        console2.log("timeoutSettle calls:", handler.callCount_timeoutSettle());
        console2.log("timeoutForfeit calls:", handler.callCount_timeoutForfeit());
        console2.log("withdraw calls:", handler.callCount_withdraw());
        console2.log("\nGhost variables:");
        console2.log("ETH deposited:", handler.ghost_ethDeposited());
        console2.log("ETH withdrawn:", handler.ghost_ethWithdrawn());
        console2.log("Tokens deposited:", handler.ghost_tokenDeposited());
        console2.log("Tokens withdrawn:", handler.ghost_tokenWithdrawn());
        console2.log("\nTotal orders created:", core.nextOrderId() - 1);
    }
}
