// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {BaseTest} from "../BaseTest.t.sol";
import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState, BalanceKind} from "../../CONTRACTS/core/Types.sol";

/**
 * @title Invariants Test
 * @notice Tests for protocol invariants (INV.1-14) from WP §4.1-4.3
 * @dev Priority P1 invariants: INV.4, INV.8, INV.10, INV.11
 *
 * Test Coverage:
 * - INV.4: Single credit per order (prevent double-spend)
 * - INV.8: Global balance equality
 * - INV.10: Pull semantics (only withdraw() transfers funds)
 * - INV.11: Anchor immutability (client/contractor/tokenAddr)
 */
contract InvariantsTest is BaseTest {
    event BalanceCredited(
        uint256 indexed orderId,
        address indexed to,
        address token,
        uint256 amount,
        BalanceKind kind
    );

    /*//////////////////////////////////////////////////////////////
                        INV.4: SINGLE CREDIT PER ORDER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.4: Each order can only be credited once (prevent double-spend)
     * @dev WP §4.1 INV.4: "一个订单只会被记账一次（防止双花）"
     *
     * Test Scenario:
     * 1. Create order and settle via approveReceipt
     * 2. Verify BalanceCredited event emitted exactly once
     * 3. Attempt to call approveReceipt again
     * 4. Verify revert with ErrInvalidState
     */
    function test_INV4_SingleCreditPerOrder_ApproveReceipt() public {
        // 1. Create order (ETH)
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // 2. Accept order
        vm.prank(contractor);
        core.acceptOrder(orderId);

        // 3. Mark ready
        vm.prank(contractor);
        core.markReady(orderId);

        // 4. Approve receipt - should emit BalanceCredited exactly once
        vm.expectEmit(true, true, false, true);
        emit BalanceCredited(
            orderId,
            contractor,
            address(0),
            ESCROW_AMOUNT,
            BalanceKind.Payout
        );

        vm.prank(client);
        core.approveReceipt(orderId);

        // Verify order is now Settled (terminal state)
        Order memory order = core.getOrder(orderId);
        assertEq(uint8(order.state), uint8(OrderState.Settled));
        assertEq(order.escrow, 0); // Escrow cleared

        // 5. Attempt to approve again - should revert (INV.4 protection)
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.approveReceipt(orderId);

        // 6. Verify balance credited only once
        uint256 contractorBalance = core.withdrawableOf(address(0), contractor);
        assertEq(contractorBalance, ESCROW_AMOUNT); // Exactly 1x escrow
    }

    /**
     * @notice INV.4: Forfeited order cannot be credited
     * @dev After timeoutForfeit, order cannot be settled or approved
     */
    function test_INV4_SingleCreditPerOrder_ForfeitedOrderImmutable() public {
        // 1. Create order
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // 2. Accept -> raiseDispute
        vm.prank(contractor);
        core.acceptOrder(orderId);

        vm.prank(client);
        core.raiseDispute(orderId);

        // 3. Warp past dispute window
        Order memory order = core.getOrder(orderId);
        vm.warp(order.disputeStart + DIS_SEC + 1);

        // 4. Forfeit
        core.timeoutForfeit(orderId);

        // Verify forfeited
        order = core.getOrder(orderId);
        assertEq(uint8(order.state), uint8(OrderState.Forfeited));
        assertEq(order.escrow, 0);

        // 5. Attempt to approve receipt - should revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.approveReceipt(orderId);

        // 6. Attempt to raise dispute - should revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.raiseDispute(orderId);

        // 7. Verify no balance credited to client or contractor
        assertEq(core.withdrawableOf(address(0), client), 0);
        assertEq(core.withdrawableOf(address(0), contractor), 0);

        // 8. Verify forfeit balance increased
        assertEq(core.forfeitBalance(address(0)), ESCROW_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                    INV.8: GLOBAL BALANCE EQUALITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.8: Contract balance equals user balances + forfeit + pending escrows
     * @dev WP §4.3 INV.8: "合约余额 = 用户可提余额 + ForfeitPool + 未终态订单托管"
     *
     * Formula: contractBalance = Σ(userBalances) + forfeitBalance + Σ(pendingEscrows)
     *
     * Test Scenario:
     * 1. Create 3 orders with different states
     * 2. Verify equation holds after each state transition
     */
    function test_INV8_GlobalBalanceEquality_MultipleOrders() public {
        // Initial state: contract balance should be 0
        _assertBalanceEquality(address(0));

        // Order 1: Settled (credits user balance)
        uint256 order1 = _createAndDepositETH(1 ether);
        _assertBalanceEquality(address(0)); // Check after deposit

        vm.prank(contractor);
        core.acceptOrder(order1);
        _assertBalanceEquality(address(0));

        vm.prank(contractor);
        core.markReady(order1);
        _assertBalanceEquality(address(0));

        vm.prank(client);
        core.approveReceipt(order1);
        _assertBalanceEquality(address(0)); // Check after settlement

        // Order 2: Forfeited (credits forfeit pool)
        uint256 order2 = _createAndDepositETH(2 ether);
        _assertBalanceEquality(address(0));

        vm.prank(contractor);
        core.acceptOrder(order2);
        _assertBalanceEquality(address(0));

        vm.prank(client);
        core.raiseDispute(order2);
        _assertBalanceEquality(address(0));

        Order memory ord2 = core.getOrder(order2);
        vm.warp(ord2.disputeStart + DIS_SEC + 1);
        core.timeoutForfeit(order2);
        _assertBalanceEquality(address(0)); // Check after forfeit

        // Order 3: Executing (pending escrow)
        uint256 order3 = _createAndDepositETH(3 ether);
        _assertBalanceEquality(address(0));

        vm.prank(contractor);
        core.acceptOrder(order3);
        _assertBalanceEquality(address(0)); // Check with pending escrow

        // Order 4: Cancelled (refunds client)
        uint256 order4 = _createAndDepositETH(0.5 ether);
        _assertBalanceEquality(address(0));

        vm.prank(client);
        core.cancelOrder(order4);
        _assertBalanceEquality(address(0)); // Check after cancellation

        // Final state verification
        uint256 contractBalance = address(core).balance;
        uint256 clientBalance = core.withdrawableOf(address(0), client);
        uint256 contractorBalance = core.withdrawableOf(address(0), contractor);
        uint256 forfeit = core.forfeitBalance(address(0));

        // Order 1: 1 ETH to contractor
        // Order 2: 2 ETH forfeited
        // Order 3: 3 ETH pending (Executing)
        // Order 4: 0.5 ETH refunded to client

        assertEq(contractorBalance, 1 ether); // From order 1
        assertEq(clientBalance, 0.5 ether); // From order 4
        assertEq(forfeit, 2 ether); // From order 2

        Order memory pendingOrder = core.getOrder(order3);
        uint256 pendingEscrow = pendingOrder.escrow;
        assertEq(pendingEscrow, 3 ether);

        // INV.8: contractBalance = userBalances + forfeit + pendingEscrow
        assertEq(
            contractBalance,
            clientBalance + contractorBalance + forfeit + pendingEscrow,
            "INV.8 violation: balance mismatch"
        );
    }

    /**
     * @notice INV.8: Balance equality holds with ERC-20 tokens
     */
    function test_INV8_GlobalBalanceEquality_ERC20() public {
        uint256 escrow1 = 100e18; // 100 tokens (within INITIAL_BALANCE)
        uint256 escrow2 = 200e18; // 200 tokens (within INITIAL_BALANCE)

        // Order 1: Settled
        uint256 order1 = _createAndDepositERC20(escrow1);

        _assertBalanceEquality(address(token));

        vm.prank(contractor);
        core.acceptOrder(order1);

        vm.prank(contractor);
        core.markReady(order1);

        vm.prank(client);
        core.approveReceipt(order1);

        _assertBalanceEquality(address(token));

        // Order 2: Pending
        uint256 order2 = _createAndDepositERC20(escrow2);

        _assertBalanceEquality(address(token));

        // Verify final state
        uint256 contractBalance = token.balanceOf(address(core));
        uint256 contractorBalance = core.withdrawableOf(address(token), contractor);
        uint256 forfeit = core.forfeitBalance(address(token));
        Order memory ord2 = core.getOrder(order2);

        assertEq(contractorBalance, escrow1);
        assertEq(forfeit, 0);
        assertEq(ord2.escrow, escrow2);

        assertEq(
            contractBalance,
            contractorBalance + forfeit + ord2.escrow,
            "INV.8 violation for ERC-20"
        );
    }

    /**
     * @notice INV.8: Balance equality holds after governance withdrawal
     */
    function test_INV8_GlobalBalanceEquality_AfterGovernanceWithdrawal() public {
        // 1. Create and forfeit an order
        uint256 orderId = _createAndDepositETH(5 ether);

        vm.prank(contractor);
        core.acceptOrder(orderId);

        vm.prank(client);
        core.raiseDispute(orderId);

        Order memory order = core.getOrder(orderId);
        vm.warp(order.disputeStart + DIS_SEC + 1);
        core.timeoutForfeit(orderId);

        _assertBalanceEquality(address(0));

        // 2. Governance withdraws half of forfeit
        uint256 withdrawAmount = 2.5 ether;
        vm.prank(governance);
        core.withdrawForfeit(address(0), governance, withdrawAmount);

        _assertBalanceEquality(address(0));

        // Verify forfeit balance decreased
        assertEq(core.forfeitBalance(address(0)), 2.5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        INV.10: PULL SEMANTICS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.10: Only withdraw() transfers funds to users
     * @dev WP §4.3 INV.10: "只有 withdraw() 会实际转账给用户"
     *
     * Test Scenario:
     * 1. Settle an order via approveReceipt
     * 2. Verify contractor balance increased internally
     * 3. Verify contractor's ETH balance unchanged (no push payment)
     * 4. Call withdraw()
     * 5. Verify contractor's ETH balance increased
     */
    function test_INV10_PullSemantics_NoAutomaticTransfer() public {
        uint256 contractorBalanceBefore = contractor.balance;

        // 1. Create and settle order
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        vm.prank(contractor);
        core.acceptOrder(orderId);

        vm.prank(contractor);
        core.markReady(orderId);

        vm.prank(client);
        core.approveReceipt(orderId);

        // 2. Verify internal balance increased
        uint256 internalBalance = core.withdrawableOf(address(0), contractor);
        assertEq(internalBalance, ESCROW_AMOUNT);

        // 3. Verify no automatic transfer (INV.10)
        uint256 contractorBalanceAfter = contractor.balance;
        assertEq(
            contractorBalanceAfter,
            contractorBalanceBefore,
            "INV.10 violation: automatic transfer occurred"
        );

        // 4. Call withdraw() - ONLY this should transfer funds
        vm.prank(contractor);
        core.withdraw(address(0));

        // 5. Verify ETH transferred
        assertEq(contractor.balance, contractorBalanceBefore + ESCROW_AMOUNT);
        assertEq(core.withdrawableOf(address(0), contractor), 0);
    }

    /**
     * @notice INV.10: Pull semantics for ERC-20 tokens
     */
    function test_INV10_PullSemantics_ERC20() public {
        uint256 escrow = 500e18; // 500 tokens (within INITIAL_BALANCE)
        uint256 contractorBalanceBefore = token.balanceOf(contractor);

        // 1. Create and settle order
        uint256 orderId = _createAndDepositERC20(escrow);

        vm.prank(contractor);
        core.acceptOrder(orderId);

        vm.prank(contractor);
        core.markReady(orderId);

        vm.prank(client);
        core.approveReceipt(orderId);

        // 2. Verify no automatic transfer
        assertEq(
            token.balanceOf(contractor),
            contractorBalanceBefore,
            "INV.10 violation: ERC-20 automatically transferred"
        );

        // 3. Verify internal balance
        assertEq(core.withdrawableOf(address(token), contractor), escrow);

        // 4. Withdraw
        vm.prank(contractor);
        core.withdraw(address(token));

        // 5. Verify transfer
        assertEq(token.balanceOf(contractor), contractorBalanceBefore + escrow);
        assertEq(core.withdrawableOf(address(token), contractor), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    INV.11: ANCHOR IMMUTABILITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice INV.11: Order anchors (client/contractor/tokenAddr) are immutable
     * @dev WP §4.3 INV.11: "订单锚点（client, contractor, tokenAddr）不可变"
     *
     * Test Scenario:
     * 1. Create order and record anchors
     * 2. Transition through all states
     * 3. Verify anchors never change
     */
    function test_INV11_AnchorImmutability_ThroughAllStates() public {
        // 1. Create order
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // Record anchors at creation
        Order memory initialOrder = core.getOrder(orderId);
        address anchorClient = initialOrder.client;
        address anchorContractor = initialOrder.contractor;
        address anchorToken = initialOrder.tokenAddr;

        // 2. State: Initialized -> Executing
        vm.prank(contractor);
        core.acceptOrder(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 3. State: Executing -> Reviewing
        vm.prank(contractor);
        core.markReady(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 4. State: Reviewing -> Disputing
        vm.prank(client);
        core.raiseDispute(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 5. State: Disputing -> Forfeited
        Order memory disputingOrder = core.getOrder(orderId);
        vm.warp(disputingOrder.disputeStart + DIS_SEC + 1);
        core.timeoutForfeit(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 6. Verify final state
        Order memory finalOrder = core.getOrder(orderId);
        assertEq(uint8(finalOrder.state), uint8(OrderState.Forfeited));
        assertEq(finalOrder.client, anchorClient);
        assertEq(finalOrder.contractor, anchorContractor);
        assertEq(finalOrder.tokenAddr, anchorToken);
    }

    /**
     * @notice INV.11: Anchors immutable through Settled path
     */
    function test_INV11_AnchorImmutability_SettledPath() public {
        // 1. Create order
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        Order memory initialOrder = core.getOrder(orderId);
        address anchorClient = initialOrder.client;
        address anchorContractor = initialOrder.contractor;
        address anchorToken = initialOrder.tokenAddr;

        // 2. Initialized -> Executing
        vm.prank(contractor);
        core.acceptOrder(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 3. Executing -> Reviewing
        vm.prank(contractor);
        core.markReady(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 4. Reviewing -> Settled
        vm.prank(client);
        core.approveReceipt(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 5. Verify final state
        Order memory finalOrder = core.getOrder(orderId);
        assertEq(uint8(finalOrder.state), uint8(OrderState.Settled));
    }

    /**
     * @notice INV.11: Anchors immutable through Cancelled path
     */
    function test_INV11_AnchorImmutability_CancelledPath() public {
        // 1. Create order
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        Order memory initialOrder = core.getOrder(orderId);
        address anchorClient = initialOrder.client;
        address anchorContractor = initialOrder.contractor;
        address anchorToken = initialOrder.tokenAddr;

        // 2. Initialized -> Cancelled
        vm.prank(client);
        core.cancelOrder(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // 3. Verify final state
        Order memory finalOrder = core.getOrder(orderId);
        assertEq(uint8(finalOrder.state), uint8(OrderState.Cancelled));
    }

    /**
     * @notice INV.11: TokenAddr immutability for ERC-20
     */
    function test_INV11_AnchorImmutability_ERC20Token() public {
        uint256 escrow = 100e18; // 100 tokens (within INITIAL_BALANCE)

        // 1. Create ERC-20 order
        uint256 orderId = _createAndDepositERC20(escrow);

        // Record anchors
        Order memory order = core.getOrder(orderId);
        address anchorClient = order.client;
        address anchorContractor = order.contractor;
        address anchorToken = order.tokenAddr;

        // Verify tokenAddr is token
        assertEq(anchorToken, address(token));

        // 2. Transition states
        vm.prank(contractor);
        core.acceptOrder(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        vm.prank(contractor);
        core.markReady(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        vm.prank(client);
        core.approveReceipt(orderId);
        _assertAnchorsUnchanged(orderId, anchorClient, anchorContractor, anchorToken);

        // Final verification: tokenAddr still token
        Order memory finalOrder = core.getOrder(orderId);
        assertEq(finalOrder.tokenAddr, address(token), "INV.11 violation: tokenAddr changed");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Assert INV.8 balance equality for a token
     */
    function _assertBalanceEquality(address tokenAddr) internal view {
        uint256 contractBalance;
        if (tokenAddr == address(0)) {
            contractBalance = address(core).balance;
        } else {
            contractBalance = token.balanceOf(address(core));
        }

        // Sum all user withdrawable balances
        uint256 totalUserBalances = core.withdrawableOf(tokenAddr, client)
            + core.withdrawableOf(tokenAddr, contractor)
            + core.withdrawableOf(tokenAddr, governance);

        uint256 forfeit = core.forfeitBalance(tokenAddr);

        // Sum all pending escrows (non-terminal orders)
        uint256 totalPendingEscrow = _sumPendingEscrows(tokenAddr);

        // INV.8: contractBalance = totalUserBalances + forfeit + totalPendingEscrow
        assertEq(
            contractBalance,
            totalUserBalances + forfeit + totalPendingEscrow,
            "INV.8 violation: balance equation mismatch"
        );
    }

    /**
     * @notice Sum all pending escrows for non-terminal orders
     */
    function _sumPendingEscrows(address tokenAddr) internal view returns (uint256 total) {
        uint256 nextId = core.nextOrderId();
        for (uint256 i = 1; i < nextId; i++) {
            Order memory order = core.getOrder(i);

            // Skip if wrong token
            if (order.tokenAddr != tokenAddr) continue;

            // Only count non-terminal states
            if (
                order.state != OrderState.Settled
                    && order.state != OrderState.Forfeited
                    && order.state != OrderState.Cancelled
            ) {
                total += order.escrow;
            }
        }
    }

    /**
     * @notice Assert order anchors are unchanged
     */
    function _assertAnchorsUnchanged(
        uint256 orderId,
        address expectedClient,
        address expectedContractor,
        address expectedToken
    ) internal view {
        Order memory order = core.getOrder(orderId);

        assertEq(order.client, expectedClient, "INV.11 violation: client changed");
        assertEq(order.contractor, expectedContractor, "INV.11 violation: contractor changed");
        assertEq(order.tokenAddr, expectedToken, "INV.11 violation: tokenAddr changed");
    }
}
