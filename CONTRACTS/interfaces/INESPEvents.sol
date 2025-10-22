// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {OrderState, BalanceKind, SettleActor} from "../core/Types.sol";

/**
 * @title INESPEvents
 * @notice NESP 协议事件定义（WP §6.2）
 * @dev 所有事件不携带显式 ts 字段，以 block.timestamp 作为时间锚点
 */
interface INESPEvents {
    /**
     * @notice 订单创建事件（WP §6.2）
     * @param orderId 订单 ID
     * @param client 买方地址
     * @param contractor 卖方地址
     * @param tokenAddr 资产地址（address(0) 表示 ETH）
     * @param dueSec D_due: 履约窗口（秒）
     * @param revSec D_rev: 评审窗口（秒）
     * @param disSec D_dis: 争议窗口（秒）
     * @param feeHook 手续费 Hook 地址（address(0) 表示无手续费）
     * @param feeCtxHash 手续费上下文哈希
     */
    event OrderCreated(
        uint256 indexed orderId,
        address indexed client,
        address indexed contractor,
        address tokenAddr,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec,
        address feeHook,
        bytes32 feeCtxHash
    );

    /**
     * @notice 托管额充值事件
     * @param orderId 订单 ID
     * @param from 充值来源地址
     * @param amount 充值金额
     * @param newEscrow 充值后的托管总额
     * @param via 调用通道（address(0) 为直连，否则为转发合约地址）
     */
    event EscrowDeposited(
        uint256 indexed orderId, address indexed from, uint256 amount, uint256 newEscrow, address via
    );

    /**
     * @notice 订单接单事件（E1: Initialized → Executing）
     * @param orderId 订单 ID
     * @param escrow 当前托管额
     */
    event Accepted(uint256 indexed orderId, uint256 escrow);

    /**
     * @notice 交付完成事件（E3: Executing → Reviewing）
     * @param orderId 订单 ID
     * @param readyAt 交付完成时间
     */
    event ReadyMarked(uint256 indexed orderId, uint48 readyAt);

    /**
     * @notice 争议发起事件（E5/E10: → Disputing）
     * @param orderId 订单 ID
     * @param by 发起方地址
     */
    event DisputeRaised(uint256 indexed orderId, address indexed by);

    /**
     * @notice 履约窗口延长事件
     * @param orderId 订单 ID
     * @param oldDueSec 旧窗口（秒）
     * @param newDueSec 新窗口（秒）
     * @param actor 操作者（应为 client）
     */
    event DueExtended(uint256 indexed orderId, uint48 oldDueSec, uint48 newDueSec, address actor);

    /**
     * @notice 评审窗口延长事件
     * @param orderId 订单 ID
     * @param oldRevSec 旧窗口（秒）
     * @param newRevSec 新窗口（秒）
     * @param actor 操作者（应为 contractor）
     */
    event ReviewExtended(uint256 indexed orderId, uint48 oldRevSec, uint48 newRevSec, address actor);

    /**
     * @notice 订单结清事件（E4/E8/E9: → Settled）
     * @param orderId 订单 ID
     * @param amountToSeller 卖方收款总额（含手续费，即 A）
     * @param escrow 结清时的托管额（E）
     * @param actor 触发方（Client 或 Timeout）
     */
    event Settled(uint256 indexed orderId, uint256 amountToSeller, uint256 escrow, SettleActor actor);

    /**
     * @notice 签名协商结清事件（E12: Disputing → Settled）
     * @param orderId 订单 ID
     * @param proposer 提议方地址
     * @param acceptor 接受方地址
     * @param amountToSeller 协商金额（A）
     * @param nonce 提议方的 nonce
     */
    event AmountSettled(
        uint256 indexed orderId, address proposer, address acceptor, uint256 amountToSeller, uint256 nonce
    );

    /**
     * @notice 订单没收事件（E13: Disputing → Forfeited）
     * @param orderId 订单 ID
     * @param tokenAddr 资产地址
     * @param amount 没收金额
     */
    event Forfeited(uint256 indexed orderId, address tokenAddr, uint256 amount);

    /**
     * @notice 订单取消事件（E2/E6/E7/E11: → Cancelled）
     * @param orderId 订单 ID
     * @param cancelledBy 取消方地址（client 或 contractor）
     */
    event Cancelled(uint256 indexed orderId, address cancelledBy);

    /**
     * @notice 余额记账事件（结清/退款/手续费）
     * @param orderId 订单 ID
     * @param to 接收地址
     * @param tokenAddr 资产地址
     * @param amount 记账金额
     * @param kind 余额类型（Payout/Refund/Fee）
     */
    event BalanceCredited(uint256 indexed orderId, address indexed to, address tokenAddr, uint256 amount, BalanceKind kind);

    /**
     * @notice 用户提现事件
     * @param to 提现地址
     * @param tokenAddr 资产地址
     * @param amount 提现金额
     */
    event BalanceWithdrawn(address indexed to, address tokenAddr, uint256 amount);

    /**
     * @notice 治理提款事件（ForfeitPool 提现）
     * @param tokenAddr 资产地址
     * @param to 接收地址
     * @param amount 提现金额
     * @param actor 治理调用者
     */
    event ProtocolFeeWithdrawn(address indexed tokenAddr, address to, uint256 amount, address actor);
}
