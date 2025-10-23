// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {NESPCore} from "../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState} from "../CONTRACTS/core/Types.sol";
import {MockERC20} from "../CONTRACTS/mocks/MockERC20.sol";
import {AlwaysYesValidator} from "../CONTRACTS/mocks/AlwaysYesValidator.sol";

/**
 * @title BaseTest
 * @notice 测试基础类，提供通用设置和辅助函数
 */
contract BaseTest is Test {
    // ============================================
    // 合约实例
    // ============================================

    NESPCore public core;
    MockERC20 public token;

    // ============================================
    // 测试账户
    // ============================================

    address public governance;
    address public client;
    address public contractor;
    address public provider;
    address public thirdParty;

    // ============================================
    // 测试常量
    // ============================================

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant ESCROW_AMOUNT = 10 ether;
    uint256 public constant FEE_BPS = 250; // 2.5%

    uint48 public constant DUE_SEC = 1 days;
    uint48 public constant REV_SEC = 1 days;
    uint48 public constant DIS_SEC = 7 days;

    // ============================================
    // Setup
    // ============================================

    function setUp() public virtual {
        // 创建测试账户
        governance = makeAddr("governance");
        client = makeAddr("client");
        contractor = makeAddr("contractor");
        provider = makeAddr("provider");
        thirdParty = makeAddr("thirdParty");

        // 给账户充值 ETH
        vm.deal(governance, INITIAL_BALANCE);
        vm.deal(client, INITIAL_BALANCE);
        vm.deal(contractor, INITIAL_BALANCE);
        vm.deal(provider, INITIAL_BALANCE);
        vm.deal(thirdParty, INITIAL_BALANCE);

        // 部署合约
        core = new NESPCore(governance);
        token = new MockERC20("Test Token", "TEST");

        // 给账户分配 ERC20 代币
        token.mint(client, INITIAL_BALANCE);
        token.mint(contractor, INITIAL_BALANCE);
        token.mint(thirdParty, INITIAL_BALANCE);

        // 标记合约地址（便于追踪）
        vm.label(address(core), "NESPCore");
        vm.label(address(token), "MockERC20");
        vm.label(governance, "Governance");
        vm.label(client, "Client");
        vm.label(contractor, "Contractor");
        vm.label(provider, "Provider");
        vm.label(thirdParty, "ThirdParty");

        // 设置全局验证器（始终通过）以便带手续费用例
        vm.prank(governance);
        core.setFeeValidator(address(new AlwaysYesValidator()));
    }

    // ============================================
    // 辅助函数：创建订单
    // ============================================

    /**
     * @notice 创建 ETH 订单（无手续费）
     */
    function _createETHOrder() internal returns (uint256 orderId) {
        vm.prank(client);
        orderId = core.createOrder(
            address(0), // ETH
            contractor,
            0, // 使用默认 dueSec
            0, // 使用默认 revSec
            0, // 使用默认 disSec
            address(0), // feeRecipient
            0 // feeBps
        );
    }

    /**
     * @notice 创建 ETH 订单（带手续费）
     */
    function _createETHOrderWithFee() internal returns (uint256 orderId) {
        vm.prank(client);
        orderId = core.createOrder(
            address(0), // ETH
            contractor,
            DUE_SEC,
            REV_SEC,
            DIS_SEC,
            provider,
            uint16(FEE_BPS)
        );
    }

    /**
     * @notice 创建 ERC20 订单（无手续费）
     */
    function _createERC20Order() internal returns (uint256 orderId) {
        vm.prank(client);
        orderId = core.createOrder(
            address(token),
            contractor,
            0, // 使用默认值
            0,
            0,
            address(0),
            0
        );
    }

    /**
     * @notice 创建 ERC20 订单（带手续费）
     */
    function _createERC20OrderWithFee() internal returns (uint256 orderId) {
        vm.prank(client);
        orderId = core.createOrder(
            address(token),
            contractor,
            DUE_SEC,
            REV_SEC,
            DIS_SEC,
            provider,
            uint16(FEE_BPS)
        );
    }

    /**
     * @notice 创建并充值 ETH 订单
     */
    function _createAndDepositETH(uint256 amount) internal returns (uint256 orderId) {
        vm.prank(client);
        orderId = core.createAndDeposit{value: amount}(
            address(0),
            contractor,
            DUE_SEC,
            REV_SEC,
            DIS_SEC,
            address(0),
            0,
            amount
        );
    }

    /**
     * @notice 创建并充值 ERC20 订单
     */
    function _createAndDepositERC20(uint256 amount) internal returns (uint256 orderId) {
        // 先授权
        vm.prank(client);
        token.approve(address(core), amount);

        // 创建并充值
        vm.prank(client);
        orderId = core.createAndDeposit(
            address(token),
            contractor,
            DUE_SEC,
            REV_SEC,
            DIS_SEC,
            address(0),
            0,
            amount
        );
    }

    // ============================================
    // 辅助函数：充值
    // ============================================

    /**
     * @notice 充值 ETH 到订单
     */
    function _depositETH(uint256 orderId, uint256 amount, address depositor) internal {
        vm.prank(depositor);
        core.depositEscrow{value: amount}(orderId, amount);
    }

    /**
     * @notice 充值 ERC20 到订单
     */
    function _depositERC20(uint256 orderId, uint256 amount, address depositor) internal {
        vm.prank(depositor);
        token.approve(address(core), amount);

        vm.prank(depositor);
        core.depositEscrow(orderId, amount);
    }

    // ============================================
    // 辅助函数：状态转换
    // ============================================

    /**
     * @notice 执行完整的正常流程（Initialized → Settled）
     * @return orderId 订单 ID
     */
    function _executeHappyPath() internal returns (uint256 orderId) {
        // 1. 创建并充值
        orderId = _createAndDepositETH(ESCROW_AMOUNT);

        // 2. 接单（E1: Initialized → Executing）
        vm.prank(contractor);
        core.acceptOrder(orderId);

        // 3. 标记完成（E3: Executing → Reviewing）
        vm.prank(contractor);
        core.markReady(orderId);

        // 4. 验收（E8: Reviewing → Settled）
        vm.prank(client);
        core.approveReceipt(orderId);
    }

    /**
     * @notice 执行到 Executing 状态
     */
    function _toExecuting(uint256 orderId) internal {
        vm.prank(contractor);
        core.acceptOrder(orderId);
    }

    /**
     * @notice 执行到 Reviewing 状态
     */
    function _toReviewing(uint256 orderId) internal {
        _toExecuting(orderId);
        vm.prank(contractor);
        core.markReady(orderId);
    }

    /**
     * @notice 执行到 Disputing 状态
     */
    function _toDisputing(uint256 orderId) internal {
        _toReviewing(orderId);
        vm.prank(client);
        core.raiseDispute(orderId);
    }

    // ============================================
    // 辅助函数：断言
    // ============================================

    /**
     * @notice 断言订单状态
     */
    function _assertState(uint256 orderId, OrderState expectedState) internal {
        Order memory order = core.getOrder(orderId);
        assertEq(uint8(order.state), uint8(expectedState), "Unexpected order state");
    }

    /**
     * @notice 断言订单托管额
     */
    function _assertEscrow(uint256 orderId, uint256 expectedEscrow) internal {
        Order memory order = core.getOrder(orderId);
        assertEq(order.escrow, expectedEscrow, "Unexpected escrow amount");
    }

    /**
     * @notice 断言可提余额
     */
    function _assertWithdrawable(address tokenAddr, address account, uint256 expectedAmount) internal {
        uint256 actual = core.withdrawableOf(tokenAddr, account);
        assertEq(actual, expectedAmount, "Unexpected withdrawable amount");
    }

    /**
     * @notice 断言 ETH 余额
     */
    function _assertETHBalance(address account, uint256 expectedBalance) internal {
        assertEq(account.balance, expectedBalance, "Unexpected ETH balance");
    }

    /**
     * @notice 断言 ERC20 余额
     */
    function _assertTokenBalance(address account, uint256 expectedBalance) internal {
        assertEq(token.balanceOf(account), expectedBalance, "Unexpected token balance");
    }
}
