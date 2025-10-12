# [DISCUSSION] NESP — 无仲裁托管结算协议（限时争议 · 对称没收 · 零协议费）

**Tags**: EIPs, ERC, escrow, dispute, symmetric-forfeit, zero-fee, 2771, 4337

> 本草稿对齐 `SPEC/zh/whitepaper.md`（唯一语义源）。文中函数、事件、状态与不变量均引用白皮书编号（E.x / INV.x / MET.x）。

---

## TL;DR

NESP（No-Arbitration Escrow Settlement Protocol）面向 A2A 市场与钱包厂商，需要在无仲裁、一次性交付的场景下保持可信中立，不把裁量权交给多签或治理委员会。

对这些集成方而言的关键机制：

1. **限时状态机**：履约窗口 `D_due`、评审窗口 `D_rev`、争议窗口 `D_dis`（§2.2，§3.1），与 A2A 会话中的“交付截止”“客户确认”“冷静期”消息一一映射。  
2. **对称没收（E13 / INV.8）**：争议窗口超时未协商，双方押金一并罚没，以定时惩罚而非仲裁来抑制僵局。  
3. **零协议费（§1.3 / INV.14 / MET.5）**：所有结算路径都满足 `escrow_before = payout + refund`，否则 `ErrFeeForbidden`，平台如需收费必须在更高层自加条款。  
4. **Pull 结算（INV.10）**：状态转移仅记账，资金由 `withdraw` 主动拉取且附带 `nonReentrant`，外部攻击面更小。

状态流程回顾：  
`Initialized` →（E1）`Executing` →（E3）`Reviewing` →（E4/E9）`Settled` 或（E5/E10）`Disputing` →（E12）`Settled` /（E13）`Forfeited`；若守卫不满足，仍可走取消路径（E2/E6/E7/E11）。

---

## Motivation

- 中心化托管依赖平台仲裁与抽成，缺乏可信中立；去中心化仲裁又引入治理复杂度。  
- Rollup、AA（ERC-2771/4337）与代理经济兴起，需要**最小可信托管乐高**：可审计、可复现、易组合。  
- 过往 Magicians 上的 A2A 讨论（如委托执行控制器、账户绑定代理）多依赖多签或治理兜底，本帖尝试提供“定时惩罚、零裁量”的替代路线。  
- NESP 将“纠纷裁决”转化为“时间边界 + 押金结构”，通过 INV.13（唯一机制）让合作成为支配策略。

---

## Scope & Non-Goals

**在范围内**
- 单笔托管（ETH/ERC-20），Client→Contractor 的一次性交付；
- 必备函数/事件/错误（§6.1/§6.2），含 2771/4337 来源解析（§6.3）；
- 可观测指标与 SLO（§7.1/§7.2），用于公共审计。

**不在范围**
- 多阶段里程碑、多币种篮子、仲裁/治理/评分系统；
- 平台费、收益再分配、外层风控策略（留给上层实现）。

---

## State Machine（§3）

| 转换 | 触发函数 | 关键守卫 | 结果 | A2A 消息映射 |
|------|----------|----------|------|----------------|
| E1 | `acceptOrder` | `state=Initialized` 且主体=contractor | 进入 `Executing`，设置 `startTime` | 承包方：“我接单了。” |
| E3 | `markReady` | `now < startTime + D_due` | 锚定 `readyAt`，进入 `Reviewing` | 承包方：“交付物就绪/已发货。” |
| E4/E9 | `approveReceipt` / `timeoutSettle` | `state ∈ {Executing,Reviewing}` / `now ≥ readyAt + D_rev` | 全额结清（INV.1） | 客户：“确认收货。” / 客户超时未回。 |
| E5/E10 | `raiseDispute` | 主体 ∈ {client, contractor} | 冻结 escrow，记录 `disputeStart` | 任一方：“有问题，请暂停。” |
| E12 | `settleWithSigs` | `A ≤ escrow`，双签有效 | 金额型结清（INV.2/INV.3） | 双方签署协商金额。 |
| E13 | `timeoutForfeit` | `now ≥ disputeStart + D_dis` | 对称没收（INV.8） | 系统：“争议过期，双方押金被没收。” |
| E2/E6/E7/E11 | `cancelOrder` | 详见守卫 G.E6/G.E7/G.E11 | 取消订单 | 守卫允许下的任意一方撤单。 |

> 任何状态变更前先检查冻结/终态守卫：`state ∈ {Disputing}` → `ErrFrozen`；终态 → `ErrInvalidState`。

---

## Minimal Interface（§6.1）

规范性的最小函数集合（所有入口均遵循 CEI，Pull 语义）：

```
createOrder(tokenAddr, contractor, dueSec, revSec, disSec) -> orderId
createAndDeposit(tokenAddr, contractor, dueSec, revSec, disSec, amount) payable
depositEscrow(orderId, amount) payable
acceptOrder(orderId)
markReady(orderId)
approveReceipt(orderId)
timeoutSettle(orderId)
raiseDispute(orderId)
settleWithSigs(orderId, payload, sigClient, sigContractor)
timeoutForfeit(orderId)
cancelOrder(orderId)
withdraw(tokenAddr)
getOrder(orderId) view -> {client, contractor, tokenAddr, state, escrow, dueSec, revSec, disSec, startTime, readyAt, disputeStart}
withdrawableOf(tokenAddr, account) view -> uint256
extendDue(orderId, newDueSec)
extendReview(orderId, newRevSec)
```

错误集合：`ErrInvalidState / ErrExpired / ErrBadSig / ErrOverEscrow / ErrFrozen / ErrFeeForbidden / ErrAssetUnsupported / ErrReplay / ErrUnauthorized`（§5.2）。

2771/4337：解析后的业务主体 `subject` 用于所有守卫，`via` 字段写入事件（§6.3）。

---

## Events & Observability（§6.2，§7）

最小事件：
```
OrderCreated(orderId, client, contractor, tokenAddr, dueSec, revSec, disSec, ts)
EscrowDeposited(orderId, from, amount, newEscrow, ts, via)
Accepted(orderId, escrow, ts)
ReadyMarked(orderId, readyAt, ts)
DueExtended(orderId, oldDueSec, newDueSec, ts, actor)
ReviewExtended(orderId, oldRevSec, newRevSec, ts, actor)
DisputeRaised(orderId, by, ts)
Settled(orderId, amountToSeller, escrow, ts, actor)   // actor∈{Client,Timeout}
AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce, ts)
Forfeited(orderId, ts)
Cancelled(orderId, ts, cancelledBy)                  // cancelledBy∈{Client,Contractor}
BalanceCredited(orderId, to, tokenAddr, amount, kind, ts) // kind∈{Payout,Refund}
BalanceWithdrawn(to, tokenAddr, amount, ts)
```

公共指标示例（§7.1）：
- `MET.1` 结清延迟 P95；`MET.4` 协商接受率；`MET.5` 零费违规次数（应恒为 0）；  
- `GOV.1` 终态分布；`GOV.3` 争议时长；  
- 计数去重规则详见 §7.1。

SLO 判据（§7.2）：`SLO_T(W) := (MET.5=0) ∧ (forfeit_rate ≤ θ) ∧ (acceptance_rate ≥ β) ∧ (p95_settle ≤ τ)`。

---

## Security Considerations（§5）

- **签名与重放**：`settleWithSigs` 采用 EIP-712/EIP-1271 域 `{chainId, contract, orderId, tokenAddr, amountToSeller, proposer, acceptor, nonce, deadline}`（§5.1）。  
- **CEI & Reentrancy**：除 `withdraw`、`transferFrom` 外禁止外部调用；`withdraw` 为 `nonReentrant`（§5.3）。  
- **时间守卫**：`D_due/D_rev` 仅允许单调延长；`D_dis` 固定不变（INV.12）。  
- **零协议费**：任何违背 INV.14 的路径必须 `revert ErrFeeForbidden`；建议以 `MET.5` 持续监控。  
- **非标资产**：若余额差不等于转账额，立即 `ErrAssetUnsupported`（INV.7）。
- **对称没收与女巫成本**：僵持的代价与合作相同，除非攻击者自担双方押金；押金+计时器让理性女巫更倾向合作，仍欢迎社区补充信誉、质押等低成本身份场景的缓解策略。

---

## Compatibility & Extensibility

- 资产：ETH / ERC-20（原生资产需匹配 `msg.value`；ERC-20 使用 SafeERC20）。  
- 调用来源：直连、受信转发（2771）、EntryPoint（4337）；禁止多跳链路。  
- 上层可扩展押金/评分/复合里程碑，但需保证核心状态机与不变量不被破坏。

---

## Open Questions（征求社区意见）

1. **窗口参数**：`D_due/D_rev/D_dis` 的默认值与链级最小/最大约束；是否需要跨链差异化建议？  
2. **争议落点**：是否允许部署方调整超时落点（如某些场景倾向退款而非罚没）？  
3. **签名域扩展**：是否需要 `termsHash` 或 `deliveryHash` 作为可选字段？  
4. **指标采集**：是否需要标准化 `Outcome` 汇总事件以便索引器消费？  
5. **多资产/多阶段**：社区是否需要在标准层保留扩展钩子，还是保持核心最小化？
6. **多主体 A2A**：若同一订单存在多于两位主体（co-op/DAO 小组），无仲裁条件下的最佳实践为何？  
7. **信誉 / 女巫护栏**：标准是否应推荐配套的 SBT、质押或信用评分，以降低低成本身份对对称没收的滥用？

---

## References

- `SPEC/zh/whitepaper.md`（版本对齐于本草稿编写时最新提交）  
- `EIP-DRAFT/eip-nesp.md`（正在补完的 ERC 草案骨架）  
- `SPEC/commons`（待补充的状态机图、流程示例）  
- `TESTS/`（计划中的 Foundry/Hardhat 骨架）

---

## Next Steps

1. 收集 Magicians 反馈，并记录其与既有 A2A 讨论（委托执行、账户代理等）的差异；采纳部分同步写入 `EIP-DRAFT/eip-nesp.md` 的 Rationale / Security / Open Issues。  
2. 在 EthResearch 发布配套博弈分析（§9、§16.3），并做双向交叉链接，方便读者比较模型。  
3. 与钱包 / 市场 / AA 提供方合作，验证 2771/4337 流程、签名样本与事件口径，同时公布测试脚本位置。  
4. 一旦社区形成共识，将推荐的信誉 / 女巫护栏方案收录到 `SPEC/commons`。

---

**English Abstract**  
NESP defines a zero-fee, no-arbitration escrow settlement standard with bounded performance/review/dispute windows and symmetric forfeiture. The minimal interface (`createOrder`, `raiseDispute`, `settleWithSigs`, `timeoutForfeit`, etc.), event schema, invariants (`A ≤ E`, zero-fee identity), and AA-friendly provenance rules (2771/4337) are aligned with the Chinese SSOT. We welcome feedback on default timeout outcomes, timer bounds, optional signatures, observability requirements, multi-agent variants, and recommended reputation / Sybil guardrails before advancing the ERC draft.
