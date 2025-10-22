// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

/**
 * @title Types
 * @notice 定义 NESP 协议的核心数据结构
 * @dev 遵循白皮书 SPEC/zh/whitepaper.md §2, §3
 */

/// @notice 订单状态枚举（WP §3.0）
enum OrderState {
    Initialized,  // 已创建，等待卖方接单
    Executing,    // 执行中，卖方已接单
    Reviewing,    // 评审中，卖方已标记完成
    Disputing,    // 争议中，双方协商
    Settled,      // 已结清（终态）
    Forfeited,    // 已没收（终态）
    Cancelled     // 已取消（终态）
}

/// @notice 余额类型（用于 BalanceCredited 事件）
enum BalanceKind {
    Payout,   // 卖方收款
    Refund,   // 买方退款
    Fee       // 手续费
}

/// @notice 结清触发方（用于 Settled 事件）
enum SettleActor {
    Client,   // 买方主动验收
    Timeout   // 超时自动结清
}

/// @notice 订单结构体（WP §2.1, §2.2, §2.3）
/// @dev 字段按 Gas 优化打包：address(20) + uint48(6) 可打包到同一个 slot
struct Order {
    // Slot 1: 参与者（40 字节）
    address client;      // 买方地址
    address contractor;  // 卖方地址

    // Slot 2: 资产与状态（32 字节）
    address tokenAddr;   // 资产地址（ETH 使用 address(0)）
    OrderState state;    // 当前状态（1 字节枚举）
    uint48 dueSec;       // D_due: 履约窗口（秒）
    uint48 revSec;       // D_rev: 评审窗口（秒）

    // Slot 3: 托管额（32 字节）
    uint256 escrow;      // E: 托管额（单调不减）

    // Slot 4: 时间锚点 + 争议窗口（32 字节）
    uint48 startTime;    // 接单时间（acceptOrder）
    uint48 readyAt;      // 交付时间（markReady）
    uint48 disputeStart; // 争议开始时间（raiseDispute）
    uint48 disSec;       // D_dis: 争议窗口（固定，不可延长）

    // Slot 5: 手续费策略（32 字节）
    address feeHook;     // 手续费 Hook 合约（address(0) 表示无手续费）
    bytes32 feeCtxHash;  // 手续费上下文哈希（链下存储原始 feeCtx）
}

/// @notice 手续费策略上下文（链下存储，仅哈希上链）
/// @dev 这是信息性定义，不在合约中使用
struct FeeContext {
    address provider;    // 服务商地址
    uint256 feeBps;      // 费率（基点，1/10000）
    bytes32 metadata;    // 额外元数据（预留）
}
