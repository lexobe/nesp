# NESP 博弈文档（合订本｜信息性，SSOT 对齐）

写作约定与 SSOT 约束
- 时间边界：截至 2025‑09；如与 SSOT 版本冲突，以 SSOT 为准。
- 信息性/非规范：本合订本不改变协议语义；唯一语义源为 `docs/zh/nesp_spec.md`（简称“SSOT”）。
- 引用与锚点：仅引用 SSOT 的章节与编号（E.x/INV.x/API/EVT/MET/GOV/PR.*/VER）。
- 最小化原则：不重复定义 ABI/事件/指标；不新增不变量/状态/窗口/口径；不引入“仲裁/表决/再分配/熔断/桥控”等内核语义。

目录
- [第一章 模型与假设（SSOT §1/§2/§5/§7/§8/§6）](#ch1)
- [第二章 结果与性质（SSOT §6 映射）](#ch2)
- [第三章 基线对比（信息性/类外对照）](#ch3)
- [第四章 证明草图与反例（信息性/按 Result‑ID）](#ch4)
- [第五章 观测与 SLO（信息性/SSOT 映射）](#ch5)
 

---

<a id="ch1"></a>
## 第一章 模型与假设（联合稿｜信息性，SSOT 对齐）

说明与范围
- 本章为“联合稿”，整合多视角的共同结论，用于解释 NESP（曾用名 NAS/PACT）的模型与假设。


SSOT 锚点
- 设计原则与非目标：SSOT §1
- 模型与记号：SSOT §2（参与者、状态、时间窗口、金额口径等）
- 安全与错误、签名与时间边界：SSOT §5
- API/事件与追溯映射：SSOT §7
- 可观测性与 SLO：SSOT §8
- 收益比较与均衡（信息性）：SSOT §6

1) 参与者与状态（复述自 SSOT）
- 玩家：Client（买方）、Contractor（卖方）。
- 状态空间 S：`{Initialized, Executing, Reviewing, Disputing, Settled, Forfeited, Cancelled}`；转换 E.x 见 SSOT §7、§12。

2) 时间与窗口（复述自 SSOT）
- 锚点：`startTime, readyAt, disputeStart`。
- 窗口：`D_due, D_rev` 可延后（单调），`D_dis` 固定不可延长；统一时间源为 `block.timestamp`（秒）。

3) 金额与口径（复述自 SSOT）
- 托管额 `E`：仅经 `depositEscrow` 单调增加；
- 结清额 `A`：满足 `0 ≤ A ≤ E(t_settle)`；无争议按当前 `E` 全额结清；争议流仅校验签名与 `A ≤ E`。
- 单位：金额以 token 最小单位计价；ETH 与 ERC‑20 保持一致语义（细节见 SSOT §7）。

4) 动作与接口（引用 SSOT，不重复定义）
- 参考最小集：`createOrder/createAndDeposit/depositEscrow/acceptOrder/markReady/approveReceipt/timeoutSettle/raiseDispute/settleWithSigs/timeoutForfeit/extendDue/extendReview/withdraw`（见 SSOT §7）。
- 事件（锚点）：`OrderCreated/EscrowDeposited/Accepted/Settled/AmountSettled/Forfeited/Cancelled/Balance{Credited,Withdrawn}`（见 SSOT §7）。

5) 支付与收益（信息性复述）
- 结清：买方 `V−A`、卖方 `A−C`；
- 没收：对称威慑（双方都拿不到本笔 `E`）。
- 结论（信息性，与 SSOT §6 对齐）：付款不劣、有限步终止（由窗口结构支撑）、Top‑up 比较静态等（详见第二章“结果”与 SSOT PR.*）。

6) 信息结构（信息性）
- 公共：状态、时间戳、托管额 E、事件与日志；
- 私人：V（买方价值）、C（卖方成本）、主观质量信号。

7) 最小内置与可信中立（共识）
- 与 SSOT §1 完全一致：不将仲裁/声誉/投票裁决/再质押等社会判断与外部治理耦合进入合约内核；协议仅提供可验证状态、事件与记账，保持可信中立。
- 若部署启用账户抽象与代付（4337/2771）调用路径，仍不得改变 `A ≤ E`、时间窗口与状态机语义；事件中以 `via` 可观测（SSOT §7）。

8) 公平与社会观察（信息性）
- 公平关注置于观察与解释层，不导出任何“再分配/裁量”的合约诉求：
  - 终态分布（GOV.1）与 `A/E` 分布（GOV.2）可做分群体视图，用于观察可能的不对称影响；
  - 外部费（非协议费，如钱包/转发/打包成本）可设信息性面板，避免“伪零费”叙事偏差。

9) 稳健性方法（信息性，分析层）
- 仅用于 sanity check 与告警，不进入合约守卫：
  - 单调性：检验 `A` 随 `E` 的方向一致性；
  - 分位/秩回归：提升稳健性；
  - 断点/DiD：围绕参数/窗口变更的自然实验；
  - 离群点监测：与 SLO/回滚剧本联动（见第五章）。

10) 工程护栏（信息性，保障模型假设可检）
- Pull 语义与 CEI；提现 `nonReentrant`；
- 签名域完整：`orderId|token|amount|nonce|deadline|chainid`；跨单/跨链/过期/域错分支需测试（SSOT §5）；
- 金额运算采用安全下取整（避免四舍五入提精度）；非标准 ERC‑20 以适配层与白名单策略处理；
- 事件最小字段自检：集中见第五章“观测与 SLO”（以 SSOT §7/§8 为准）。

11) 渗透性与起源（信息性，部署治理维度）
- 起源（自发/有意）与渗透性（高/低）是部署与治理的外部维度，只在应用/市场层体现：
  - 低渗透“沙盒”起步，观察 MET.4/GOV.1/GOV.2 与 MET.1/3；
  - 分层开桥：额度/清算周期/缓冲/熔断等在外围系统实施，不改变内核语义；
  - 指标达标后提升渗透度。

12) 观测映射（SSOT §8 对齐）
- MET.1 结清延迟、MET.3 资金滞留、MET.4 协商接受率、MET.5 零协议费违规（期望 0）、GOV.1 终态分布、GOV.2 `A/E` 分布；
- Trace 链接 E.x ↔ API/EVT ↔ INV.x ↔ MET/GOV（见 SSOT §7、§8、§12）。

13) 边界与非目标（共识）
- 不在合约内核加入：仲裁/表决/再分配/停市/熔断/桥控等；
- 不在本合订本文档重复定义 ABI/事件口径或新增不变量；
- 行为模型与方法学仅用于分析与告警，不进入状态机守卫。

---

<a id="ch2"></a>
## 第二章 结果与性质（信息性/SSOT 映射）

说明
- 本章仅汇总“可解释结论”的信息性表述，并映射到 SSOT 的 PR.* 编号；不改变协议语义。

结果索引（Result‑ID ↔ SSOT.PR.*）
- Result‑1（付款不劣）↔ SSOT PR.1：`u_C(pay) − u_C(forfeit) = E − A ≥ 0`；当 `A<E` 时严格 > 0。
- Result‑2（卖方没收为劣；常见参数）↔ SSOT PR.2：若 `R(t) < A`，则 `A − R(t) > 0 ≥ −I(t)`。
- Result‑3（SPE 充分条件）↔ SSOT PR.3：存在 `A ∈ (C, min(V, E)]` 且 `κ(Review/Dispute)=1`（定义见 SSOT §2，以 SSOT 定义为准），则“交付并结清”为子博弈完美均衡路径。
- Result‑4（比较静态/Top‑up 单调）↔ SSOT PR.4：Top‑up 把买方偏好由 `forfeit/tie` 推向 `pay`。

观测映射（信息性）
- Result‑1/2：对应 MET.1/MET.3（结清与滞留）与 GOV.1（终态分布）的稳定性；
- Result‑3：通过路径覆盖与最长时长校验支撑“有限终止”（见 SSOT §8、§12）；
- Result‑4：可在分析层检验 `A ~ E + T_dis` 的方向一致性（信息性），不入合约守卫。

扩展插槽（占位）
- Result‑5+：当 SSOT 新增 PR.* 或信息性结论扩展时，再行映射与补充。

有效性验收口径（信息性）
- 判定谓词 `Effectiveness(W)`：`(R1 ∧ R2 ∧ R3 ∧ R4)` 且 `SLO_T(W)` 且 `Δ_BASELINE(W) ≥ 0`。
  - `SLO_T(W)`：在观测窗口 `W` 内满足部署侧在 CHG 中定义的阈值集 `T`（至少含：`MET.5=0`、没收率 ≤ θ、协商接受率 ≥ β、结清 P95 延迟 ≤ τ）。
  - `Δ_BASELINE(W)`：与选定基线在相同窗口/口径下的差值（定义见第三章“对照口径”）。
  - 说明：上述为信息性判据；数值阈值与窗口由部署侧版本化定义（不改 SSOT 语义）。
  - 字段与窗口：参见第五章“观测与 SLO”（以 SSOT §7/§8 为准）。
  - 符号注记：`f` 为部署侧定义的加权函数（见 CHG:Effective-Params）。
  - CHG 绑定（必须存在）：`CHG:Effective-Params = { W, θ, β, τ, f }`；缺失或无效则 `Effectiveness(W)` 不可评估。

---

<a id="ch3"></a>
## 第三章 基线对比（信息性/类外对照）

说明与范围
- 本章用于对比 NESP 与常见替代方案的结构性差异，供场景选择与决策支持；不改变协议语义。
- 重要：部分基线违反 NESP 的“无仲裁（No‑Arbitration）”前提（见 SSOT §1），因此为“类外对照”，不纳入约束最优性链条。
- 比较为定性信息，用于理解结构性差异；不并入 NESP 的指标口径或 SSOT 语义。

对照口径（信息性）
- 设观测窗口 `W` 与版本口径 `VER.*`，在相同窗口/来源/字段下定义：
  - 成功率 `succ = #Settled / (#Settled + #Forfeited + #Cancelled)`；
  - 没收率 `forf = #Forfeited / (#Settled + #Forfeited + #Cancelled)`；
  - 结清延迟 `p95_settle`（按 SSOT 指标）与协商接受率 `acc`（MET.4）。
- 定义 `Δ_BASELINE(W) = f(succ, forf, p95_settle, acc)_NESP − f(…)_Baseline`（`f` 为部署侧选择的加权函数，记录于 CHG）。
- 说明：仅为对照的口径定义；不改变 SSOT 与指标语义。
 - 对照数据绑定（CHG，必须存在）：`CHG:Baseline-Data = { source, fields_map, window=W }`；缺失或无效则 `Δ_BASELINE(W)` 不可计算。

对象清单（摘要）
- 基线 1：直接支付（无机制）
  - 结构：买方先付、卖方后交付，无托管与追索；
  - 直观：在主观性交付/一次性交易中，合作难以维持，交易失败概率高，社会福利趋近 0。

- 基线 2：中心化托管 + 仲裁（类外对照；违反 No‑Arbitration）
  - 结构：平台持有托管 E，发生争议时以证据裁量；
  - 结构性成本与约束（示例，见 refs/*）：平台费、争议/仲裁成本、保障/延迟成本、KYC/地域准入、平台裁量流程；
  - 取舍：擅长复杂证据/人工判断；带来费用与治理俘获风险，不满足最小内置与可信中立。

- 基线 3：其他信任最小化机制（结构对比）
  - HTLC：适于可验证资产的原子交换；无法表达主观性交付与 `A∈(0,E]` 的部分结清；
  - 状态通道：适于重复交互/低争议场景；需双边流动性锁定与在线性，不适合陌生方一次性 A2A；
  - 去中心化仲裁（Kleros/Aragon Court 等）：引入治理裁量/投票，违反 No‑Arbitration（类外对照）。

- 基线 4：可信中立性（Credible Neutrality）视角
  - 目标：机制不依赖特定参与者的裁量，且“可见的中立”便于外部理解与审计；
  - NESP 的位置：以“公开时间窗口 + 对称规则 + 可验证签名 + 零协议费”实现接近目标；开放事件口径便利外部审计。

适用性指引（信息性）
- 倾向 NESP 的条件：
  - 主观性交付/一次性交换，需可审计而不引入平台裁量；
  - 需要 `A∈[0,E]` 的部分结清与对称威慑；
  - 追求最小内置与可信中立；
  - 可接受“限时协商 + 对称没收”的硬威慑与零协议费。
- 倾向中心化托管/仲裁（类外对照）的条件：
  - 高复杂证据/高度主观评价、强监管/KYC 要求、愿意承担平台费与裁量；
  - 可接受平台作为最终裁决者（与 No‑Arbitration 原则不相容）。
- 其他：
  - 原子交换/可验证客观条件 → HTLC；
  - 高频、重复、低争议 → 状态通道；
  - 投票裁决可接受 → 去中心化仲裁（类外）。

观测与对照（信息性）
- 对 NESP：通过 MET.1/3/4、GOV.1/2、MET.5（=0）与 Trace 进行健康度评估；
- 对中心化与仲裁平台：参考外部费/处理周期/纠纷率/退款率等公开数据（见 refs/*），不混入 NESP 的指标口径。

资料与追溯（仓库内 refs/*）
- `refs/ebay_selling_fees.html`
- `refs/ebay_money_back.html`
- `refs/kleros_stats.html`
- `refs/upwork_identity_verification.html`
- `refs/upwork_disputes_mediation.html`
- `refs/upwork_freelancer_fees.html`

注：上述 refs/* 为外部资料索引，非 NESP 指标口径的一部分。

---

<a id="ch4"></a>
## 第四章 证明草图与反例（信息性/按 Result‑ID）

说明
- 本章提供“信息性”的证明草图与反例库，逐条映射第二章的 Result‑ID，并标注 SSOT 锚点（PR.* / INV.* / E.x / API/EVT）。
- 不改变协议语义；若规范变化，需在 SSOT 进行版本化并回链到此处。

前提与范围（共识，信息性）
- 语义源：仅引用 SSOT；不新增任何内核假设。
- 前提复述（来自 SSOT）：
  - 金额口径：`A ≤ E(t_settle)`；E 仅由 `depositEscrow` 单调增加；
  - 时间窗口：`D_due/D_rev` 可延后（单调），`D_dis` 固定不可延长；
  - 签名与安全：EIP‑712/1271 签名域完备（`orderId|token|amount|nonce|deadline|chainid`），Pull 语义与 CEI；
  - 事件与追溯：E.x ↔ API/EVT ↔ INV.x ↔ MET/GOV 可追溯（SSOT §7/§8）。

观测与复现（共识，信息性）
- 指标锚点：MET.1/3/4、GOV.1/2、MET.5（=0）；字段与 Trace 见第五章“观测与 SLO”（以 SSOT §7/§8 为准）。
- 方法参考：单调/分位/断点/DiD 为分析层工具，不进入守卫；回滚剧本见第五章。

红线与非目标（共识）
- 不把公平/再分配/裁量/外部治理依赖写入内核或证明语义；
- 不在本章重复定义 ABI/事件或新增不变量；
- 渗透性/起源属于部署与治理层（应用层讨论），与证明语义解耦。

Proof Sketch — Result‑1（付款不劣）↔ SSOT PR.1
- 假设：`A ≤ E`（INV.1），无争议全额结清（SSOT §1/§2），Pull 结算（资金会计独立）。
- 结论：`E − A ≥ 0` 成立；当 `A<E` 严格大于 0。
- 观测：结清/退款计入 `Balance{Credited,Withdrawn}`；对应 MET.1/MET.3。

Proof Sketch — Result‑2（卖方没收为劣；常见参数）↔ SSOT PR.2
- 假设：争议路径有效，且 `R(t) < A`；
- 结论：`A − R(t) > 0 ≥ −I(t)`，形成没收的劣势偏好。
- 观测：GOV.1 的没收率与 MET.6 时延分布。
 - 代理判据（信息性）：结合第二章 `SLO_T(W)` 阈值，视 `GOV.1 ≤ θ ∧ MET.4 ≥ β` 为“倾向满足”。

Proof Sketch — Result‑3（SPE 充分条件）↔ SSOT PR.3
- 假设：存在 `A ∈ (C, min(V, E)]` 且评审/争议阶段 `κ=1`；
- 结论：回溯归纳给出“交付并结清”的子博弈完美均衡路径；
- 观测：路径覆盖（E.*）完整，最长时长 ≤ `D_due+D_rev+D_dis`（SSOT §8）。

Proof Sketch — Result‑4（比较静态/Top‑up 单调）↔ SSOT PR.4
- 假设：`E` 通过 `depositEscrow` 单调增加，且价格在 `A ≤ E` 守卫下协商；
- 结论：Top‑up 将买方偏好从 `forfeit/tie` 推向 `pay`；
- 观测：`A/E` 分布（GOV.2）与 `EscrowDeposited` 事件驱动的 E 曲线。

反例库（占位）
- Ex‑1：允许 `A > E` 或 `E` 可减少 → Result‑1 不成立；
- Ex‑2：允许延长 `D_dis` 或引入外部投票裁决 → 有限终止破坏，Result‑3 失效；
- Ex‑3：`settleWithSigs` 缺少 `orderId|token|amount|nonce|deadline|chainid` 之一 → 重放破坏价格路径。

---

<a id="ch5"></a>
## 第五章 观测与 SLO（信息性/SSOT 映射）

SSOT 绑定与范围
- 唯一语义源：SSOT §7/§8。本章仅提供“指标锚点/事件自检/方法参考”，不改变任何口径。

指标锚点（以 SSOT 为准）
- MET.1 结清延迟 P95、超时触发率。
- MET.3 资金滞留余额。
- MET.4 协商接受率（事件：`AmountSettled` / `DisputeRaised`）。
- MET.5 零协议费违规计数（期望=0；来源：回执/节点日志 `ErrFeeForbidden` 计数）。
- GOV.1 终态分布（成功/没收/取消）。
- GOV.2 `A/E` 基线分布（进入 Reviewing/Disputing 时的 E 作为基线）。

Trace 模式（引用 SSOT 定义，不重复）
- 典型：E12（Disputing→Settled，`settleWithSigs`）→ `AmountSettled, Settled` → MET.4。
- 典型：E13（Disputing→Forfeited，`timeoutForfeit`）→ `Forfeited` → GOV.1/争议时长（SSOT §12 示例）。

事件字段最小自检（信息性提示，口径以 SSOT 为准）
- `Settled(orderId, amountToSeller, escrow, ts, actor)`：需可区分 `actor ∈ {Client, Timeout}`。
- `AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce, ts)`：用于计算 MET.4 与审计签名报文链路。
- `Forfeited(orderId, ts)`：用于 GOV.1 与争议时长统计。
- `EscrowDeposited(orderId, from, amount, newEscrow, ts, via)`：用于资金曲线与代付/转发区分。

方法附录（分析层参考，禁止进入合约守卫）
- 单调性检验：验证 `A` 随 `E` 的方向一致性（信息性 sanity check）。
- 分位/秩回归：降低强分布假设的敏感度。
- 断点/DiD：围绕窗口/参数调整的自然实验。
- 离群点告警：配合 MET/GOV 的阈值，供部署层触发停写/白名单/回滚（见下）。

公平与外部费（信息性面板）
- 分群体 `A/E` 与没收率（GOV.2/GOV.1）；解释偏差但不输出任何再分配/裁量主张。
- 外部费（非协议费）：钱包/转发/打包成本的观测面板，避免“伪零费”的叙事偏差。

SLO 与回滚（部署层）
- SLO 由部署/产品层设定并在变更卡（CHG）中记录；
- 触发条件（示例）：MET.5>0、没收率异常升高、极端 `A/E`、提现失败率上升；
- 动作模板：停写/白名单/回滚（配合 SSOT §10/§11 的版本化与迁移策略）。

退出条件（模板，信息性）：若【唯一判据】在【观察窗 T】内持续满足，则执行【停止/退出/回滚】；默认时区 UTC（或在文首声明）。

有效性 SLO 判据（信息性）
- `SLO_T(W) := (MET.5=0) ∧ (forfeit_rate ≤ θ) ∧ (acceptance_rate ≥ β) ∧ (p95_settle ≤ τ)`；`θ/β/τ` 与窗口 `W` 由部署侧在 CHG 定义。
- “有效性失败 → 退出/回退”：当 `¬Effectiveness(W)` 时，按“退出条件”与变更卡执行停写/白名单/回滚。

数据/工件锚点（模板，信息性）
- 链上事件与回执（网络/合约地址/事件签名）与索引器数据集 ID 由部署侧提供并版本化（CHG）；
- 建议记录：事件主题/字段、解析脚本路径或面板链接、查询窗口与筛选条件；仅作为复现实证的锚点说明。
 - SLO/回滚运行手册绑定（CHG，必须存在）：`CHG:SLO-Runbook = { thresholds_ref, runbook_uri, rollback_steps }`；缺失或无效则 SLO/退出不可核对。

---
