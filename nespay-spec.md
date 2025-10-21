# NESPAY 扩展规范（基于 NESP 白皮书）

说明
- 本文是对 NESP 核心协议（WP/Spec）的“产品级扩展”约束，覆盖：
  - 证据承诺（Evidence Commitments，简称 EVC）扩展
  - 手续费 Hook（FeeHook）扩展
- 扩展不改变 NESP 核心状态机、不变量与 Pull/CEI 边界，仅在“应用层/扩展层”增加接口与只读计算；结算口径与事件审计保持可复现。

依赖与基线
- 依赖：NESP WP/Spec（FeeHook 字段：`feeHook, feeCtx/feeCtxHash`；结清三笔记账；ForfeitPool；最小 API/事件）。
- 不变量：保持 `A ≤ E`、单次入账、终态清零、Pull 语义与 ForfeitPool 恒等式不变。

## 1) Evidence Commitments（EVC 扩展）

目标（WHY）
- 在不改变结算主流程与金额不变量的前提下，记录关键节点的“离链证据指纹”，用于审计与可观测性。

接口与事件（WHAT）
- 合约可选暴露：`commitEvidence(orderId, evc)`（扩展层；非核心）
  - 数据结构（MUST）：`EvidenceCommitment = { hash: bytes32, uri: string≤256, alg: string≤32(ASCII) }`
  - 事件（MUST）：`EvidenceCommitted(orderId, status, address actor, EvidenceCommitment evc)`
- 约束（MUST）：
  - 只允许订单参与者（client 或 contractor）提交；`actor = 解析后的 subject（直连/2771/4337）`
  - 单次仅提交 1 条 `evc`；`uri` 长度 ≤ 256；`alg` 仅作提示，不作语义校验
  - 调用不改变订单状态/金额/可提余额；仅发事件

实现与运行（HOW）
- 推荐把 EVC 独立为扩展合约/模块；核心合约不强制依赖
- 建议使用内容寻址 URI（如 `ipfs://CIDv1`），或同时提供强哈希
- 观测（信息性）：可在运维层统计 `EvidenceCommitted` 的提交率与延迟；不计入核心计数/去重

安全（MUST）
- 拒绝非参与者/多跳/未授权调用；不允许把 EVC 作为结算前置或守卫条件

## 2) FeeHook（手续费扩展）

目标（WHY）
- 在结清（Settled）时，对“卖方本次应收 A”的毛额进行只读计算的手续费扣减；内核仍按三笔入账（Payout=A−fee、Refund=E−A、Fee=fee），并维持 Pull 提现与 CEI 顺序。

字段与生命周期（WHAT）
- 创建（MUST）：`feeHook, feeCtx` 随订单创建固化（事件中存 `feeCtxHash`）；允许 `feeHook = address(0)` 表示不计费
- 视图（MUST）：`getOrder(..., feeHook, feeCtxHash)`；事件 `OrderCreated(..., feeHook, feeCtxHash)`

接口与集成（HOW）
- Hook 接口（MUST）：
```solidity
interface IFeeHook {
  /// 仅在结清路径由核心合约以 STATICCALL 调用；不得改状态/转账
  function onSettleFee(
    uint256 orderId,
    address payer,    // 扣费侧（承包方）
    uint256 gross,    // 本次应收 A 的毛额
    bytes calldata ctx
  ) external view returns (uint256 fee, address to);
}
```
- 调用规范（MUST）：
  - 结清时核心合约以 STATICCALL 调用 `onSettleFee`，仅读取 `(fee,to)`
  - 约束：`0 ≤ fee ≤ gross`；`fee=0` 或 `to=address(0)` ⇒ 可不发 `kind=Fee` 事件
  - 记账：核心按三笔入账并清零 `escrow`；提现沿用 `withdraw(token)`（Pull）
- 失败语义（MUST）：Hook 异常导致结清回滚（推荐 “严格模式”）；是否允许“宽容为 0 费”由实现层配置（信息性）

参考实现（信息性）
- 百分比费率 Hook（只读计算，不写状态）：
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface IFeeHook { function onSettleFee(uint256 id,address payer,uint256 gross,bytes calldata ctx) external view returns (uint256,address); }
contract PercentFeeHook is IFeeHook {
  struct FeeParams { uint16 rBps; address beneficiary; }
  function onSettleFee(uint256 /*id*/, address /*payer*/, uint256 gross, bytes calldata ctx)
    external pure returns (uint256 fee, address to)
  { FeeParams memory p = abi.decode(ctx,(FeeParams)); if (gross==0||p.rBps==0||p.beneficiary==address(0)) return (0,address(0)); fee=(gross*uint256(p.rBps))/10000; to=p.beneficiary; }
}
```

安全与审计（MUST）
- Hook 仅 STATICCALL；不得重入/外部转账；核心继续遵循 CEI 与 `nonReentrant`
- 守恒验证：`(A−fee) + (E−A) + fee = E`；`fee ≤ A`；`feeHook=0` ⇒ `fee=0`
- 事件审计：`BalanceCredited(orderId, to, token, amount, kind=Fee)`（金额为 0 可省略）可复现 Fee 规模

## 3) 对核心的不变量与接口的影响

- 不变量（MUST）：仅 INV.14 来源为 Hook；其余（INV.1–13、ForfeitPool、Pull 例外、恒等式）不变
- API/事件（MUST）：核心最小集合保持不变；扩展不新增结算入口，仅在创建固化字段与结清时只读计算

## 4) 代表性测试与边界

- FeeHook：fee=0、fee=max（A 全扣/上限）/签名结清；`feeHook=0`；Hook 失败回滚
- EVC：多次提交同一订单、uri 长度边界、非参与者拒绝；不影响结算与可提余额

## 5) 兼容性与部署建议（信息性）

- Registry：可选维护 Hook 白名单与参数模板（不写入核心）
- ctx 与哈希：在事件中仅存 `feeCtxHash`，原始 `feeCtx` 由链下保存并用于重放审计
- 版本化：扩展按自有版本推进；核心 WP/Spec 仅保字段与守恒口径

