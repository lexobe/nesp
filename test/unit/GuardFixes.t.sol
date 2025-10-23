// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {BaseTest} from "../BaseTest.t.sol";
import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState} from "../../CONTRACTS/core/Types.sol";

/**
 * @title GuardFixesTest
 * @notice 测试 P0/P1 修复的守卫逻辑
 * @dev 验证 Issue #2 (E6), Issue #4 (INV.6) 的修复
 */
contract GuardFixesTest is BaseTest {
    // ============================================
    // Issue #2: E6 时间守卫测试
    // ============================================

    /**
     * @notice 测试 E6: client 在履约期内不能取消 Executing 订单
     */
    function test_E6_CancelOrder_RevertWhen_NotTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 在履约期内（未超时）
        Order memory order = core.getOrder(orderId);
        assertLt(block.timestamp, order.startTime + order.dueSec, "Should be before timeout");

        // client 尝试取消应该 revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.cancelOrder(orderId);

        // 验证状态未改变
        _assertState(orderId, OrderState.Executing);
    }

    /**
     * @notice 测试 E6: client 在 readyAt 已设置后不能取消
     */
    function test_E6_CancelOrder_RevertWhen_AlreadyReady() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId); // 已标记完成(state=Reviewing)

        // 快进到履约超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec + 1);

        // 验证确实超时了
        assertGe(block.timestamp, order.startTime + order.dueSec, "Should be after timeout");

        // client 不能取消 Reviewing 状态的订单(E11只允许contractor)
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.cancelOrder(orderId);

        // 验证状态未改变
        _assertState(orderId, OrderState.Reviewing);
    }

    /**
     * @notice 测试 E6: client 可以在履约超时后取消 Executing 订单
     */
    function test_E6_CancelOrder_Success_AfterTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 快进到履约超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec + 1);

        // 验证确实超时了
        assertGe(block.timestamp, order.startTime + order.dueSec, "Should be after timeout");
        assertEq(order.readyAt, 0, "readyAt should not be set");

        // client 可以取消
        vm.prank(client);
        core.cancelOrder(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Cancelled);
        _assertWithdrawable(address(0), client, ESCROW_AMOUNT);
    }

    /**
     * @notice 测试 E6: 边界条件 - 恰好在超时时刻
     */
    function test_E6_CancelOrder_Success_ExactlyAtTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 快进到恰好超时时刻
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec);

        // 恰好超时时可以取消（WP §3.3 G.E6: now >= startTime + D_due）
        vm.prank(client);
        core.cancelOrder(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Cancelled);
        _assertWithdrawable(address(0), client, ESCROW_AMOUNT);
    }

    /**
     * @notice 测试 E7: contractor 可以随时取消 Executing 订单（无时间限制）
     */
    function test_E7_CancelOrder_Success_ContractorAnytime() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // contractor 在履约期内就可以取消（无时间限制）
        vm.prank(contractor);
        core.cancelOrder(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Cancelled);
        _assertWithdrawable(address(0), client, ESCROW_AMOUNT);
    }

    // ============================================
    // Issue #4: INV.6 入口前抢占测试
    // ============================================

    /**
     * @notice 测试 INV.6: approveReceipt 在评审超时后应 revert
     */
    function test_INV6_ApproveReceipt_RevertWhen_ReviewingTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 快进到评审超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec + 1);

        // 验证确实超时了
        assertGe(block.timestamp, order.readyAt + order.revSec, "Should be after review timeout");

        // client 尝试验收应该 revert（应使用 timeoutSettle）
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.approveReceipt(orderId);

        // 验证状态未改变
        _assertState(orderId, OrderState.Reviewing);
    }

    /**
     * @notice 测试 INV.6: approveReceipt 在评审期内可以正常执行
     */
    function test_INV6_ApproveReceipt_Success_WithinReviewPeriod() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 在评审期内（未超时）
        Order memory order = core.getOrder(orderId);
        assertLt(block.timestamp, order.readyAt + order.revSec, "Should be within review period");

        // client 可以正常验收
        vm.prank(client);
        core.approveReceipt(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Settled);
        _assertWithdrawable(address(0), contractor, ESCROW_AMOUNT);
    }

    /**
     * @notice 测试 INV.6: approveReceipt 从 Executing 状态调用不受超时限制
     */
    function test_INV6_ApproveReceipt_Success_FromExecuting() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 从 Executing 状态直接验收不受评审窗口限制
        vm.prank(client);
        core.approveReceipt(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Settled);
    }

    /**
     * @notice 测试 INV.6: raiseDispute 在评审超时后应 revert
     */
    function test_INV6_RaiseDispute_RevertWhen_ReviewingTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 快进到评审超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec + 1);

        // 验证确实超时了
        assertGe(block.timestamp, order.readyAt + order.revSec, "Should be after review timeout");

        // client 尝试发起争议应该 revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.raiseDispute(orderId);

        // 验证状态未改变
        _assertState(orderId, OrderState.Reviewing);
    }

    /**
     * @notice 测试 INV.6: raiseDispute 在评审期内可以正常执行
     */
    function test_INV6_RaiseDispute_Success_WithinReviewPeriod() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 在评审期内（未超时）
        Order memory order = core.getOrder(orderId);
        assertLt(block.timestamp, order.readyAt + order.revSec, "Should be within review period");

        // client 可以正常发起争议
        vm.prank(client);
        core.raiseDispute(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Disputing);
    }

    /**
     * @notice 测试 INV.6: raiseDispute 从 Executing 状态调用不受超时限制
     */
    function test_INV6_RaiseDispute_Success_FromExecuting() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 从 Executing 状态发起争议不受评审窗口限制
        vm.prank(client);
        core.raiseDispute(orderId);

        // 验证状态转换
        _assertState(orderId, OrderState.Disputing);
    }

    /**
     * @notice 测试 INV.6: 边界条件 - 恰好在评审超时时刻
     */
    function test_INV6_ExactlyAtReviewTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 快进到恰好评审超时时刻
        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec);

        // 恰好超时时仍然不能调用（需要 >= 判断）
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.approveReceipt(orderId);
    }

    // ============================================
    // 综合测试：E6 + INV.6 组合场景
    // ============================================

    /**
     * @notice 测试完整流程：client 超时取消 → contractor 重新接单 → 评审超时 → 自动结清
     */
    function test_Combined_TimeoutCancelAndAutoSettle() public {
        // 1. 创建订单
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 2. 快进到履约超时，client 取消
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec + 1);

        vm.prank(client);
        core.cancelOrder(orderId);
        _assertState(orderId, OrderState.Cancelled);

        // 3. client 重新创建订单
        uint256 orderId2 = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId2);

        // 4. 评审超时，使用 timeoutSettle
        Order memory order2 = core.getOrder(orderId2);
        vm.warp(order2.readyAt + order2.revSec + 1);

        vm.prank(thirdParty);
        core.timeoutSettle(orderId2);

        // 验证最终状态
        _assertState(orderId2, OrderState.Settled);
        _assertWithdrawable(address(0), contractor, ESCROW_AMOUNT);
    }

    /**
     * @notice 测试 INV.6 防止延迟攻击：超时后立即尝试验收
     */
    function test_INV6_PreventDelayAttack() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 快进到评审窗口即将结束
        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec);

        // 在同一个区块内，先有人调用 timeoutSettle（Keeper）
        // 但 client 抢先调用 approveReceipt（MEV）
        // INV.6 应该阻止 client 的抢先
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.approveReceipt(orderId);

        // timeoutSettle 应该成功
        vm.prank(thirdParty);
        core.timeoutSettle(orderId);

        _assertState(orderId, OrderState.Settled);
    }
}
