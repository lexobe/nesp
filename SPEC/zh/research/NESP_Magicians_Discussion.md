# [DISCUSSION] NESP — 无仲裁托管结算协议（限时争议 · 对称没收 · 零协议费）

**Tags**: EIPs, ERC, escrow, dispute, symmetric-forfeit, zero-fee, trustless, rollup

> 本帖介绍并征求反馈的 NESP（No-Arbitration Escrow Settlement Protocol）协议，完整规范见 `SPEC/zh/whitepaper.md`（唯一语义源）与 `EIP-DRAFT/eip-nesp.md`。所有函数、事件、状态与不变量均引用白皮书锚点（E.x / INV.x / MET.x）。

---

## TL;DR

1. **NESP 是什么**：一个无信任（trustless）、面向 A2A 交易的托管结算协议，承诺无仲裁、零协议费、对称罚没威慑、Pull 式提现。  
2. **关键机制**：  
   - 限时状态机（履约 `D_due`、评审 `D_rev`、争议 `D_dis`），保障流程可预期（§3）。  
   - 对称没收（E13 / INV.8）：争议超时双方押金同时没收，形成“拖延无利可图”的博弈结构。  
   - `A ≤ E`、零协议费（INV.14）：任何扣费都会 `ErrFeeForbidden`，记录在 `MET.5`。  
   - Pull 结算（INV.10）：状态机只记账，真实资金在 `withdraw` 时结算，配合 `nonReentrant`。  
3. **兼容性**：默认直连调用，部署方可选启用 ERC-2771/4337 等 AA 通道，但不得改变金额/时间语义（§6.3）。  
4. **求反馈**：窗口参数、签名域扩展、多主体协作、声誉/女巫护栏、观测事件等细节欢迎探讨。

---

## 为什么我们需要 NESP？

- **现状痛点**：中心化托管平台收取费用、依赖仲裁；去中心化仲裁框架则需要额外治理与仲裁者。  
- **Rollup-centric**：顺着以太坊“L1 极简、L2 创新”的路线，NESP 被设计成无需任何共识层改动的合约级积木，可部署在任意 Rollup / L2 上。  
- **NESP 的定位**：提供一个最小、可审计的结算骨干，把“裁决”转化为“时间 + 押金”组合，既避开仲裁，又能形成合作激励。  
- **信任最小化**：所有路径要么全额结清、要么签名协商、要么对称没收。没有裁量、没有协议内收费，且所有状态与金额都可由第三方复验。

---

## 协议核心（白皮书 §3 / §4）

| 转换 | 函数 | 条件 | 说明 |
|------|------|------|------|
| E1 | `acceptOrder` | `state=Initialized` 且主体=contractor | 进入执行态，记录 `startTime` |
| E3 | `markReady` | `now < startTime + D_due` | 锚定 `readyAt`，进入评审态 |
| E4/E9 | `approveReceipt` / `timeoutSettle` | 客户确认或评审超时 | `amountToSeller = escrow` |
| E5/E10 → E12/E13 | `raiseDispute` → `settleWithSigs` / `timeoutForfeit` | 任一方争议，之后协商或没收 | 协商签名满足 `A ≤ E`；超时双方没收 |
| E2/E6/E7/E11 | `cancelOrder` | 守卫限制 | 根据守卫条件取消订单 |
| 提现 | `withdraw` | Pull 结算、`nonReentrant` | 满足 INV.5 幂等 |

**不变量**：  
- `INV.1–INV.4`：单次记账、幂等提现。  
- `INV.5`：提现幂等。  
- `INV.8`：对称没收。  
- `INV.10`：Pull 结算。  
- `INV.11/INV.12`：锚点一次性、计时器单调。  
- `INV.14`：零协议费。
- 这些约束确保资金路径完全可验证，观测者无需信任合约作者或仲裁方即可推导结果。

---

## 事件与观测

最小事件集合（§6.2）：`OrderCreated`、`EscrowDeposited`、`Accepted`、`ReadyMarked`、`DisputeRaised`、`Settled`、`AmountSettled`、`Forfeited`、`Cancelled`、`BalanceCredited`、`BalanceWithdrawn` 等。  
核心指标（§7.1）：  
- `MET.1` 结清延迟 P95  
- `MET.4` 协商接受率  
- `MET.5` 零费违规次数（应保持 0）  
- `GOV.1`/`GOV.3` 终态 / 争议分布  

`EscrowDeposited.via` 默认 `address(0)`；若部署启用受信通道，可记录 `forwarder/EntryPoint`。

---

## 安全与实现提示（§5 / §6）

- **签名安全**：`settleWithSigs` 使用域 `{chainId, contract, orderId, tokenAddr, amountToSeller, proposer, acceptor, nonce, deadline}`，防跨单/跨链重放。  
- **CEI & 重入**：除 `withdraw` 外不得外部调用；`withdraw` 必须 `nonReentrant` 并先清零余额。  
- **计时器优先权**：入口在超时条件成立时必须优先执行 `timeout*`，防延迟勒索。  
- **非标资产**：对 fee-on-transfer、rebase 代币无法对账时应 `revert ErrAssetUnsupported`。  
- **AA 支持（可选）**：若启用 2771/4337，需要配置受信地址、拒绝多跳，并确保行为等价于直连调用。

## Rollup / AA 部署提示

- 协议核心无需任何 L1 修改，可直接在任意 Rollup / L2 部署。  
- 若 Rollup 运行方计划提供受信转发或 EntryPoint，请公布监控/熔断策略（例如如何观测 `MET.5`、何时停写），以便大家对齐实践。  
- 欢迎分享在 L2 环境中调用 NESP 的样例（Bundler、Paymaster、意图执行器等），帮助我们验证“协议极简 + 实现多样”的目标。

---

## 开放问题（欢迎讨论）

1. `D_due/D_rev/D_dis` 的默认值和链级约束有什么建议？  
2. 是否允许某些部署在超时后偏向退款而非对称没收？怎样保持可信中立？  
3. `settleWithSigs` 是否需要 `termsHash` / `deliveryHash` / `intentId` 等扩展字段？  
4. 是否需要额外的 `Outcome` 聚合事件，便于索引器汇总？  
5. 多阶段或多资产场景是否应留扩展钩子，还是维持最小接口？  
6. 多主体（多个承包方/委托方）如何在无仲裁前提下拆分押金与收益？  
7. 对称没收是否需要配合链上声誉/SBT/质押等机制以限制女巫攻击？

---

## 期待社区反馈的方向

- 协议安全性或经济激励是否有遗漏？  
- 是否有实际案例/需求能验证或挑战 NESP 的设计？  
- 有没有建议的参数范围、测试用例、参考实现？  
- 账户抽象或意图执行团队是否愿意提供调用样例？  

我们计划：
1. 将本帖收集的反馈整理进 `EIP-DRAFT/eip-nesp.md` 的 Rationale / Security / Open Issues。  
2. 补齐一个最小复现实验（Foundry/脚本），验证 `INV.14`、`INV.8` 等不变量，方便社区复查。  
3. 在 ethresear.ch 发布博弈与参数分析（白皮书 §9/§16.3 的扩展），并与本帖互链。  
4. 与愿意试用的团队合作，补充示例代码与测试脚本（`TESTS/` 目录），尤其欢迎 Rollup/AA 团队提交调用范例。  
5. 若形成共识，将声誉/女巫护栏等补充设计记录在 `SPEC/commons`。

谢谢阅读，欢迎在本帖直接分享观点、提出问题或附上相关实验结果，让 NESP 成为社区共同雕琢的无仲裁结算协议。
