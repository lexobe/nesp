// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

/**
 * @title IFeeHook
 * @notice 手续费策略接口（WP §12.1）
 * @dev 实现此接口以提供自定义手续费计算逻辑
 *
 * 设计原则：
 * - 必须是 view 函数（STATICCALL 调用，不可修改状态）
 * - 返回的 fee 必须 ≤ amountToSeller（由调用方验证）
 * - Gas 限制：50,000（防止 DoS 攻击）
 */
interface IFeeHook {
    /**
     * @notice 计算结清时的手续费
     * @param orderId 订单 ID
     * @param client 买方地址
     * @param contractor 卖方地址
     * @param amountToSeller 结清金额（卖方收款总额，含手续费）
     * @param feeCtx 手续费上下文（订单创建时固化）
     * @return recipient 手续费接收地址
     * @return fee 手续费金额（必须 ≤ amountToSeller）
     *
     * @dev 示例实现（固定费率）：
     *      fee = floor(amountToSeller * feeBps / 10_000)
     *      recipient = providerAddress
     */
    function onSettleFee(
        uint256 orderId,
        address client,
        address contractor,
        uint256 amountToSeller,
        bytes memory feeCtx
    ) external view returns (address recipient, uint256 fee);
}
