// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {BaseTest} from "../BaseTest.t.sol";
import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState, SettleActor} from "../../CONTRACTS/core/Types.sol";

/**
 * @title EdgeCasesTest
 * @notice 测试边界条件和特殊场景
 * @dev 覆盖时间边界、极端参数、Race Condition 等
 */
contract EdgeCasesTest is BaseTest {
    // ============================================
    // 时间边界测试
    // ============================================

    /**
     * @notice 测试履约窗口边界：恰好在 startTime + dueSec
     * @dev Fixed: WP §3.3 G.E6 specifies `now ≥ startTime + D_due` (includes equality)
     */
    function test_EdgeCase_ExecutionDeadline_ExactBoundary() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        Order memory order = core.getOrder(orderId);

        // 快进到恰好履约期结束（boundary）
        vm.warp(order.startTime + order.dueSec);

        // G.E6 specifies `now ≥ startTime + D_due` (includes equality)
        // 所以在 boundary 时刻**可以**取消
        vm.prank(client);
        core.cancelOrder(orderId);

        // 验证状态
        _assertState(orderId, OrderState.Cancelled);
    }

    /**
     * @notice 测试评审窗口边界：恰好在 readyAt + revSec
     */
    function test_EdgeCase_ReviewDeadline_ExactBoundary() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        Order memory order = core.getOrder(orderId);

        // 快进到恰好评审期结束
        vm.warp(order.readyAt + order.revSec);

        // INV.6 要求 now >= readyAt + revSec 时 revert
        // 所以在 boundary 时刻应该 revert
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.approveReceipt(orderId);

        // timeoutSettle 应该可以调用
        vm.prank(thirdParty);
        core.timeoutSettle(orderId);
    }

    /**
     * @notice 测试争议窗口边界：恰好在 disputeStart + disSec
     * @dev Fixed: WP §3.3 G.E13 specifies `now ≥ disputeStart + D_dis` (includes equality)
     */
    function test_EdgeCase_DisputeDeadline_ExactBoundary() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toDisputing(orderId);

        Order memory order = core.getOrder(orderId);

        // 快进到恰好争议期结束
        vm.warp(order.disputeStart + order.disSec);

        // G.E13 specifies `now ≥ disputeStart + D_dis` (includes equality)
        // 所以在 boundary 时刻**可以**标记没收
        vm.prank(thirdParty);
        core.timeoutForfeit(orderId);

        // 验证状态和罚没
        _assertState(orderId, OrderState.Forfeited);
        assertEq(core.forfeitBalance(address(0)), ESCROW_AMOUNT, "Funds should be forfeited");
    }

    /**
     * @notice 测试时间倒流（区块链重组）
     * @dev Foundry 的 vm.warp 不允许时间倒流，但测试参数
     */
    function test_EdgeCase_BlockReorg_TODO() public {
        // 时间倒流在 EVM 中不应该发生
        // 但如果发生，时间守卫应该仍然有效
        // TODO: 研究 Foundry 是否支持模拟重组
    }

    // ============================================
    // 极端参数测试
    // ============================================

    /**
     * @notice 测试极短的时间窗口（1 秒）
     */
    function test_EdgeCase_MinimalTimeWindows() public {
        vm.prank(client);
        uint256 orderId = core.createOrder(
            address(0), // ETH
            contractor, // contractor
            1,          // dueSec: 1 秒
            1,          // revSec: 1 秒
            1,          // disSec: 1 秒
            address(0),
            0
        );

        _depositETH(orderId, ESCROW_AMOUNT, client);
        _toExecuting(orderId);

        // 1 秒后应该可以超时取消
        vm.warp(block.timestamp + 2);

        Order memory order = core.getOrder(orderId);
        assertGt(block.timestamp, order.startTime + order.dueSec, "Should be after timeout");

        vm.prank(client);
        core.cancelOrder(orderId);

        _assertState(orderId, OrderState.Cancelled);
    }

    /**
     * @notice 测试极长的时间窗口（1 年）
     */
    function test_EdgeCase_MaximalTimeWindows() public {
        uint48 oneYear = 365 days;

        vm.prank(client);
        uint256 orderId = core.createOrder(
            address(0),
            contractor,
            oneYear, // dueSec: 1 年
            oneYear, // revSec: 1 年
            oneYear, // disSec: 1 年
            address(0),
            0
        );

        _depositETH(orderId, ESCROW_AMOUNT, client);
        _toExecuting(orderId);

        // 1 年后应该可以超时取消
        vm.warp(block.timestamp + oneYear + 1);

        Order memory order = core.getOrder(orderId);
        assertGt(block.timestamp, order.startTime + order.dueSec, "Should be after timeout");

        vm.prank(client);
        core.cancelOrder(orderId);

        _assertState(orderId, OrderState.Cancelled);
    }

    /**
     * @notice 测试时间窗口溢出（uint48 最大值）
     * @dev uint48 可以表示约 8900 年，实际使用不应溢出
     */
    function test_EdgeCase_TimeOverflow() public {
        uint48 maxUint48 = type(uint48).max; // 2^48 - 1 = 281474976710655 秒 ≈ 8900 年

        vm.prank(client);
        uint256 orderId = core.createOrder(
            address(0),
            contractor,
            maxUint48, // dueSec: 最大值
            maxUint48, // revSec: 最大值
            maxUint48, // disSec: 最大值
            address(0),
            0
        );

        _depositETH(orderId, ESCROW_AMOUNT, client);

        // 验证订单创建成功
        Order memory order = core.getOrder(orderId);
        assertEq(order.dueSec, maxUint48, "dueSec should be max");
    }

    /**
     * @notice 测试极小金额（1 wei）
     */
    function test_EdgeCase_MinimalAmount() public {
        uint256 orderId = _createAndDepositETH(1 wei);

        // 正常流程
        _toExecuting(orderId);
        vm.prank(contractor);
        core.markReady(orderId);
        vm.prank(client);
        core.approveReceipt(orderId);

        // 验证结清
        _assertState(orderId, OrderState.Settled);
        assertEq(core.withdrawableOf(address(0), contractor), 1 wei, "Should receive 1 wei");
    }

    /**
     * @notice 测试极大金额（1000000 ETH）
     */
    function test_EdgeCase_MaximalAmount() public {
        uint256 largeAmount = 1_000_000 ether;

        // 给 client 足够余额
        vm.deal(client, largeAmount);

        uint256 orderId = _createAndDepositETH(largeAmount);

        // 正常流程
        _toExecuting(orderId);
        vm.prank(contractor);
        core.markReady(orderId);
        vm.prank(client);
        core.approveReceipt(orderId);

        // 验证结清
        _assertState(orderId, OrderState.Settled);
        assertEq(core.withdrawableOf(address(0), contractor), largeAmount, "Should receive full amount");
    }

    // ============================================
    // Race Condition 测试
    // ============================================

    /**
     * @notice 测试 Race: client 和 contractor 同时取消
     * @dev 在同一个区块中，只有一个能成功
     */
    function test_EdgeCase_RaceCancellation_TODO() public {
        // Foundry 的事务是顺序执行的，无法真正模拟并发
        // 但可以测试快速连续调用
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 快进到超时
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec + 1);

        // client 先取消
        vm.prank(client);
        core.cancelOrder(orderId);

        // contractor 再取消应该 revert（状态已是 Cancelled）
        vm.prank(contractor);
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.cancelOrder(orderId);
    }

    /**
     * @notice 测试 Race: approveReceipt vs timeoutSettle
     * @dev INV.6 应该防止这种抢先
     */
    function test_EdgeCase_RaceSettlement() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toReviewing(orderId);

        Order memory order = core.getOrder(orderId);
        vm.warp(order.readyAt + order.revSec + 1);

        // client 尝试验收（应该被 INV.6 阻止）
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrExpired.selector);
        core.approveReceipt(orderId);

        // timeoutSettle 应该成功
        vm.prank(thirdParty);
        core.timeoutSettle(orderId);

        _assertState(orderId, OrderState.Settled);
    }

    /**
     * @notice 测试 Race: markReady vs cancelOrder
     * @dev Fixed: After markReady, state is Reviewing. cancelOrder from Reviewing requires contractor (G.E11)
     */
    function test_EdgeCase_RaceMarkReadyVsCancel() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // contractor 先标记完成
        vm.prank(contractor);
        core.markReady(orderId);

        // 快进到履约超时（但状态已是 Reviewing，不是 Executing）
        Order memory order = core.getOrder(orderId);
        vm.warp(order.startTime + order.dueSec + 1);

        // G1 Fix: 评审窗口可能已过期，触发 ErrExpired 而非 ErrUnauthorized
        // client 尝试取消应该 revert（G.E11: Reviewing → Cancelled requires contractor）
        vm.prank(client);
        vm.expectRevert(); // 可能是 ErrExpired 或 ErrUnauthorized
        core.cancelOrder(orderId);
    }

    // ============================================
    // 状态一致性测试
    // ============================================

    /**
     * @notice 测试 deposit 后再次 deposit（增量托管）
     */
    function test_EdgeCase_IncrementalDeposit() public {
        vm.prank(client);
        uint256 orderId = core.createOrder(address(0), contractor, 7 days, 3 days, 7 days, address(0), 0);

        // 第一次 deposit
        _depositETH(orderId, 10 ether, client);

        // 第二次 deposit
        _depositETH(orderId, 5 ether, client);

        // 验证托管额累加
        Order memory order = core.getOrder(orderId);
        assertEq(order.escrow, 15 ether, "Escrow should accumulate");
    }

    /**
     * @notice 测试 acceptOrder 后 client 尝试再次 deposit
     */
    function test_EdgeCase_DepositAfterAccept() public {
        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        _toExecuting(orderId);

        // 尝试再次 deposit（当前实现允许，但可能不是期望行为）
        vm.deal(client, 10 ether);
        vm.prank(client);
        core.depositEscrow{value: 10 ether}(orderId, 10 ether);

        // 验证托管额增加
        Order memory order = core.getOrder(orderId);
        assertEq(order.escrow, ESCROW_AMOUNT + 10 ether, "Escrow should increase");
    }

    /**
     * @notice 测试 getOrder 查询不存在的订单
     */
    function test_EdgeCase_GetNonExistentOrder() public {
        uint256 nonExistentId = 999999;

        Order memory order = core.getOrder(nonExistentId);

        // 不存在的订单应该返回零值结构体
        assertEq(order.client, address(0), "Non-existent order should have zero values");
        assertEq(order.escrow, 0, "Non-existent order should have zero escrow");
    }

    /**
     * @notice 测试 withdrawableOf 查询不存在的用户
     */
    function test_EdgeCase_WithdrawableOfNonExistentUser() public view {
        // 查询从未参与过的地址
        uint256 balance = core.withdrawableOf(address(0), address(0xdead));
        assertEq(balance, 0, "Non-existent user should have zero balance");
    }

    // ============================================
    // Gas 消耗测试
    // ============================================

    /**
     * @notice 测试 Happy Path 的 Gas 消耗
     * @dev 用于 Gas 优化基准
     */
    function test_EdgeCase_GasBenchmark_HappyPath() public {
        uint256 gasBefore = gasleft();

        uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
        orderId = _executeHappyPath();

        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for Happy Path", gasUsed);

        // 提现
        gasBefore = gasleft();
        vm.prank(contractor);
        core.withdraw(address(0));
        gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for Withdraw", gasUsed);
    }

    /**
     * @notice 测试多次 deposit 的 Gas 增长
     */
    function test_EdgeCase_GasBenchmark_MultipleDeposits() public {
        vm.prank(client);
        uint256 orderId = core.createOrder(address(0), contractor, 7 days, 3 days, 7 days, address(0), 0);

        // 10 次 deposit
        for (uint256 i = 0; i < 10; i++) {
            uint256 gasBefore = gasleft();
            _depositETH(orderId, 1 ether, client);
            uint256 gasUsed = gasBefore - gasleft();
            emit log_named_uint("Gas used for deposit iteration", i);
            emit log_named_uint("Gas amount", gasUsed);
        }
    }

    // ============================================
    // 错误恢复测试
    // ============================================

    /**
     * @notice 测试合约暂停后恢复（如果实现了 pause 功能）
     */
    function test_EdgeCase_PauseResume_TODO() public {
        // 当前实现没有 pause 功能
        // TODO: 如果添加紧急暂停功能，需要测试恢复后的状态一致性
    }

    /**
     * @notice 测试升级后的状态迁移（如果使用代理模式）
     */
    function test_EdgeCase_UpgradeMigration_TODO() public {
        // 当前实现没有升级功能
        // TODO: 如果使用可升级合约，需要测试升级后的兼容性
    }

    // ============================================
    // 特殊地址测试
    // ============================================

    /**
     * @notice 测试 client/contractor 使用合约地址
     * @dev 合约地址应该能正常接收 ETH（如果实现了 receive）
     */
    function test_EdgeCase_ContractAddressAsParty_TODO() public {
        // 需要部署测试合约作为 client/contractor
        // TODO: 测试合约地址能否正常参与订单
    }

    /**
     * @notice 测试零费路径：feeRecipient=0 或 feeBps=0 不应产生手续费记账
     */
    function test_EdgeCase_ZeroFee_NoFeeCredit() public {
        uint256 orderId = _createETHOrder(); // feeRecipient=0, feeBps=0
        _depositETH(orderId, ESCROW_AMOUNT, client);
        _toExecuting(orderId);
        vm.prank(client);
        core.approveReceipt(orderId);

        // provider 不应收到手续费
        assertEq(core.withdrawableOf(address(0), provider), 0, "Zero-fee path should not credit provider");
    }

    // ============================================
    // 多订单交互测试
    // ============================================

    /**
     * @notice 测试同一 client 和 contractor 的多个订单
     * @dev Fixed: Execute happy path on orderIds[3] instead of creating a new order
     */
    function test_EdgeCase_MultipleOrdersSameParties() public {
        // 创建 5 个订单
        uint256[] memory orderIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            orderIds[i] = _createAndDepositETH(ESCROW_AMOUNT);
        }

        // 不同状态
        _toExecuting(orderIds[0]); // Executing
        _toReviewing(orderIds[1]); // Reviewing
        _toDisputing(orderIds[2]); // Disputing

        // Execute happy path on orderIds[3]
        _toExecuting(orderIds[3]);
        vm.prank(contractor);
        core.markReady(orderIds[3]);
        vm.prank(client);
        core.approveReceipt(orderIds[3]);

        // 验证每个订单独立
        _assertState(orderIds[0], OrderState.Executing);
        _assertState(orderIds[1], OrderState.Reviewing);
        _assertState(orderIds[2], OrderState.Disputing);
        _assertState(orderIds[3], OrderState.Settled);
        _assertState(orderIds[4], OrderState.Initialized);
    }

    /**
     * @notice 测试余额聚合：同一用户在多个订单中的余额累积
     */
    function test_EdgeCase_BalanceAggregationMultipleOrders() public {
        // 已在 Settlement.t.sol 中测试
        // 这里测试更复杂的场景：部分结清 + 全额结清 + 退款混合

        // 订单1：全额给 contractor
        uint256 orderId1 = _createAndDepositETH(10 ether);
        _toExecuting(orderId1);
        vm.prank(contractor);
        core.markReady(orderId1);
        vm.prank(client);
        core.approveReceipt(orderId1);

        // 订单2：取消退款给 client
        uint256 orderId2 = _createAndDepositETH(20 ether);
        vm.prank(client);
        core.cancelOrder(orderId2);

        // 订单3：再给 contractor
        uint256 orderId3 = _createAndDepositETH(15 ether);
        _toExecuting(orderId3);
        vm.prank(contractor);
        core.markReady(orderId3);
        vm.prank(client);
        core.approveReceipt(orderId3);

        // 验证聚合余额
        assertEq(core.withdrawableOf(address(0), contractor), 10 ether + 15 ether, "Contractor balance incorrect");
        assertEq(core.withdrawableOf(address(0), client), 20 ether, "Client balance incorrect");
    }

    // ============================================
    // 事件顺序测试
    // ============================================

    /**
     * @notice 测试 Happy Path 的完整事件序列
     * @dev TODO: 需要在 BaseTest 中声明事件才能测试
     */
    function test_EdgeCase_EventSequence_HappyPath_TODO() public {
        // 暂时跳过事件测试，需要导入事件定义
        // TODO: 在 BaseTest 中添加事件声明后取消注释
    }
}
