# A2A 无仲裁托管结算协议（NESP）规范
English Title: A2A No‑Arbitration Escrow Settlement Protocol (NESP)
副题：信任最小化 · 限时争议 · 对称没收威慑 (Trust‑Minimized · Timed‑Dispute · Symmetric‑Forfeit (Deterrence))

发布状态：正式颁布版（Release）
版本：0.1
发布日期：2025-09-30

概述（信息性）
- NESP 是面向 A2A 的无仲裁托管结算协议：买方先将应付资金 E 托管至合约，卖方接单并交付；无争议一次性全额放款 E；发生分歧则在争议期内以可验证签名协商结清金额 A（A≤E），差额返还买方；逾期未合意则对称没收托管资金 E 以形成威慑。

核心流程
- Step 1 托管：买方把应付款先存入托管账户（E）。
- Step 2 交付：卖方接单并完成交付/发货。
- Step 3 验收放款（无争议）：买方验收通过，托管款一次性全额打给卖方（E）（若配置 FeeHook，卖方实际可提为 `E − fee`；详见 §3.3 终态资金口径）。
- Step 4 发起争议（如有）：在限定时间内提出分歧。
- Step 5 限时协商：双方在争议期内商定付款数额 A（A≤E）→ 按 A 付款，剩余返还买方。
- Step 6 超时威慑：若超时仍未达成一致，则对称没收这笔托管款（双方都拿不到，划入 ForfeitPool；罚没资产默认沉淀于协议，可由治理模块提取用于协议费用；其他用途须经社区决议授权）。
- 说明：无平台仲裁。

## 0) 规范与追溯锚点
- 规范用语：MUST/SHOULD/MAY/MUST NOT。
- 语义优先级：本规范的“状态机与守卫” > 模型与记号 > 不变量 > API/事件 > 安全 > SLO > 治理数据 > 版本/变更 > 附录。
- ID 约定：
  - 状态转移边：E.x；不变量：INV.x；接口/事件：API.x/EVT.x；指标：MET.x（社会侧可用 GOV.x）；版本口径：VER.x；错误：ERR.x；结论：PR.x。
- Trace 原则（MUST）：每条 E.x 至少映射到一个 API/EVT，并覆盖相关 INV.x 与至少一项 MET.x/GOV.x。
- 发起方术语：client=买方，contractor=卖方，任意=任何 EOA 或合约地址（permissionless）。
- 术语大小写：client/contractor 与 Client/Contractor 等同（不区分大小写）。

## 1) 设计原则与非目标（Minimal Enshrinement）
- MUST NOT：将仲裁、信誉、治理投票等社会层逻辑内置到共识。
- MUST：协议仅提供可验证状态、事件与记账（Pull 结算）。
- MUST：金额口径仅以托管额 E 与结清额 A 表达（链上仅记录托管与结清）。
- MUST：唯一机制：线下协商应付金额 → 买方上链托管相应资金 E；线下验收 → 链上确认，全额结清；争议路径采用签名协商金额结清（见 §4）。
- MUST：资金仅经由 `depositEscrow` 单调增加；不支持减少或替换托管；订单创建不要求金额（escrow 初始为 0）。
- SHOULD：`acceptOrder`（承接）仅在“托管额满足线下协商的应付金额”时进行（产品层闸门），实现层可选检查 `escrow > 0`。
- SHOULD：参数渐进、可观测驱动；保持实现简单、可审计。

注：NESP 的命名来源于 No‑Arbitration（无仲裁）原则。

链上仅记录托管与结清（规范性）
- MUST：协议在接口/存储/事件中仅记录托管额 E 与结清额 A，且始终满足 `A ≤ E`。
- MUST NOT：任何守卫与状态转移除状态、`E`、`D_*` 与签名校验外，不得依赖其他外部金额字段。
- MUST：无争议结清按当前 E 全额放款（`approveReceipt/timeoutSettle => amountToSeller = E`）。
- MUST：争议结清仅校验签名与 `A ≤ E`。

## 2) 模型与记号（A ≤ E 口径）
- 参与者：Client、Contractor。
- 时间与计时器：`startTime, readyAt, disputeStart`；`D_due, D_rev, D_dis`（相对时长，单位：秒；其中 `D_due/D_rev` 允许“单调延后”，`D_dis` 固定且不可延长）。
- 资金与金额：`E`（托管额，单调不减、不可减少）、`A`（实际结清额，0 ≤ A ≤ E）。
- 结清判定：结清动作发生时（验收或超时放款，或签名协商被对手方接受后上链），以当时的 E 计算 `A` 与退款。
 - 术语与符号（信息性）：
  - `V`：买方价值（与 E/A 同口径）；`C`：卖方成本（与 E/A 同口径）。
  - `κ(t)`：可用性/状态系数（Executing∈[0,1]；Reviewing/Disputing=1）。
  - `R(t)`/`I(t)`：卖方/买方的机会收益/沉没成本项（用于收益比较，非结算口径的一部分）。
 - 可用性与成本：`κ(t)`（Executing∈[0,1]；Reviewing/Disputing=1）、`R(t)`、`I(t)`；收益 `(V−A, A−C)`。
- 对手与信息结构：自利/半理性；公开 `state/times/escrow`；协商采用可验证签名（EIP‑712/1271）。
- 单位与时间：金额以 token 最小单位计价；时间以 `block.timestamp`（秒）计；区块时间抖动不作为纠纷判断依据；命名约定：
  - `*Sec` 后缀仅用于 API/输入参数的相对时长（秒）（如 `newDueSec/newRevSec`）；API 参数命名 MUST 使用 `*Sec` 后缀；
  - 模型参数使用 `D_*` 命名（如 `D_due/D_rev/D_dis`），表示相对时长（秒）（MUST）；
  - `startTime/readyAt/disputeStart` 为绝对时间（时间戳）。
- 记号约定：文中 `now ≡ block.timestamp`；CEI ≡ checks–effects–interactions。

- 资产与代币（MUST）：
  - `tokenAddr` 表示资产标识（ERC‑20 合约地址或“原生 ETH”哨兵标识）。
  - 原生 ETH 支持：当订单资产为 ETH 时，`depositEscrow`/`createAndDeposit` 为 `payable`，要求 `msg.value == amount`；提现使用 `call` 且 `nonReentrant`。
  - ERC‑20 资产：要求 `msg.value == 0`，并使用 SafeERC20 `transferFrom` 扣划 `amount`（或在 `createAndDeposit` 中一并完成）。
  - 建议（SHOULD）：部署方可提供“封装 ETH（WETH）适配层”作为工程选项，但规范层面必须支持原生 ETH。

### 2.1 参数协商与范围（规范性）
- 协商主体与生效时点（MUST）：`E`、`D_due`、`D_rev`、`D_dis` 由 Client 与 Contractor 针对“每一笔订单”达成一致；实现必须在订单建立/接受时将其作为“订单字段”固化存储。
- 默认值（MUST）：协议定义以下默认值，用于调用方未显式指定时：`D_due = 1 day = 86_400s`、`D_rev = 1 day = 86_400s`、`D_dis = 7 days = 604_800s`。采用默认时，必须在订单创建时将“生效值”固化存储并在 `OrderCreated` 事件中记录。
- 修改规则（MUST）：
  - `E` 仅可通过 `depositEscrow` 单调增加，不得减少；
  - `D_due` 与 `D_rev` 仅允许在争议发生前“单调延后”（见 SIA1/SIA2），不得缩短；
  - `D_dis` 自设置后固定，协议层不提供延长入口（禁止 `extendDispute`）。
- 有界性（MUST）：存储口径下，三者必须为有限值且大于 0；为抵御链上重组，`D_dis ≥ 2·T_reorg`（由部署方按目标链给出 `T_reorg` 估计）。
- 零值约定（MUST）：允许在 `createOrder/createAndDeposit` 时传入 `dueSec/revSec/disSec = 0` 表示“采用协议默认值”；实现收到零值时必须以内置默认替换后再存储与发事件。除上述入口的零值语义外，其他接口与持久化字段不得为 0。
- 建议（SHOULD）：产品/客户端可根据场景提供“参数模板/推荐区间”，默认可预填为 `1d/1d/7d`，但应允许用户覆盖。

## 3) 状态机与守卫（规范性，SSOT）

### 3.0 允许的转换（除此之外无其他，MUST）
注：变量与时间相关的副作用统一见 3.2 “守卫与副作用”。下列每条转移标注发起方：client、contractor、任意（三类含义：买方、卖方、无主体限制）。
- E1 Initialized -acceptOrder-> Executing（发起方：contractor）
- E2 Initialized -cancelOrder-> Cancelled（发起方：client/contractor）
- E3 Executing -markReady-> Reviewing（发起方：contractor）
- E4 Executing -approveReceipt-> Settled（发起方：client）
- E5 Executing -raiseDispute-> Disputing（发起方：client/contractor）
- E6 Executing -cancelOrder-> Cancelled（发起方：client）
- E7 Executing -cancelOrder-> Cancelled（发起方：contractor）
- E8 Reviewing -approveReceipt-> Settled（发起方：client）
- E9 Reviewing -timeoutSettle-> Settled（发起方：任意）
- E10 Reviewing -raiseDispute-> Disputing（发起方：client/contractor）
- E11 Reviewing -cancelOrder-> Cancelled（发起方：contractor）
- E12 Disputing -settleWithSigs-> Settled（发起方：对手方（client 或 contractor 之一））
- E13 Disputing -timeoutForfeit-> Forfeited（发起方：任意）


### 3.1 状态不变动作（SIA，MUST）
- SIA1 `extendDue(orderId, newDueSec)`：
  - Condition：`newDueSec > 当前 D_due`（严格延后）。
  - Subject：`client`。
  - Effects：`D_due` 更新为 `newDueSec` 并发出 `DueExtended`。
  - Failure：条件未满足 MUST `revert`（`ErrInvalidState`）。
- SIA2 `extendReview(orderId, newRevSec)`：
  - Condition：`newRevSec > 当前 D_rev`（严格延后）。
  - Subject：`contractor`。
  - Effects：`D_rev` 更新为 `newRevSec` 并发出 `ReviewExtended`。
  - Failure：条件未满足 MUST `revert`（`ErrInvalidState`）。
- SIA3 `depositEscrow(orderId, amount)`（`payable`）：
  - Condition：`amount > 0`；`state ∈ {Initialized, Executing, Reviewing}`；当订单资产为 ETH 时 MUST `msg.value == amount`，为 ERC‑20 时 MUST `msg.value == 0` 且 `SafeERC20.transferFrom(payer, this, amount)` 成功。
  - Subject：
    - 受信任的 2771/4337 路径：解析得到的 `subject` MUST 等于 `client`；
    - 其他任意地址：视为赠与主体，须自行完成授权并承担没收风险。
  - Effects：`escrow ← escrow + amount`（单调增加），触发 `EscrowDeposited`。
  - Failure：
    - `state ∈ {Disputing, Settled, Forfeited, Cancelled}` MUST `revert`（`ErrFrozen` 或 `ErrInvalidState`）；
    - 主体不符 MUST `revert`（`ErrUnauthorized`）；
    - 资产/转账校验失败 MUST `revert`（`ErrAssetUnsupported` 或等效错误）。

### 3.2 守卫与副作用（MUST）
- 统一规则（MUST）：所有守卫以 `{Condition, Subject, Effects, Failure}` 描述，未列出的路径一律禁止。
- 参数持久化（MUST）：订单建立/接受时必须固化 `D_due/D_rev/D_dis` 的实际值；不得依赖链上“隐式默认”。
- 锚点一次性（MUST）：`startTime/readyAt/disputeStart` 设置后不得回拨或覆写；`D_due/D_rev` 仅允许单调延长，协议不提供 `extendDispute`。
- 调用主体（Resolved Subject）定义：
  - 直连：`subject = msg.sender`，`via = address(0)`；
  - EIP‑2771：若 `isTrustedForwarder(msg.sender)=true`，`subject = _msgSender()`；
  - EIP‑4337：若 `msg.sender == EntryPoint`，`subject = userOp.sender`。

- 守卫条目（MUST）：
  - G.E1 `acceptOrder`：
    - Condition：`state = Initialized`。
    - Subject：`contractor`（经受信路径解析后）。
    - Effects：状态转入 Executing，并设置 `startTime = now`。
    - Failure：条件未满足 MUST `revert`（`ErrInvalidState` 或 `ErrUnauthorized`）。
  - G.E3 `markReady`：
    - Condition：`state = Executing` 且 `now < startTime + D_due`。
    - Subject：`contractor`。
    - Effects：状态转入 Reviewing，并设置 `readyAt = now`（重新起算 `D_rev`）。
    - Failure：条件未满足 MUST `revert`。
  - G.E4/G.E8 `approveReceipt`：
    - Condition：`state ∈ {Executing, Reviewing}`。
    - Subject：`client`。
    - Effects：结清金额 `amountToSeller = escrow`，状态转入 Settled；与 3.3 终态资金口径一致：记账三笔（`Payout=amountToSeller−fee`、`Refund=escrow−amountToSeller`、`Fee=floor(amountToSeller*bps/10_000)`），订单 `escrow` 清零。
    - Failure：条件未满足 MUST `revert`。
  - G.E5 `raiseDispute`（执行阶段）：
    - Condition：`state = Executing` 且 `now < startTime + D_due`。
    - Subject：`client` 或 `contractor`。
    - Effects：状态转入 Disputing，设置 `disputeStart = now`，托管额 E 冻结（禁止后续充值）。
    - Failure：条件未满足 MUST `revert`。
  - G.E10 `raiseDispute`（评审阶段）：
    - Condition：`state = Reviewing` 且 `now < readyAt + D_rev`。
    - Subject：`client` 或 `contractor`。
    - Effects：状态转入 Disputing，保持/设置 `disputeStart = now` 并冻结托管额。
    - Failure：条件未满足 MUST `revert`。
  - G.E6 `cancelOrder`（client）：
    - Condition：`state = Executing`、`readyAt` 未设置，且 `now ≥ startTime + D_due`。
    - Subject：`client`。
    - Effects：状态转入 Cancelled；将订单 `escrow` 全额按退款口径记账至买方可提余额（Refund），订单 `escrow` 清零。
    - Failure：条件未满足 MUST `revert`。
  - G.E7 `cancelOrder`（contractor，执行阶段）：
    - Condition：`state = Executing`。
    - Subject：`contractor`。
    - Effects：状态转入 Cancelled；将订单 `escrow` 全额按退款口径记账至买方可提余额（Refund），订单 `escrow` 清零。
    - Failure：条件未满足 MUST `revert`。
  - G.E9 `timeoutSettle`：
    - Condition：`state = Reviewing` 且 `now ≥ readyAt + D_rev`。
    - Subject：任意地址。
    - Effects：结清金额 `amountToSeller = escrow`，状态转入 Settled；与 3.3 终态资金口径一致：记账三笔并清零 `escrow`。
    - Failure：条件未满足 MUST `revert`。
  - G.E11 `cancelOrder`（contractor，评审阶段）：
    - Condition：`state = Reviewing`。
    - Subject：`contractor`。
    - Effects：状态转入 Cancelled；将订单 `escrow` 全额按退款口径记账至买方可提余额（Refund），订单 `escrow` 清零。
    - Failure：条件未满足 MUST `revert`。
  - G.E12 `settleWithSigs`：
    - Condition：`state = Disputing`，`now < disputeStart + D_dis`，`amountToSeller ≤ escrow`，并通过 EIP‑712/1271 签名、`nonce`、`deadline` 校验。
    - Subject：`client` 或 `contractor`。
    - Effects：按签名金额结清（`amountToSeller = A`），状态转入 Settled；与 3.3 终态资金口径一致：记账三笔并清零 `escrow`。
    - Failure：条件未满足 MUST `revert`（`ErrBadSig/ErrReplay/ErrExpired/ErrOverEscrow` 等）。
- G.E13 `timeoutForfeit`：
    - Condition：`state = Disputing` 且 `now ≥ disputeStart + D_dis`。
    - Subject：任意地址。
    - Effects：状态转入 Forfeited，订单托管额全额计入 ForfeitPool（增加 `forfeitBalance[tokenAddr]`），订单 `escrow` 清零；罚没资产继续由治理模块托管，可在满足授权条件时提取。
    - Failure：条件未满足 MUST `revert`。

### 3.3 终态约束（MUST）
- `Settled/Forfeited/Cancelled` 为终态；到达终态后不得再改变状态或资金记账；仅允许提现型入口读取并领取既有可领额（若有）。

## 4) 结算与不变量（Pull 支付）
- 金额计算
  - INV.1 全额结清：`amountToSeller = escrow`（approve/timeout）。
  - INV.2 金额型结清：`amountToSeller = A` 且 `0 ≤ A ≤ escrow`（签名协商）。
  - INV.3 退款：`refundToBuyer = escrow − amountToSeller`（若 A < escrow）。
- 资金安全
- INV.4 单次入账：每单至多一次将结清额/退款额入账至聚合余额（single_credit），防止重复计入可提余额。
  - INV.5 幂等提现：提现前先读取并清零聚合余额，转账成功即完成；重复调用无可提余额，返回无副作用。
  - INV.6 入口前抢占：外部入口先处理 `timeout*`，防延迟攻击。
  - INV.7 资产与对账：SafeERC20 + 余额差核验；必要时采用白名单/适配层。对“费率/重基/非标准”代币如无法保证恒等对账，MUST `revert`（ErrAssetUnsupported）。
- 资金去向与兼容
  - INV.8 Forfeited：`escrow → ForfeitPool`（治理可控提取），`owed/refund` 清零。ForfeitPool 为合约内逻辑账户：罚没资产默认留存在合约余额，仅能在满足治理授权（协议费用或经社区授权的用途）时，由治理模块调用治理提款接口转出；ETH 与 ERC‑20 采用一致语义。
    - 记账不变量：维护 `forfeitBalance[tokenAddr]`；Forfeited 时增加，治理提款时减少；MUST 满足 `forfeitBalance[tokenAddr] ≥ 0`。
    - 全量资金恒等式（审计）：分 `tokenAddr` 核对“合约资产余额 = Σ 未终态订单 escrow + Σ 用户聚合可提余额 + forfeitBalance”。
  - INV.9 比例路径兼容（可选）：`amountToSeller = floor(escrow * num / den)`；余数全部计入买方退款。实现 MUST 使用安全的“mulDiv 向下取整”或等效无溢出实现；任何溢出/下溢 MUST revert；禁止四舍五入与精度提升。
- INV.10 Pull 语义：状态变更仅“记账可领额”（聚合到 `balance[token][addr]`），实际转账仅在 `withdraw(token)` 发生；治理提款为系统级外流，不属于用户 `withdraw(token)`，但须满足 INV.8 与安全约束；禁止在状态变更入口直接 `transfer`。
  - INV.14 手续费（FeeHook）：当订单处于 Settled 终态时，若已配置 `feeHook`，则按 Hook 返回的 `fee` 计入手续费可提余额；必须满足 `0 ≤ fee ≤ amountToSeller`，且守恒成立：`(amountToSeller − fee) + (escrow − amountToSeller) + fee = escrow`。当 `feeHook = address(0)` 或 `fee = 0` 时不产生 Fee 记账与事件；Cancelled/Forfeited 不计费。
  - INV.11 锚点一次性：`startTime/readyAt/disputeStart` 一旦设置，MUST NOT 修改或回拨（仅允许“未设置 → 设置一次”）。
  - INV.12 计时器规则：`D_due/D_rev` 仅允许延后（单调增加，且在进入 Disputing 前）；`D_dis` 固定且不可延长。
  - INV.13 唯一机制：无争议路径必须全额结清；争议路径采用签名金额结清；金额口径始终满足 `A ≤ E`，链上仅记录托管与结清。


## 5) 安全与威胁模型
- 签名与重放（MUST）：采用 EIP‑712/1271；签名域至少包含 `{chainId, contract, orderId, amountToSeller(=A), proposer, acceptor, nonce, deadline}`；`amountToSeller ≤ E`；`nonce` 的作用域至少为 `{orderId, signer}` 且一次性消费；`deadline` 基于 `block.timestamp` 判定。必须防止跨订单/跨合约/跨链重放。
- 错误映射（MUST）：统一的失败→错误码映射如下：
  - 签名不匹配/域不符 → `ErrBadSig`
  - `nonce` 已用/冲突 → `ErrReplay`
  - 报文超期（`deadline < now`）→ `ErrExpired`
  - 非授权充值主体（SIA3 授权校验失败）→ `ErrUnauthorized`
  - 争议冻结期充值 → `ErrFrozen`
  - 终态/非法状态的入口调用 → `ErrInvalidState`
  - 托管不足/超额 → `ErrOverEscrow`
  - 非标准/不支持资产 → `ErrAssetUnsupported`
- 重入与交互顺序：提现 `nonReentrant`，遵循 CEI。
- 时间边界：统一区块时间；`D_due/D_rev` 仅允许延后（单调），`D_dis` 固定且不可延长。
- 残余风险：破坏型对手导致的没收外部性 → 由社会层资质/信誉/稽核约束。

## 6) 收益比较与均衡（SPE 概要）
- PR.1 付款不劣：`u_C(pay) − u_C(forfeit) = E − A ≥ 0`；当 `A<E` 时严格 > 0。
 - PR.2 卖方没收为劣：若 `R(t) < A`，则 `A − R(t) > 0 ≥ −I(t)`。
- PR.3 SPE（充分条件）：存在 `A ∈ (C, min(V, E)]` 且 `κ(Review/Dispute)=1`，则“交付并结清”为子博弈完美均衡路径。
- PR.4 比较静态：Top‑up 单调把买方偏好由 `forfeit/tie` 推向 `pay`。

## 7) API 与事件契约（映射状态机/不变量）
- 函数（最小集）：
  - `createOrder(tokenAddr, contractor, dueSec, revSec, disSec, feeHook, feeCtxHash) -> orderId`
    - 零值采用默认（MUST）：若 `dueSec/revSec/disSec` 传入 0，表示采用协议默认值（`1d/1d/7d`）；事件 `OrderCreated` 中的 `dueSec/revSec/disSec` 必须记录替换后的“生效值”（非 0）。
  - `createAndDeposit(tokenAddr, contractor, dueSec, revSec, disSec, feeHook, feeCtxHash, amount)`（payable）→ 创建并充值（ETH: `msg.value==amount`；ERC‑20: `SafeERC20.safeTransferFrom` amount）
  - `depositEscrow(orderId, amount)`（payable；同上资产规则）
  - `acceptOrder(orderId)`；`markReady(orderId)`；`approveReceipt(orderId)`；`timeoutSettle(orderId)`
  - `raiseDispute(orderId)`；`settleWithSigs(orderId, payload, sig1, sig2)`；`timeoutForfeit(orderId)`
  - `cancelOrder(orderId)`
  - `withdraw(tokenAddr)`：提取累计收益或退款（Pull 语义，`nonReentrant`），成功时触发 `BalanceWithdrawn`。
  - `withdrawForfeit(tokenAddr, to, amount)`：治理模块调用，从 ForfeitPool 中提取指定资产；成功时触发 `ProtocolFeeWithdrawn`。
  - `extendDue(orderId, newDueSec)`；`extendReview(orderId, newRevSec)`（单调延后）
  - `getOrder(orderId) view`：返回 `{client, contractor, tokenAddr, state, escrow, dueSec, revSec, disSec, startTime, readyAt, disputeStart, feeHook, feeCtxHash}`。
  - `withdrawableOf(tokenAddr, account) view`：读取聚合可提余额（涵盖 `Payout/Refund/Fee`）。
- 事件（建议的最小充分字段；单一清单）：
  - `OrderCreated(orderId, client, contractor, tokenAddr, dueSec, revSec, disSec, feeHook, feeCtxHash)`
  - `EscrowDeposited(orderId, from, amount, newEscrow, via)`；`Accepted(orderId, escrow)`；`ReadyMarked(orderId, readyAt)`；`DisputeRaised(orderId, by)`
    - 字段口径：`via ∈ {address(0), forwarderAddr, entryPointAddr}`；`address(0)` 表示直接调用（`msg.sender == tx.origin`）；2771 记录转发合约地址，且 `isTrustedForwarder(via)=true`；4337 记录实现配置的 `EntryPoint` 地址。除上述三类外的合约调用 MUST `revert`（ErrUnauthorized）。不支持多重转发/嵌套；如检测到多跳 MUST `revert`（ErrUnauthorized）。授权失败为回滚路径，不发 `EscrowDeposited` 事件。
  - `DueExtended(orderId, oldDueSec, newDueSec, actor)`（`actor == client`）；`ReviewExtended(orderId, oldRevSec, newRevSec, actor)`（`actor == contractor`）
  - `Settled(orderId, amountToSeller, escrow, actor)`（`actor ∈ {Client, Timeout}`）
  - `AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce)`
  - `AssetUnsupported(orderId, tokenAddr)`（可选；仅当适配层在配置/预检流程中判定资产不支持且事务成功返回时发射；主流程内若以 `ErrAssetUnsupported` 回滚则不发。唯一性：同一 `orderId`/`tokenAddr` 在同一版本配置周期内最多发射一次，重复预检不得重复发射。）
  - `Forfeited(orderId, tokenAddr, amount)`；`Cancelled(orderId, cancelledBy)`（`cancelledBy ∈ {Client, Contractor}`）
  - `BalanceCredited(orderId, to, tokenAddr, amount, kind)`（`kind ∈ {Payout, Refund, Fee}`）
  - `BalanceWithdrawn(to, tokenAddr, amount)`
  - `ProtocolFeeWithdrawn(tokenAddr, to, amount, actor)`
  - 说明：事件不再携带显式时间字段，统一以日志所在区块的 `block.timestamp` 作为时间锚点。

#### 7.A 证据承诺（可选扩展，NESP‑EVC）
证据承诺不属于内核规范；接口/事件与实现建议见 NESP‑EVC 扩展文档。
- 错误（示例）：ERR.1 `ErrInvalidState`；ERR.2 `ErrGuardFailed`；ERR.3 `ErrAlreadyPaid`；ERR.4 `ErrExpired`；ERR.5 `ErrBadSig`；ERR.6 `ErrOverEscrow`；ERR.7 `ErrFrozen`；ERR.8 `ErrAssetUnsupported`；ERR.9 `ErrReplay`；ERR.10 `ErrUnauthorized`。
- 映射规则（MUST）：E.x ↔ API/EVT ↔ INV.x ↔ MET.x/GOV.x 一一可追溯。
 - （工程建议）资产支持与适配层细节见平台工程文档。

## 8) 可观测性与 SLO
- 指标（示例）：
  - MET.1 结清延迟 P95、超时触发率；
  - MET.2 提现失败率、重试率；
  - MET.3 资金滞留余额；
  - MET.4 争议时长分布、协商接受率（公式：协商接受率 = `AmountSettled` 事件数 / `DisputeRaised` 事件数；建议观测窗口 7/30 天滚动；撤销/过期不计入分子；每单仅计首个 `AmountSettled`；跨窗口滚动按事件时间戳归属；分母按“同一订单在结清/没收前的首次 `DisputeRaised` 计 1 次”，重复触发/撤销不重复计数）。
  - MET.5 状态转换延迟/吞吐（E1/E3/E5/E10 等非终态转换的时延与速率）；
  - GOV.1 终态分布（成功/没收/取消）；
（EVC 指标见扩展文档 NESP‑OPS/NESP‑EVC）。
- GOV.2 `A/E` 基线分布（以进入 Reviewing 或 Disputing 时的 E 为基线，见 VER）。
- GOV.4 ForfeitPool 使用台账：统计没收累计额、提现金额，校验 `forfeitBalance` 不为负；公开用途分类（协议费用/社区授权用途）。
- SLO（示例）：提现成功率 ≥ 99.9%；结清到账 P50 < 1 区块、P95 < 3 区块；资金滞留余额 < 0.1%（周）。
- 熔断/回滚：超阈触发“切换白名单/停写/回滚”剧本（与第10、11章联动）。

## 9) 治理与数据（社会层）
- 口径版本化（VER）：明确窗口（如 7 天）、基线定义（进入 Reviewing/Disputing 时的 E）、字段来源与版本号。
- 隐私与可解释：最小披露、可验证日志；保留 `nonce/deadline/proposer` 证据链；提供申诉/审计通道（模板化）。

## 10) 版本化与变更管理
- 语义版本：状态机/INV/API/MET 任一变更 → 次版本以上；破坏性变更 → 主版本。
- 变更卡（CHG）：记录影响面（4→5→7→8 链路）、迁移/回滚步骤、兼容窗口。
- 兼容别名（信息性）：为降低集成断裂，提供一个小版本周期（例如 0.1.x）别名支持：`acceptBySig`（→ `settleWithSigs`）、`PriceSettled`（→ `AmountSettled`）。别名仅作为入口别名（不重复发事件），在 0.2.0 起移除；ABI/SDK 应同时暴露别名与规范名并标注 deprecated；遥测/日志应可区分别名与规范入口（例如记录函数选择器/方法名）。

## 11) 渐进路线图
- T0（MVP）：状态机完整、Pull 结算、不变量与基础指标；
- T1：批量提现、事件驱动自动领取、最小代付（4337/2771）；
- T2：非常规代币适配层与白名单策略、跨域回退工具；
- T3：接口标准化与生态协作，保持“最小内置”。

## 12) 附录（追溯矩阵）
风格说明：本节“转换箭头”的规范写法为 ASCII `->`；如渲染为 Unicode 箭头（→），视为等价显示，不改变含义。
信息性示例（Trace）：
 - Trace.1：E4（Executing->Settled，approveReceipt） -> API: `approveReceipt` -> INV.1 -> EVT: `Settled` -> MET: 结清延迟/资金滞留。
 - Trace.2：E12（Disputing->Settled，settleWithSigs） -> API: `settleWithSigs` -> INV.2 -> EVT: `AmountSettled, Settled` -> MET: 争议时长/协商接受率。
 - Trace.3：E13（Disputing->Forfeited，timeoutForfeit） -> API: `timeoutForfeit` -> EVT: `Forfeited` -> GOV: 没收率/争议时长。
- Trace.4：ForfeitPool 治理提现 -> API: `withdrawForfeit` -> INV.8 -> EVT: `ProtocolFeeWithdrawn` -> GOV: GOV.4（用途审计）。
全量映射（覆盖所有允许的转换；至少一项指标；编号对齐）：
- E1 Initialized->Executing（acceptOrder） -> API: `acceptOrder` -> INV: INV.11 -> EVT: `Accepted` -> MET: MET.5（接单延迟）。
- E2 Initialized->Cancelled（cancel） -> API: `cancelOrder` -> INV: INV.3（退款计算） -> EVT: `Cancelled` -> GOV: GOV.1。
- E3 Executing->Reviewing（markReady） -> API: `markReady` -> INV: INV.11 -> EVT: `ReadyMarked` -> MET: MET.5（执行->评审时延）。
- E4 Executing->Settled（approveReceipt） -> API: `approveReceipt` -> INV.1 -> EVT: `Settled` -> MET: MET.1/MET.3。
 - E5 Executing->Disputing（raiseDispute） -> API: `raiseDispute` -> INV: INV.11 -> EVT: `DisputeRaised` -> MET: MET.5（争议触发时延）。
- E6 Executing->Cancelled（cancel: Client 条件） -> API: `cancelOrder` -> INV: INV.3 -> EVT: `Cancelled` -> GOV: GOV.1。
- E7 Executing->Cancelled（cancel: Contractor） -> API: `cancelOrder` -> INV: INV.3 -> EVT: `Cancelled` -> GOV: GOV.1。
- E8 Reviewing->Settled（approveReceipt） -> API: `approveReceipt` -> INV: INV.1 -> EVT: `Settled` -> MET: MET.1/MET.3。
- E9 Reviewing->Settled（timeoutSettle） -> API: `timeoutSettle` -> INV: INV.1 -> EVT: `Settled` -> MET: MET.1。
 - E10 Reviewing->Disputing（raiseDispute） -> API: `raiseDispute` -> INV: INV.11 -> EVT: `DisputeRaised` -> MET: MET.5（争议触发时延）。
- E11 Reviewing->Cancelled（cancel: Contractor） -> API: `cancelOrder` -> INV: INV.3 -> EVT: `Cancelled` -> GOV: GOV.1。
- E12 Disputing->Settled（settleWithSigs） -> API: `settleWithSigs` -> INV: INV.2 -> EVT: `AmountSettled, Settled` -> MET: MET.4（协商接受率）。
- E13 Disputing->Forfeited（timeoutForfeit） -> API: `timeoutForfeit` -> INV: INV.8 -> EVT: `Forfeited` -> GOV: GOV.1/GOV.3（争议时长）。


---
