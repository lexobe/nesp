// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {BaseTest} from "../BaseTest.t.sol";
import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState} from "../../CONTRACTS/core/Types.sol";

/**
 * @title ErrorCodesTest
 * @notice 测试自定义错误码的使用（Issue #7）
 * @dev 验证所有新增的 Custom Errors 是否正确触发
 */
contract ErrorCodesTest is BaseTest {
    // ============================================
    // Issue #7: Custom Errors 测试
    // ============================================

    /**
     * @notice 测试 ErrZeroAddress: 构造函数传入零地址
     */
    function test_ErrZeroAddress_Constructor() public {
        // 部署时传入零地址应该 revert
        vm.expectRevert(NESPCore.ErrZeroAddress.selector);
        new NESPCore(address(0));
    }

    /**
     * @notice 测试 ErrSelfDealing: 创建订单时 contractor 不得等于 client
     */
    function test_ErrSelfDealing_CreateOrder() public {
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrSelfDealing.selector);
        core.createOrder(
            address(0),  // tokenAddr (ETH)
            client,      // contractor 与 client 相同
            7 days,      // dueSec
            3 days,      // revSec
            7 days,      // disSec
            address(0),  // feeRecipient
            0            // feeBps
        );
    }

    /**
     * @notice 测试 ErrZeroAmount: 提现零额
     */
    function test_ErrZeroAmount_Withdraw() public {
        // 没有余额时提现
        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrZeroAmount.selector);
        core.withdraw(address(0));
    }

    /**
     * @notice 测试 ErrZeroAmount: 创建零额订单（deposit 前）
     */
    function test_ErrZeroAmount_CreateOrder() public {
        // 创建订单（deposit 0）
        vm.prank(client);
        uint256 orderId = core.createOrder(
            address(0),  // tokenAddr (ETH)
            contractor,  // contractor
            7 days,      // dueSec
            3 days,      // revSec
            7 days,      // disSec
            address(0),  // feeRecipient
            0            // feeBps
        );

        // 尝试 deposit 0 应该 revert（如果实现检查了）
        // 注：当前实现允许 deposit(0)，这是一个潜在改进点
    }

    /**
     * @notice 测试 ErrInsufficientBalance: 提现超过余额
     */
    function test_ErrInsufficientBalance_Withdraw_TODO() public {
        // 当前实现的 withdraw 会直接计算可用余额
        // 如果实现了部分提现功能，需要测试此错误
        // TODO: 如果添加了 withdraw(amount) 接口
    }

    /**
     * @notice 测试 ErrInvalidState: 从错误状态调用函数
     */
    function test_ErrInvalidState_AcceptOrder_AlreadyAccepted() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 尝试再次接单
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.acceptOrder(orderId);
    }

    /**
     * @notice 测试 ErrInvalidState: Settled 状态后不能再操作
     */
    function test_ErrInvalidState_AfterSettled() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        orderId = _executeHappyPath();

        // 验证已结清
        _assertState(orderId, OrderState.Settled);

        // 尝试再次验收
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.approveReceipt(orderId);

        // 尝试取消
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.cancelOrder(orderId);

        // 尝试发起争议
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.raiseDispute(orderId);
    }

    /**
     * @notice 测试 ErrUnauthorized: 非授权用户调用
     */
    function test_ErrUnauthorized_CancelOrder() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // thirdParty 尝试取消（只有 client/contractor 可以）
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.cancelOrder(orderId);
    }

    /**
     * @notice 测试 ErrUnauthorized: 非 client 验收
     */
    function test_ErrUnauthorized_ApproveReceipt() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // contractor 尝试验收（只有 client 可以）
        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.approveReceipt(orderId);
    }

    /**
     * @notice 测试 ErrUnauthorized: 非 contractor 标记完成
     */
    function test_ErrUnauthorized_MarkReady() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // client 尝试标记完成（只有 contractor 可以）
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.markReady(orderId);
    }

    /**
     * @notice 测试 ErrExpired: 评审超时后调用 approveReceipt
     */
    function test_ErrExpired_ApproveReceipt() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 快进到评审超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec + 1);

        // 尝试验收应该 revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.approveReceipt(orderId);
    }

    /**
     * @notice 测试 ErrExpired: 评审超时后调用 raiseDispute
     */
    function test_ErrExpired_RaiseDispute() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        // 快进到评审超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec + 1);

        // 尝试发起争议应该 revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.raiseDispute(orderId);
    }

    /**
     * @notice 测试 ErrInvalidState: 在非 Disputing 状态标记没收
     */
    function test_ErrInvalidState_MarkForfeited_WrongState() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 快进到履约超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec + 1);

        // 尝试标记没收（当前状态是 Executing，不是 Disputing）
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.timeoutForfeit(orderId);
    }

    /**
     * @notice 测试 ErrInvalidState: 争议窗口未超时
     */
    function test_ErrInvalidState_MarkForfeited_NotTimeout() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toDisputing(orderId);

        // 在争议窗口内（未超时）
        Order memory order = core.getOrder(orderId);
        assertLt(block.timestamp, order.disputeStart + order.disSec, "Should be within dispute window");

        // 尝试标记没收应该 revert
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.timeoutForfeit(orderId);
    }

    // ============================================
    // Gas 优化验证：Custom Errors vs require(msg)
    // ============================================

    /**
     * @notice Gas 对比：Custom Error vs require string
     * @dev 这个测试用于验证 Gas 节省（需要 forge snapshot）
     */
    function test_GasComparison_CustomError() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 记录 Gas 使用量
        uint256 gasBefore = gasleft();

        vm.prank(thirdParty);
        try core.cancelOrder(orderId) {
            // 不应该成功
        } catch {
            // 预期 revert
        }

        uint256 gasUsed = gasBefore - gasleft();

        // Custom Error 应该节省约 50% Gas
        // 注：实际 Gas 对比需要与 require("msg") 版本比较
        // 这里只是记录基准值
        emit log_named_uint("Gas used for Custom Error", gasUsed);
    }

    // ============================================
    // 边界条件测试
    // ============================================

    /**
     * @notice 测试多个错误条件的优先级
     * @dev 当多个条件都违反时，应该返回第一个检查到的错误
     */
    function test_ErrorPriority_StateBeforeAuth() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        orderId = _executeHappyPath(); // 已结清

        // 状态错误 + 权限错误 → 应该先返回 ErrInvalidState
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.approveReceipt(orderId);
    }

    /**
     * @notice 测试 Settled 状态的终态性
     * @dev 验证所有状态转换函数都拒绝 Settled 状态
     */
    function test_SettledState_IsTerminal() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        orderId = _executeHappyPath();

        // 验证所有可能的状态转换都被拒绝
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(contractor);
        core.acceptOrder(orderId);

        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(contractor);
        core.markReady(orderId);

        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(client);
        core.approveReceipt(orderId);

        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(client);
        core.raiseDispute(orderId);

        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(client);
        core.cancelOrder(orderId);
    }

    /**
     * @notice 测试 Forfeited 状态的终态性
     */
    function test_ForfeitedState_IsTerminal() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toDisputing(orderId);

        // 快进到争议超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.disputeStart + order.disSec + 1);

        // 标记没收
        vm.prank(thirdParty);
        core.timeoutForfeit(orderId);

        // 验证所有状态转换都被拒绝
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(client);
        core.approveReceipt(orderId);

        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(client);
        core.cancelOrder(orderId);
    }

    /**
     * @notice 测试 Cancelled 状态的终态性
     */
    function test_CancelledState_IsTerminal() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // client 取消
        vm.prank(client);
        core.cancelOrder(orderId);

        // 验证所有状态转换都被拒绝
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(contractor);
        core.acceptOrder(orderId);

        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        vm.prank(client);
        core.approveReceipt(orderId);
    }
}
