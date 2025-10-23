// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {BaseTest} from "../BaseTest.t.sol";
import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState} from "../../CONTRACTS/core/Types.sol";

/**
 * @title StateMachineTest
 * @notice 测试 NESP 核心状态机（E1-E13）
 * @dev 遵循 WP §3.0-§3.1 状态转换规范
 */
contract StateMachineTest is BaseTest {
    // ============================================
    // E1: acceptOrder (Initialized → Executing)
    // ============================================

    function test_E1_AcceptOrder_Success() public {
        // 创建并充值订单
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _assertState(orderId, OrderState.Initialized);

        // E1: contractor 接单
        vm.prank(contractor);
        core.acceptOrder(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Executing);
        _assertEscrow(orderId, ESCROW_AMOUNT);

        // 验证 startTime 已设置
        Order memory order = core.getOrder(orderId);
        assertGt(order.startTime, 0, "startTime should be set");
    }

    function test_E1_AcceptOrder_RevertWhen_NotContractor() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // 非 contractor 尝试接单
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.acceptOrder(orderId);
    }

    function test_E1_AcceptOrder_RevertWhen_WrongState() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 已经是 Executing 状态，无法再次接单
        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.acceptOrder(orderId);
    }

    // ============================================
    // E2: cancelOrder (Initialized → Cancelled)
    // ============================================

    function test_E2_CancelOrder_Success() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _assertState(orderId, OrderState.Initialized);

        // E2: client 取消订单
        vm.prank(client);
        core.cancelOrder(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Cancelled);

        // 验证 client 已记账退款
        _assertWithdrawable(address(0), client, ESCROW_AMOUNT);
    }

    function test_E2_CancelOrder_RevertWhen_NotClient() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // Initialized 状态下，client 和 contractor 都可以取消
        // 修改测试：第三方无法取消
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.cancelOrder(orderId);
    }

    // ============================================
    // E3: markReady (Executing → Reviewing)
    // ============================================

    function test_E3_MarkReady_Success() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // E3: contractor 标记完成
        vm.prank(contractor);
        core.markReady(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Reviewing);

        // 验证 readyAt 已设置
        Order memory order = core.getOrder(orderId);
        assertGt(order.readyAt, 0, "readyAt should be set");
    }

    function test_E3_MarkReady_RevertWhen_NotContractor() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        vm.prank(client);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.markReady(orderId);
    }

    function test_E3_MarkReady_RevertWhen_WrongState() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        // 仍在 Initialized 状态

        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.markReady(orderId);
    }

    /**
     * @notice 测试 E3: markReady 在履约超时后应该 revert
     * @dev WP §3.3 G.E3: 要求 now < startTime + D_due（非超时路径）
     */
    function test_E3_MarkReady_RevertWhen_AfterDueTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        Order memory order = core.getOrder(orderId);

        // 快进到履约超时后
        vm.warp(order.startTime + order.dueSec + 1);

        // contractor 尝试标记完成应该 revert
        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.markReady(orderId);
    }

    /**
     * @notice 测试 E3: markReady 恰好在履约超时时刻应该 revert
     * @dev WP §3.3: 精确边界时刻，仅允许超时路径（E6 cancelOrder）
     */
    function test_E3_MarkReady_RevertWhen_ExactlyAtDueDeadline() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        Order memory order = core.getOrder(orderId);

        // 快进到恰好履约超时时刻
        vm.warp(order.startTime + order.dueSec);

        // contractor 尝试标记完成应该 revert（边界时刻仅允许 E6）
        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.markReady(orderId);
    }

    // ============================================
    // E4: approveReceipt (Executing → Settled)
    // ============================================

    function test_E4_ApproveReceipt_FromExecuting() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // E4: client 直接验收（从 Executing）
        vm.prank(client);
        core.approveReceipt(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Settled);

        // 验证 contractor 收款（A = E）
        _assertWithdrawable(address(0), contractor, ESCROW_AMOUNT);
    }

    function test_E4_ApproveReceipt_RevertWhen_NotClient() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.approveReceipt(orderId);
    }

    // ============================================
    // E5: raiseDispute (Executing → Disputing)
    // ============================================

    function test_E5_RaiseDispute_ByClient() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // E5: client 发起争议
        vm.prank(client);
        core.raiseDispute(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Disputing);

        // 验证 disputeStart 已设置
        Order memory order = core.getOrder(orderId);
        assertGt(order.disputeStart, 0, "disputeStart should be set");
    }

    function test_E5_RaiseDispute_ByContractor() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // E5: contractor 也可以发起争议
        vm.prank(contractor);
        core.raiseDispute(orderId);

        _assertState(orderId, OrderState.Disputing);
    }

    function test_E5_RaiseDispute_RevertWhen_ThirdParty() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 第三方无法发起争议
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.raiseDispute(orderId);
    }

    /**
     * @notice 测试 E5: raiseDispute 在履约超时后应该 revert
     * @dev WP §3.3 G.E5: 要求 state = Executing AND now < startTime + D_due（非超时路径）
     */
    function test_E5_RaiseDispute_RevertWhen_AfterDueTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        Order memory order = core.getOrder(orderId);

        // 快进到履约超时后
        vm.warp(order.startTime + order.dueSec + 1);

        // client 尝试发起争议应该 revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.raiseDispute(orderId);

        // contractor 尝试发起争议也应该 revert
        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.raiseDispute(orderId);
    }

    /**
     * @notice 测试 E5: raiseDispute 恰好在履约超时时刻应该 revert
     * @dev WP §3.3: 精确边界时刻，仅允许超时路径（E6 cancelOrder）
     */
    function test_E5_RaiseDispute_RevertWhen_ExactlyAtDueDeadline() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        Order memory order = core.getOrder(orderId);

        // 快进到恰好履约超时时刻
        vm.warp(order.startTime + order.dueSec);

        // client 尝试发起争议应该 revert（边界时刻仅允许 E6）
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.raiseDispute(orderId);
    }

    // ============================================
    // E6/E7: cancelOrder (Executing → Cancelled)
    // ============================================

    function test_E6_CancelOrder_ByClient_FromExecuting() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // E6: client 取消(必须等待履约超时 - WP §3.3 G.E6)
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec + 1);

        vm.prank(client);
        core.cancelOrder(orderId);

        _assertState(orderId, OrderState.Cancelled);
        _assertWithdrawable(address(0), client, ESCROW_AMOUNT);
    }

    function test_E7_CancelOrder_ByContractor_FromExecuting() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // E7: contractor 取消
        vm.prank(contractor);
        core.cancelOrder(orderId);

        _assertState(orderId, OrderState.Cancelled);
        _assertWithdrawable(address(0), client, ESCROW_AMOUNT);
    }

    // ============================================
    // E8: approveReceipt (Reviewing → Settled)
    // ============================================

    function test_E8_ApproveReceipt_FromReviewing() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // E8: client 验收（从 Reviewing）
        vm.prank(client);
        core.approveReceipt(orderId);

        _assertState(orderId, OrderState.Settled);
        _assertWithdrawable(address(0), contractor, ESCROW_AMOUNT);
    }

    // ============================================
    // E9: timeoutSettle (Reviewing → Settled)
    // ============================================

    function test_E9_TimeoutSettle_Success() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 快进时间：超过评审窗口
        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec + 1);

        // E9: 任何人都可以触发超时结清
        vm.prank(thirdParty);
        core.timeoutSettle(orderId);

        _assertState(orderId, OrderState.Settled);
        _assertWithdrawable(address(0), contractor, ESCROW_AMOUNT);
    }

    function test_E9_TimeoutSettle_RevertWhen_NotTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 未超时
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.timeoutSettle(orderId);
    }

    function test_E9_TimeoutSettle_RevertWhen_WrongState() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId); // 不是 Reviewing 状态

        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.timeoutSettle(orderId);
    }

    // ============================================
    // E10: raiseDispute (Reviewing → Disputing)
    // ============================================

    function test_E10_RaiseDispute_FromReviewing() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // E10: client 从 Reviewing 发起争议
        vm.prank(client);
        core.raiseDispute(orderId);

        _assertState(orderId, OrderState.Disputing);
    }

    // ============================================
    // E11: cancelOrder (Reviewing → Cancelled)
    // ============================================

    function test_E11_CancelOrder_FromReviewing() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // E11: contractor 可以从 Reviewing 取消
        vm.prank(contractor);
        core.cancelOrder(orderId);

        _assertState(orderId, OrderState.Cancelled);
        _assertWithdrawable(address(0), client, ESCROW_AMOUNT);
    }

    function test_E11_CancelOrder_RevertWhen_ClientTries() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // Reviewing 状态下，client 不能取消
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.cancelOrder(orderId);
    }

    // ============================================
    // E13: timeoutForfeit (Disputing → Forfeited)
    // ============================================

    function test_E13_TimeoutForfeit_Success() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toDisputing(orderId);

        // 快进时间：超过争议窗口
        Order memory order = core.getOrder(orderId);
        vm.warp(order.disputeStart + order.disSec + 1);

        // E13: 任何人都可以触发没收
        vm.prank(thirdParty);
        core.timeoutForfeit(orderId);

        _assertState(orderId, OrderState.Forfeited);

        // 验证托管额进入 ForfeitPool
        assertEq(core.forfeitBalance(address(0)), ESCROW_AMOUNT, "ForfeitPool should receive escrow");
    }

    function test_E13_TimeoutForfeit_RevertWhen_NotTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toDisputing(orderId);

        // 未超时
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.timeoutForfeit(orderId);
    }

    function test_E13_TimeoutForfeit_RevertWhen_WrongState() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId); // 不是 Disputing 状态

        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.timeoutForfeit(orderId);
    }

    // ============================================
    // 综合测试：正常流程（Happy Path）
    // ============================================

    function test_HappyPath_FullCycle() public {
        // 1. 创建并充值
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _assertState(orderId, OrderState.Initialized);

        // 2. 接单（E1）
        vm.prank(contractor);
        core.acceptOrder(orderId);
        _assertState(orderId, OrderState.Executing);

        // 3. 标记完成（E3）
        vm.prank(contractor);
        core.markReady(orderId);
        _assertState(orderId, OrderState.Reviewing);

        // 4. 验收（E8）
        vm.prank(client);
        core.approveReceipt(orderId);
        _assertState(orderId, OrderState.Settled);

        // 5. 验证 contractor 可提现
        _assertWithdrawable(address(0), contractor, ESCROW_AMOUNT);

        // 6. contractor 提现
        uint256 balanceBefore = contractor.balance;
        vm.prank(contractor);
        core.withdraw(address(0));

        _assertETHBalance(contractor, balanceBefore + ESCROW_AMOUNT);
        _assertWithdrawable(address(0), contractor, 0);
    }

    // ============================================
    // 综合测试：争议流程
    // ============================================

    function test_DisputePath_FullCycle() public {
        // 1. 创建并充值
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // 2. 接单 → 标记完成
        _toReviewing(orderId);

        // 3. client 发起争议（E10）
        vm.prank(client);
        core.raiseDispute(orderId);
        _assertState(orderId, OrderState.Disputing);

        // 4. 争议窗口超时（E13）
        Order memory order = core.getOrder(orderId);
        vm.warp(order.disputeStart + order.disSec + 1);

        vm.prank(thirdParty);
        core.timeoutForfeit(orderId);
        _assertState(orderId, OrderState.Forfeited);

        // 5. 验证 ForfeitPool 接收托管额
        assertEq(core.forfeitBalance(address(0)), ESCROW_AMOUNT);

        // 6. 治理提款
        vm.prank(governance);
        core.withdrawForfeit(address(0), governance, ESCROW_AMOUNT);

        _assertETHBalance(governance, INITIAL_BALANCE + ESCROW_AMOUNT);
    }
}
