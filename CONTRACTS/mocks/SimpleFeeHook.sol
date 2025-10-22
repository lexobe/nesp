// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {IFeeHook} from "../interfaces/IFeeHook.sol";

/**
 * @title SimpleFeeHook
 * @notice 简单固定费率 FeeHook 实现（用于测试和参考）
 * @dev 实现 WP §12.1 的手续费策略接口
 */
contract SimpleFeeHook is IFeeHook {
    /// @notice 服务商地址
    address public immutable provider;

    /// @notice 固定费率（基点，1/10000）
    /// @dev 例如：250 表示 2.5%
    uint256 public immutable feeBps;

    /**
     * @notice 构造函数
     * @param _provider 服务商地址（手续费接收方）
     * @param _feeBps 费率（基点，≤ 10000）
     */
    constructor(address _provider, uint256 _feeBps) {
        require(_provider != address(0), "Zero provider");
        require(_feeBps <= 10000, "Fee too high"); // 最多 100%
        provider = _provider;
        feeBps = _feeBps;
    }

    /**
     * @notice 计算手续费（固定费率）
     * @dev 实现 IFeeHook.onSettleFee
     * @param orderId 订单 ID（未使用）
     * @param client 买方地址（未使用）
     * @param contractor 卖方地址（未使用）
     * @param amountToSeller 结清金额
     * @param feeCtx 手续费上下文（未使用）
     * @return recipient 手续费接收地址
     * @return fee 手续费金额
     */
    function onSettleFee(
        uint256 orderId,
        address client,
        address contractor,
        uint256 amountToSeller,
        bytes memory feeCtx
    ) external view override returns (address recipient, uint256 fee) {
        // 忽略未使用参数（避免编译警告）
        (orderId, client, contractor, feeCtx);

        // 计算手续费：floor(amountToSeller * feeBps / 10000)
        fee = (amountToSeller * feeBps) / 10000;

        // 返回服务商地址
        recipient = provider;
    }
}
