# A2A 无仲裁托管结算协议（NESP）白皮书
副题：无信任 · 限时争议 · 对称没收威慑

## 版本说明
- 本白皮书为独立、可判定、可复现的完整文档；正文内自洽给出全部定义、判据与口径，不依赖外部引用。
- 本白皮书即为唯一规范性文档（唯一语义源），包含完整的规则、接口与指标口径。
## 1. 摘要
就像互联网的演化一样，唯有“自由创建（无审计）、自由发布（无预审）、自由交易（无许可）”，生态才会自发涌现并持续扩张。然而完全自由也可能滑向“劣币驱逐良币”的黑暗森林。为避免从自由坠入无序，需要设计一套A2A（Agent‑to‑Agent）的代理结算底座，其核心要求是：无仲裁，且能协作自促进。所谓无仲裁，是指结算层不设中心化裁判，不做价值判断与平台裁量，保持可信中立的制度承诺；所谓协作自促进，是指在不引入裁量的前提下，使理性的合作与妥协成为参与者自己的最优选择，从博弈结构上使得拖延、敲诈和欺骗的边际收益为零，甚至是亏损。

NESP 正是这样的底座：**链下协商，链上约束；以对称没收威慑为核心，促进链下最大限度合作与妥协的交易结算协议，并保持协议层的可持续发展。**

### 0.1 核心流程（快速导览，非规范）
- Step 1 托管：买方把应付款先存入托管账户（E）。
- Step 2 交付：卖方接单并完成交付/发货。
- Step 3 验收放款（无争议）：买方验收通过，托管款一次性全额打给卖方（E）。
- Step 4 发起争议（如有）：在限定时间内提出分歧。
- Step 5 限时协商：双方在争议期内商定付款数额 A（A≤E）→ 按 A 付款，剩余返还买方。
- Step 6 超时威慑：若超时仍未达成一致，则对称没收这笔托管款（双方都拿不到，划入 ForfeitPool，罚没资产默认沉淀于协议，可由治理模块提取用于协议费用；其他用途须经社区决议授权）。详见第 6 章“治理接口”。
说明：本小节为导览，规范性口径以第 3–6 章（状态机/不变量/安全/接口与事件）为准；本节中的“口径锚点”仅为阅读帮助，不构成规范条文。

## 1. 设计原则（Principles）

### 1.1 最小内置（Minimal Enshrinement）
- 约束：结算内核不承载裁量与价值判断，不引入仲裁/表决/再质押依赖；链上仅保存可验证的最小集合：状态（订单流转）、金额口径（A≤E，E 单调不减）、可被外界承认的触发信号，以及公开可验证的时钟/窗口。
- 边界：上层的身份/信誉/拍卖/任务分配/使命型机制在应用层实现；若使用账户抽象/可信转发（AA/2771/4337），仅作调用通道，不得改变金额/时间/事件口径。
- 禁止项：把“谁对谁错”的裁量写入合约、以治理投票决定结算结果等。

### 1.2 可信中立（Credible Neutrality）
- 约束：确定性时间窗、对称规则、开放事件；任意第三方可重放审计。
- 证据：公开统一金额/时间口径与最小事件字段，保证“别人不必相信我们，但可以检验我们”。

### 1.3 可验证与可重放（Verifiable & Replayable）
- 最小证据集：
  - 签名承诺：采用结构化签名，域至少包含 {orderId, tokenAddr, amount, chainId, nonce, deadline}，防跨单/跨链/重放；合约/域错/过期均为统一回滚路径。
  - 金额与会计：E 单调不减、A≤E；
  - 触发器族：定义“不可达一致”的可验证触发信号（限时只是其一；亦可包含签名缺席/矛盾、最低可验证性失败、握手破裂等）；
  - 时钟与窗口：统一时间口径与到期判定，任何人可据此重放路径与结果。

### 1.4 与 A2A 生命周期的对接（Lifecycle Alignment）
- 原则：结算适配不改变 A2A 的消息语义；提供清晰的“消息→结算动作”映射与“结算事件→会话回填”路径，使会话/线程与订单上下文同源一致。
- 调用路径：默认支持直连；若部署选择代付/转发（AA/2771/4337），应记录 `via` 以便审计与归因，同时保持结算语义不变。

### 1.5 分阶段开放与门槛治理（Phased Opening）
- 门槛：以统一参数表 {W, θ, β, τ} 设定阶段验收与运行门槛（窗口、没收率上限、协商接受率下限、P95 结清上限），并版本化管理。
- 动作：额度/清算/缓冲/熔断等运营动作位于应用层执行，内核不变。
- 目标：随着渗透提升，保持可判定/可复现/可对照与可回退，避免规模外溢把系统推回裁量与黑箱。

## 2. 模型与记号（A ≤ E 口径）

### 2.1 参与者与信息结构
- 参与者：Client（买方）、Contractor（卖方）。
- 系统角色：治理模块（Governance）。不驱动订单状态机，不改变结算不变量。
- 公开信息：状态、时间戳、托管额 E、事件与日志；
- 私人信息：V（买方价值）、C（卖方成本）、质量主观信号。

### 2.2 时间与计时器
- 绝对锚点：`startTime, readyAt, disputeStart`（一次性设置后不可回拨）；
- 相对窗口：`D_due, D_rev, D_dis`（单位秒；`D_due/D_rev` 允许“单调延后”，`D_dis` 固定且不可延长）。

### 2.3 金额与单位
- `E`（托管额）：单调不减、不可减少，仅经 `depositEscrow` 增加；
- `A`（实际结清额）：0 ≤ A ≤ E（以结清时刻的 E 计）；
- 单位与时间：金额以 token 最小单位计价；时间以 `block.timestamp`（秒）。

### 2.4 术语与符号（信息性）
- `V`：买方价值；`C`：卖方成本；
- `κ(t)`：可用性/状态系数（Executing∈[0,1]；Reviewing/Disputing=1）；
- `R(t)`/`I(t)`：卖方/买方的机会收益/沉没成本项。

### 2.5 资产与代币
- `tokenAddr` 表示资产标识（ERC‑20 或“原生 ETH”哨兵）；
- ETH 资产：充值入口为 `payable`，MUST 满足 `msg.value == amount`；提现使用 `call` 且 `nonReentrant`；
- ERC‑20：`msg.value == 0`，使用 `SafeERC20.safeTransferFrom(...)` 成功后记账；
- 建议：支持“WETH 适配层”作为工程选项，但规范层必须支持原生 ETH。

### 2.6 参数协商与范围（规范）
- 协商主体与生效时点：`E`、`D_due`、`D_rev`、`D_dis` 由 Client 与 Contractor 针对“每一笔订单”达成一致；实现必须在订单建立/接受时固化存储。订单可固化手续费策略 `feeHook` 与上下文哈希 `feeCtxHash`（创建即锁定，不可修改）；允许 `feeHook = address(0)` 表示不计费。
- 默认值：若 `dueSec/revSec/disSec` 传入 0，则采用协议默认 `D_due=1d=86_400s`、`D_rev=1d=86_400s`、`D_dis=7d=604_800s`；入库与事件需记录替换后的“生效值”。
- 修改规则：`E` 仅可单调增加；`D_due/D_rev` 仅允许在争议发生前单调延后；`D_dis` 自设置后固定，不提供延长入口。
- 有界性：三者必须为有限值且大于 0；为抵御重组，`D_dis ≥ 2·T_reorg`（由部署方按目标链给出估计）。
- 零值约定：仅在创建入口可传入 0 表示“采用默认值”，其余接口与持久化字段不得为 0。

### 2.7 “不可达一致”触发器（规范与信息性）
- 规范性触发器（唯一）：限时到期。WHAT：当 `state=Disputing` 且 `now ≥ disputeStart + D_dis` 时，允许 `timeoutForfeit` 将状态置为 `Forfeited`。
- 信息性/可选触发器（非规范）：签名缺席/矛盾、最低可验证性失败、握手破裂等，可用于产品层诊断或外部治理，不进入合约守卫；其动作与罚则不在本规范内定义。
  强提醒：上述信息性触发器仅用于分析/诊断，不进入任何合约守卫或状态转换判据。

## 3. 状态机与守卫

### 3.1 允许的转换（除此之外无其他）
- E1 Initialized -acceptOrder-> Executing（发起：contractor）
- E2 Initialized -cancelOrder-> Cancelled（发起：client/contractor）
- E3 Executing -markReady-> Reviewing（发起：contractor）
- E4 Executing -approveReceipt-> Settled（发起：client）
- E5 Executing -raiseDispute-> Disputing（发起：client/contractor）
- E6 Executing -cancelOrder-> Cancelled（发起：client）
- E7 Executing -cancelOrder-> Cancelled（发起：contractor）
- E8 Reviewing -approveReceipt-> Settled（发起：client）
- E9 Reviewing -timeoutSettle-> Settled（发起：任意）
- E10 Reviewing -raiseDispute-> Disputing（发起：client/contractor）
- E11 Reviewing -cancelOrder-> Cancelled（发起：contractor）
- E12 Disputing -settleWithSigs-> Settled（发起：对手方（client 或 contractor 之一））
- E13 Disputing -timeoutForfeit-> Forfeited（发起：任意）

### 3.2 状态不变动作（SIA）
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
  - Condition：`amount > 0`；`state ∈ {Initialized, Executing, Reviewing}`；订单资产为 ETH 时 MUST `msg.value == amount`，为 ERC‑20 时 MUST `msg.value == 0` 且 `SafeERC20.safeTransferFrom(subject, this, amount)` 成功。
  - Subject：
    - 受信路径（2771/4337）：解析出的 `subject` MUST 等于 `client`；
    - 非受信路径直连 EOA：视为自担没收风险的赠与方，需自行完成代币转移授权；
    - 非受信合约调用：MUST `revert`（`ErrUnauthorized`），遵循 §6.3 的授权与来源规则。
  - Effects：`escrow ← escrow + amount`（单调增加），触发 `EscrowDeposited`。
  - Failure：
    - `state ∈ {Disputing, Settled, Forfeited, Cancelled}` MUST `revert`（`ErrFrozen` 或 `ErrInvalidState`）；
    - 主体不符 MUST `revert`（`ErrUnauthorized`）；
    - 资产/转账校验失败 MUST `revert`（`ErrAssetUnsupported` 或等效错误）。

### 3.3 守卫与副作用
- 统一规则（MUST）：每条守卫条目以 `{Condition, Subject, Effects, Failure}` 描述；未列出的入口与路径一律视为禁止。
- 参数持久化（MUST）：在订单建立/接受时固化存储 `D_due/D_rev/D_dis` 的实际值；不得依赖“隐式默认”。
- 锚点一次性（MUST）：`startTime/readyAt/disputeStart` 仅允许“未设置→设置一次”，不得回拨或覆写。
- 调用主体解析（Resolved Subject）：
  - 直连：`subject = msg.sender`，`via = address(0)`；
  - 2771：若 `isTrustedForwarder(msg.sender)=true`，`subject = _msgSender()`；
  - 4337：若 `msg.sender == EntryPoint`，`subject = userOp.sender`。
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
    - Effects：结清金额 `amountToSeller = escrow`，与后续 `BalanceCredited（kind=Payout/Refund/Fee）` 记账，订单 `escrow` 清零，状态转入 Settled。
    - Failure：条件未满足 MUST `revert`。
  - G.E5 `raiseDispute`（执行阶段）：
    - Condition：`state = Executing` 且 `now < startTime + D_due`。
    - Subject：`client` 或 `contractor`。
    - Effects：状态转入 Disputing，设置 `disputeStart = now`，托管额 E 冻结（拒绝后续充值）。
    - Failure：条件未满足 MUST `revert`。
  - G.E10 `raiseDispute`（评审阶段）：
    - Condition：`state = Reviewing` 且 `now < readyAt + D_rev`。
    - Subject：`client` 或 `contractor`。
    - Effects：状态转入 Disputing，保持 `disputeStart = now`（若首次进入）并冻结托管额。
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
    - Effects：结清金额 `amountToSeller = escrow`，记账至卖方（Payout），订单 `escrow` 清零，状态转入 Settled。
    - Failure：条件未满足 MUST `revert`。
  - G.E11 `cancelOrder`（contractor，评审阶段）：
    - Condition：`state = Reviewing`。
    - Subject：`contractor`。
    - Effects：状态转入 Cancelled；将订单 `escrow` 全额按退款口径记账至买方可提余额（Refund），订单 `escrow` 清零。
    - Failure：条件未满足 MUST `revert`。
  - G.E12 `settleWithSigs`：
    - Condition：`state = Disputing`，`now < disputeStart + D_dis`，`amountToSeller ≤ escrow`，并通过 EIP‑712/1271 签名、`nonce`、`deadline` 校验。
    - Subject：`client` 或 `contractor`。
    - Effects：按签名金额结清（`amountToSeller = A`），分别记账至卖方（Payout=A）与买方退款（Refund=escrow−A），订单 `escrow` 清零，状态转入 Settled。
    - Failure：条件未满足 MUST `revert`（`ErrBadSig/ErrReplay/ErrExpired/ErrOverEscrow` 等）。
  - G.E13 `timeoutForfeit`：
    - Condition：`state = Disputing` 且 `now ≥ disputeStart + D_dis`。
    - Subject：任意地址。
    - Effects：状态转入 Forfeited，订单 `escrow` 全额计入 ForfeitPool（增加 `forfeitBalance[tokenAddr]`），订单 `escrow` 清零；罚没资产继续由治理模块托管，可在满足授权条件时提取。
    - Failure：条件未满足 MUST `revert`。

### 3.4 终态约束
- `Settled/Forfeited/Cancelled` 为终态；到达终态后不得再改变状态或资金记账；仅允许提现入口读取并领取既有可领额（若有）。
- 终态资金口径：到达任一终态时，订单 `escrow` MUST 置为 0，并按终态路径完成记账：
  - Settled：记账三笔：
    - 卖方 Payout：`payoutToSeller = amountToSeller − fee`（`0 ≤ fee ≤ amountToSeller`）；
    - 买方 Refund：`refundToBuyer = escrow − amountToSeller`；
    - 手续费 Fee：`fee` 记入手续费受益地址（由手续费策略计算/返回）；
    金额为 0 的 `Fee` 记账可省略事件；
  - Forfeited：将原订单 `escrow` 全额计入 `forfeitBalance[tokenAddr]`（罚没），不记入任何用户余额。
  - Cancelled：将原订单 `escrow` 全额记入买方可提余额（Refund）。
- 注：治理提款不属于用户提现路径；不改变订单维度的记账与聚合可提余额；不触发 `Balance{Credited,Withdrawn}` 事件；可在满足授权条件时独立执行。

## 4. 结算与不变量（Pull 语义）

### 4.1 金额计算
- INV.1 全额结清：`amountToSeller = escrow`（approve/timeout）。
- INV.2 金额型结清：`amountToSeller = A` 且 `0 ≤ A ≤ escrow`（签名协商）。
- INV.3 退款：`refundToBuyer = escrow − amountToSeller`（若 A < escrow）。
- INV.14 平台费（服务商）：当订单处于 Settled 终态时，若已固化 `provider, feeBps`，则按 `fee = floor(amountToSeller * feeBps / 10_000)` 计入服务商可提余额；必须满足 `0 ≤ fee ≤ amountToSeller`，且守恒成立：`(amountToSeller − fee) + (escrow − amountToSeller) + fee = escrow`。Cancelled/Forfeited 不产生平台费。
  - 注：当 `provider = address(0)` 或 `feeBps = 0` 时，`fee = 0`，不产生 `kind=Fee` 的记账与事件（仍满足守恒式）。

### 4.2 资金安全
- INV.4 单次入账：每单至多一次将结清额/退款额入账至聚合余额（single_credit），防止重复计入可提余额。
- INV.5 幂等提现：提现前先读取并清零聚合余额，转账成功即完成；重复调用无可提余额，返回无副作用。
- INV.6 入口前抢占：外部入口先处理 `timeout*`，防延迟攻击。
  - 审计判据：当入口被调用时，若超时条件已满足（例如 `now ≥ readyAt + D_rev` 或 `now ≥ disputeStart + D_dis`），应优先导致对应的 `timeoutSettle/timeoutForfeit` 结果或返回超期错误；若未发生优先处理，视为违反本不变量。
- INV.7 资产与对账：SafeERC20 + 余额差核验；对“费率/重基/非标准”代币如无法保证恒等对账，MUST `revert`（ErrAssetUnsupported）。

（信息性）非标准 ERC‑20 对账伪代码
```
function _safeTransferIn(token, subject, amount) internal {
    uint256 pre = IERC20(token).balanceOf(address(this));
    SafeERC20.safeTransferFrom(IERC20(token), subject, address(this), amount);
    uint256 post = IERC20(token).balanceOf(address(this));
    if (post - pre != amount) revert ErrAssetUnsupported();
}
```
注：对 fee‑on‑transfer/rebase/可冻结/可暂停等资产，若无法满足“余额差==amount”的恒等式，应显式失败。

### 4.3 资金去向与兼容
- INV.8 没收去向与治理提款（规范）：
  - 路径与归集：`escrow → ForfeitPool`；ForfeitPool 为合约内逻辑账户，罚没资产默认留存于合约余额。
  - 治理外流（唯一）：罚没资产仅能在满足治理授权（协议运营费用或经社区决议批准的其他用途）时，由治理模块通过治理提款入口转出（见第 6 章）。
  - 记账不变量：维护 `forfeitBalance[tokenAddr]`；Forfeited 时按 `tokenAddr` 与金额增加；治理提款时相应减少；MUST 满足 `forfeitBalance[tokenAddr] ≥ 0`。
  - 分离与隔离：治理提款不影响任何订单维度的 `owed/refund` 与聚合可提余额，不触发 `Balance{Credited,Withdrawn}`。
  - 资产一致性：ETH 与 ERC‑20 采用一致语义与余额差核验。
  - 审计判据：分 `tokenAddr` 比对全量资金恒等式：
    `合约资产余额 = Σ 未终态订单 escrow + Σ 用户聚合可提余额 + forfeitBalance`；
    其中“未终态订单”指 `state ∈ {Initialized, Executing, Reviewing, Disputing}` 的订单集合；
    对治理提款，验证“`forfeitBalance` 减少量 == 实际转出量”，且无用户余额外流事件。
- INV.9 比例路径兼容（可选）：`amountToSeller = floor(escrow * num / den)`；余数全部计入买方退款。实现需使用安全“mulDiv 向下取整”或等效无溢出实现；任何溢出/下溢必须回滚；禁止四舍五入与提精度。
- INV.10 Pull 语义：状态变更仅“记账可领额”（聚合到 `balance[token][addr]`），实际转账仅在 `withdraw(token)` 发生；禁止在状态变更入口直接 `transfer`。适用范围：仅针对订单参与者路径（创建/受理/交付/争议/结清/取消/用户提现）；治理提款为系统级外流，不属于用户 `withdraw(token)`，不受本条限制，但须同时满足 §4.3 INV.8 与 §6（治理接口/授权/CEI/重入防护）的约束。
- INV.11 锚点一次性：`startTime/readyAt/disputeStart` 一旦设置，MUST NOT 修改或回拨。
- INV.12 计时器规则：`D_due/D_rev` 仅允许延后（单调增加，且在进入 Disputing 前）；`D_dis` 固定且不可延长。
- INV.13 唯一机制：无争议路径必须全额结清；争议路径采用签名金额结清；金额口径始终满足 `A ≤ E`，链上仅记录托管与结清。
#### 审计提示（信息性）
- HOW（≤3）：
  1) 对没收路径：按 `tokenAddr` 分组比对“`forfeitBalance` 增量 = Σ(Forfeited.amount)”且对应订单 `escrow` 清零；该订单维度随后无 `BalanceCredited/BalanceWithdrawn` 外流；
  2) 核对订单维度的 `owed/refund` 清零；
  3) 对 ETH 与 ERC‑20 采用一致口径（余额差 + 事件）。
- WHAT：罚没资产默认留存于合约，通过治理提款为唯一外流路径（见 §6 治理接口）；不允许除治理提款外的任何外部分配或销毁。

## 5. 安全与威胁模型

### 5.1 签名与重放
- 采用 EIP‑712/1271；签名域至少包含 `{chainId, contract, orderId, tokenAddr, amountToSeller(=A), proposer, acceptor, nonce, deadline}`。
- `amountToSeller ≤ E`；`nonce` 的作用域至少为 `{orderId, signer}` 且一次性消费；`deadline` 基于 `block.timestamp` 判定。
- 必须防止跨订单/跨合约/跨链重放。

（信息性）EIP‑712 TypedData 样例（摘录）
```
{
  "types": {
    "EIP712Domain": [
      {"name":"name","type":"string"},
      {"name":"version","type":"string"},
      {"name":"chainId","type":"uint256"},
      {"name":"verifyingContract","type":"address"}
    ],
    "Settlement": [
      {"name":"orderId","type":"uint256"},
      {"name":"tokenAddr","type":"address"},
      {"name":"amountToSeller","type":"uint256"},
      {"name":"proposer","type":"address"},
      {"name":"acceptor","type":"address"},
      {"name":"nonce","type":"uint256"},
      {"name":"deadline","type":"uint256"}
    ]
  },
  "primaryType": "Settlement",
  "domain": {
    "name": "NESP",
    "version": "1",
    "chainId": 1,
    "verifyingContract": "0x0000000000000000000000000000000000000000"
  },
  "message": {
    "orderId": 1,
    "tokenAddr": "0x0000000000000000000000000000000000000000",
    "amountToSeller": 1000000,
    "proposer": "0x0000000000000000000000000000000000000001",
    "acceptor": "0x0000000000000000000000000000000000000002",
    "nonce": 7,
    "deadline": 1924992000
  }
}
```

### 5.2 错误映射（统一）（命名示例化，允许等价错误名）
- `ErrInvalidState`、`ErrExpired`、`ErrBadSig`、`ErrOverEscrow`、`ErrFrozen`、`ErrAssetUnsupported`、`ErrReplay`、`ErrUnauthorized`。

### 5.3 交互顺序与重入
- 提现（含治理提款）`nonReentrant`，遵循 CEI；优先处理 `timeout*` 入口；提现使用 `call` 并检查返回。
- CEI 范围（规范）：除提现与 ERC‑20 `transferFrom` 外，所有状态变更入口禁止直接向外部地址转账或调用外部不受信任合约；所有状态变更入口均遵循“先校验、再记账、后交互”的顺序。

### 5.4 时间边界与残余风险
- 统一区块时间；`D_due/D_rev` 仅允许延后（单调），`D_dis` 固定且不可延长。
- 残余风险：破坏型对手导致的没收外部性 → 由社会层资质/信誉/稽核约束与运营护栏缓解。
 - 绑定（观测→动作）：当观测到异常模式（如没收率异常升高、协商接受率显著下降）时，按 §7.2 的 `SLO_T(W)` 判据与 CHG:SLO-Runbook 执行停写/白名单/回滚等动作。

## 6. API 与事件（最小充分集）
（统一说明）错误命名在本章为“示例化”（如 `ErrXxx`），部署可采用等价错误名，但须保持语义、守卫与回滚路径一致。

-### 6.1 函数（最小集）
- `createOrder(tokenAddr, contractor, dueSec, revSec, disSec, provider, feeBps) -> orderId`：创建订单，固化资产与时间锚点、服务商与费率；允许 `provider = address(0)` 表示不计费，此时 `feeBps MUST = 0`；当 `provider ≠ 0` 时，`provider` MUST 在白名单内，且 `feeBps MUST == providerFeeBps[provider]` 并满足 `0 ≤ feeBps ≤ 10_000`（若配置了全局上限 `bpsMax`：还需 `feeBps ≤ bpsMax`）；固化后不得修改。
- `createOrder(...)` 触发事件：`OrderCreated`。
- `createAndDeposit(tokenAddr, contractor, dueSec, revSec, disSec, provider, feeBps, amount)`（payable） ：创建并立即充值指定金额（ETH：`msg.value == amount`；ERC‑20：`SafeERC20.safeTransferFrom(subject, this, amount)`）；`provider/feeBps` 守卫与 `createOrder` 一致；允许 `provider = address(0)` 且 `feeBps = 0`。
- `createAndDeposit(...)` 触发事件：`OrderCreated`、`EscrowDeposited`（同一交易）。
- `depositEscrow(orderId, amount)`（payable）：补充托管额，允许 client 或第三方赠与；入口遵守资产与冻结守卫。触发事件：`EscrowDeposited`。
- `acceptOrder(orderId)`：承接订单，需 `subject == contractor`，并设置 `startTime`。触发事件：`Accepted`。
- `markReady(orderId)`：卖方声明交付就绪，仅 `subject == contractor`，设置 `readyAt` 并启动评审窗口。触发事件：`ReadyMarked`。
- `approveReceipt(orderId)`：买方验证交付并触发结清（`subject == client`）。触发事件：`Settled(actor=Client)` 与后续 `BalanceCredited（kind=Payout/Refund/Fee）` 记账。
- `timeoutSettle(orderId)`：在评审超时后由任意主体触发全额结清。触发事件：`Settled(actor=Timeout)` 与后续 `BalanceCredited（kind=Payout/Refund/Fee）` 记账。
- `raiseDispute(orderId)`：进入争议状态，`subject ∈ {client, contractor}`，记录 `disputeStart`。触发事件：`DisputeRaised`。
- `settleWithSigs(orderId, payload, sig1, sig2)`：争议期内按签名报文结清金额 A（守卫 `A ≤ escrow`）。触发事件：`AmountSettled` 与后续 `BalanceCredited（kind=Payout/Refund/Fee）` 记账（终态为 `Settled`）。
- `timeoutForfeit(orderId)`：争议超时由任意主体触发对称没收。触发事件：`Forfeited(orderId, tokenAddr, amount)`。
- `cancelOrder(orderId)`：根据守卫（G.E6/G.E7/G.E11）由 client 或 contractor 取消订单。触发事件：`Cancelled`，与后续 `BalanceCredited（kind=Refund）` 记账。
- `withdraw(tokenAddr)`：提取累计收益或退款（Pull 语义，`nonReentrant`）；成功时触发 `BalanceWithdrawn` 事件。
 - （治理接口）`withdrawForfeit(tokenAddr, to, amount)`：治理提款，将 ForfeitPool 中的罚没资产转出用于协议费用或经社区决议授权的其他用途。
   - Condition：`onlyGovernance`；`amount > 0`；`forfeitBalance[tokenAddr] ≥ amount`。
   - Subject：治理模块地址。
   - Effects：`forfeitBalance[tokenAddr] -= amount`；将资产转给 `to`；ETH 使用 `call{value:amount}`，ERC‑20 使用 `SafeERC20.safeTransfer`。
   - Failure：MUST `revert`（`ErrUnauthorized/ErrAmountZero/ErrInsufficientForfeit` 等）。上述错误命名为示例，实施可采用等价错误名，但语义与守卫必须一致。
- `commitEvidence(orderId, EvidenceCommitment)`：提交指定阶段的证据指纹；仅限订单参与者调用，可多次提交补充材料。触发事件：`EvidenceCommitted`。
- `getOrder(orderId) view`：只读查询并返回 `{client, contractor, tokenAddr, state, escrow, dueSec, revSec, disSec, startTime, readyAt, disputeStart, feeHook, feeCtxHash}`（`feeCtxHash` 为手续费策略上下文的哈希；原始 `feeCtx` 由链下保存，用于审计重放）。
- `withdrawableOf(tokenAddr, account) view`：读取聚合可提余额（涵盖 Payout/Refund/Fee），便于钱包等组件展示与核对。
- `extendDue(orderId, newDueSec)`：client 单调延长履约窗口。触发事件：`DueExtended`（记录 old/new）。
- `extendReview(orderId, newRevSec)`：contractor 单调延长评审窗口。触发事件：`ReviewExtended`（记录 old/new）。

### 6.2 事件（最小字段）
- `OrderCreated(orderId, client, contractor, tokenAddr, dueSec, revSec, disSec, feeHook, feeCtxHash)`：订单建立时触发，固化角色、时间参数与手续费策略（`feeHook` 可为 `address(0)`；`feeCtxHash` 仅存哈希）。事件的 `block.timestamp` 视为 `startTime` 候选锚点。
- `EscrowDeposited(orderId, from, amount, newEscrow, via)`：托管额充值成功后触发，记录充值来源与调用通道；未启用受信路径时 `via = address(0)`。
- `Accepted(orderId, escrow)`：承接订单（进入 Executing）时触发，确认当前托管额；`block.timestamp` 可作为 `startTime` 实际值校验。
- `ReadyMarked(orderId, readyAt)`：卖方标记交付就绪时触发（进入 Reviewing），固化 `readyAt` 锚点。
- `DisputeRaised(orderId, by)`：进入争议状态时触发，记录争议发起方。
- `DueExtended(orderId, oldDueSec, newDueSec, actor)`：买方延长履约窗口时触发（单调增加，`actor == client`）。
- `ReviewExtended(orderId, oldRevSec, newRevSec, actor)`：卖方延长评审窗口时触发（单调增加，`actor == contractor`）。
- `Settled(orderId, amountToSeller, escrow, actor)`（`actor ∈ {Client, Timeout}`）：无争议或评审超时结清时触发；其中 `escrow` 指结清时刻的 E（订单变更前的托管额，用于计算 `Refund = escrow − amountToSeller`）；与后续 `BalanceCredited（kind=Payout/Refund/Fee）` 记账（`kind=Fee` 金额为 0 时可不发事件）。
- `AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce)`：双方签名协商金额 A 后触发；与后续 `BalanceCredited（kind=Payout/Refund/Fee）` 记账（终态为 `Settled`）。
- `AssetUnsupported(orderId, tokenAddr)`（可选）：适配层或预检流程判定资产不受支持且事务成功返回时触发；若主流程以 `ErrAssetUnsupported` 回滚则不发该事件。
- `Forfeited(orderId, tokenAddr, amount)`：争议期超时被没收时触发；记录资产与没收金额（用于分资产对账与统计）。其中 `amount` 指没收时刻订单托管额（订单变更前的 E）。
- `Cancelled(orderId, cancelledBy)`（`cancelledBy ∈ {Client, Contractor}`）：订单被取消时触发；与后续 `BalanceCredited（kind=Refund）` 记账。
- `BalanceCredited(orderId, to, tokenAddr, amount, kind)`（`kind ∈ {Payout, Refund, Fee}`）：结清/退款/平台费记账到可提余额时触发（`kind=Fee` 的金额为 0 时可不发事件）。
- `BalanceWithdrawn(to, tokenAddr, amount)`：用户提现成功时触发。
 - `ProtocolFeeWithdrawn(tokenAddr, to, amount, actor)`：治理提款成功时触发；`actor` 为治理调用者。
- `EvidenceCommitted(orderId, status, address actor, EvidenceCommitment evc)`：提交证据时触发；`status` 直接使用订单当前状态值（Initialized/Executing/Reviewing/Disputing/Settled/Forfeited），`actor` 等于解析后 `subject`。字段边界见 §6.4 数据结构。
- 说明：事件不携带显式 `ts` 字段，默认以日志对应区块的 `block.timestamp` 作为时间锚点。

### 6.3 授权与来源（可选受信路径）
- 默认情形 `EscrowDeposited.via = address(0)`，表示直接调用（`msg.sender == tx.origin`）。若部署开启受信路径（如 2771 转发或 4337 EntryPoint），`via` 记录该受信合约地址。
- 需提前登记受信转发器/EntryPoint，并在链上校验：2771 模式下 `isTrustedForwarder(via)=true`；4337 模式下 `via` 必须等于配置的 `EntryPoint`。
- 其他合约调用 MUST `revert`（ErrUnauthorized）。不支持多重转发/嵌套；检测到多跳 MUST `revert`。授权失败为回滚路径，不发 `EscrowDeposited` 事件。

#### 定义与可观测锚点（补充，不改变语义）
- “多跳（multi‑hop）”界定：在同一笔调用中，经由多个转发/中继合约层层转发至本合约的情形（除受信任的 `forwarder` 或配置的 `EntryPoint` 之外的额外一跳及以上），均视为“多跳”。
- 判定口径：若 `msg.sender` 为合约地址，且既不是受信任的 `forwarder` 也不是配置的 `EntryPoint`，则视为未授权；若检测到“多跳”链路，MUST `revert`（`ErrUnauthorized`）。
- 可选工件（建议）：
  - 自定义错误签名：`ErrUnauthorized()`（或 `ErrUnauthorized(address caller, address via)`）；
  - 事件主题示例：`EscrowDeposited(uint256 orderId, address from, uint256 amount, uint256 newEscrow, address via)` 的主题 `keccak256` 值；外部审计据此核对“未发事件”。

（治理接口调用来源说明，补充，不改变语义）
- 治理接口（如 `withdrawForfeit`）不适用本节“受信路径”规则；必须由治理主体地址直接调用（判定口径：`msg.sender == governance`；若治理主体为合约，任何以该合约地址为 `msg.sender` 的内部模块/代理/委托调用均视为直接调用）；检测到经由未授权的转发/多跳调用时 MUST `revert`（`ErrUnauthorized`）。

### 6.4 证据承诺（Evidence Commitments）
- 目标：在不改变结算主流程的前提下，为关键阶段提供可验证的离链证据指纹，支持审计与 SLO 观测。
- 数据结构：`EvidenceCommitment = {hash (bytes32), uri (≤256 字节), alg (string, ≤32 字节, ASCII)}`；`alg` 建议填入内容寻址或强哈希算法名称（如 `ipfs-cid`、`sha256`、`keccak256`）；合约不对 `alg` 作语义校验，仅作为外部消费的提示性字段。
- 接口：`commitEvidence(orderId, evc)`；
  - 守卫规范（与 §3.3 体例一致）：
    - Condition：`orderId` 存在；`evc.uri.length ≤ 256`；`evc.alg.length ≤ 32`；
    - Subject：解析后的 `subject ∈ {client, contractor}`（按 §3.3“调用主体解析”：直连/2771/4337）。
    - Effects：读取订单当前状态值填入事件 `status`；触发 `EvidenceCommitted(orderId, status, actor=subject, evc)`；不改变任何订单/余额字段。
    - Failure：条件未满足 MUST `revert`（如 `ErrNotParticipant/ErrUriTooLong/ErrAlgTooLong` 等；错误命名为示例）。
- 建议：
  1. 优先使用内容寻址 URI（`ipfs://CIDv1` / `ar://TXID`）；若使用 `https://` 等位置式 URL，必须同时提交强哈希。
  2. Manifest 建议遵循 `nesp-evc-1.0`（JCS 规范化后取哈希），可扩展 `merkleRoot` 与 `encryption` 字段以支持大包或隐私场景（信息性/可选；不计入规范评审与合规性）。
  3. 单次调用仅提交 1 条承诺；如需补充，可多次调用，外部可依据 `block.timestamp` / `block.number` / `hash` 判定最新记录。应校验 `uri` 长度与字符集，防止滥用。
  4. 一线应用或离线服务可在 `acceptOrder/markReady/settleWithSigs/timeout*` 等关键动作后提醒参与者调用本接口，主合约不得替代参与者提交。
  5. SDK/CLI 可提供“生成 Manifest → 规范化 → 计算哈希 → 上传 → 调用 `commitEvidence`”的一键流程，降低人工差错。
  6. 运维应监控 `EvidenceCommitted` 事件，缺失或延迟时在 Runbook 中执行补交或告警流程。

## 7. 可观测性与 SLO（公共审计）

### 7.1 指标（定义/单位/窗口）
- MET.1 结清延迟 P95、超时触发率。
- MET.2 提现失败率、重试率。
- MET.3 资金滞留余额。
- MET.4 协商接受率 = `#AmountSettled / #DisputeRaised`（每单仅计首个 `AmountSettled`）。
- MET.5 状态转换延迟/吞吐（E1/E3/E5/E10 等非终态转换的时延与速率）。
- GOV.1 终态分布（成功/没收/取消）。
- GOV.2 `A/E` 基线分布（以进入 Reviewing/Disputing 时的 E 为基线）。
- GOV.3 争议时长分布：`DisputeRaised` 与 `Settled/Forfeited` 事件区块时间之间的持续时间（仅对进入 Disputing 的订单），按窗口统计 P50/P95/直方。
- 证据承诺观测：建议将 `EvidenceCommitted` 事件的提交率/延迟纳入 MET.5 衍生指标，并在缺失时触发运维告警。去重口径：提交率按 `orderId` 计首条提交；延迟按每单首条 `EvidenceCommitted` 与对应阶段事件（如 `Accepted/ReadyMarked/DisputeRaised/Settled/Forfeited` 等）之间的时间计算；后续补充提交不重复计数。

（ForfeitPool 可观测性，信息性）
- MET.FP1 ForfeitPool 流入量（系统级，非订单维度去重）：窗口内按 `tokenAddr` 聚合 `Σ(Forfeited.amount)`。
- MET.FP2 ForfeitPool 流出量（系统级，非订单维度去重）：窗口内按 `tokenAddr` 聚合 `Σ(ProtocolFeeWithdrawn.amount)`。
- MET.FP3 ForfeitPool 未提余额（outstanding，系统级，非订单维度去重）：`FP3 = FP1 累计 − FP2 累计`，需与链上 `forfeitBalance[tokenAddr]` 对照一致。

#### 计数与去重规则（口径约束）
- 每单仅一次：`OrderCreated/Accepted/ReadyMarked/DisputeRaised/Settled/AmountSettled/Forfeited/Cancelled`。
- `BalanceCredited`：按 `kind ∈ {Payout, Refund, Fee}` 去重——每单每种 kind 至多 1 次（因此每单最多 3 次：一次给卖方 Payout，一次给买方 Refund，一次给服务商 Fee；`kind=Fee` 金额为 0 时可不发事件）。
- 可重复事件（订单维度）：
  - `EscrowDeposited`（允许多次充值或第三方赠与）
  - `BalanceWithdrawn`（余额领取可多次提取）
  - `DueExtended`、`ReviewExtended`（窗口仅允许单调延长，重复记录前后值轨迹）
 - 系统级事件（非订单维度）：
   - `ProtocolFeeWithdrawn`（治理提款），不计入订单维度的计数与去重。

#### GOV.1 终态分布
- 定义：统计观察窗口内 `Settled/Forfeited/Cancelled` 三类终态的占比。
- 单位/窗口：归一化比例；按 7/30 天滚动窗口或运营指定窗口输出。
- 说明：每笔订单仅记录其首个终态；重复取消/再结清视为异常，应在治理流程中单独标注。

#### GOV.2 `A/E` 基线分布
- 定义：对进入 Reviewing 或 Disputing 时刻的托管额 `E`，记录最终结清额 `A` 与 `E` 之比（`A/E`）。
- 单位/窗口：比例；按 P50/P95/直方等方式统计。
- 说明：当订单被没收时记 `A = 0`；取消订单不计入该指标。

#### GOV.3 争议时长
- 定义：从 `DisputeRaised` 事件区块时间到终态 `Settled/Forfeited` 事件区块时间的持续时间。
- 单位/窗口：秒；按窗口聚合（P50/P95/直方）。
- 说明：Forfeited 与 Settled 均纳入；取消不计。

### 7.2 SLO 与回滚剧本
- 判据：`SLO_T(W) := (forfeit_rate ≤ θ) ∧ (acceptance_rate ≥ β) ∧ (p95_settle ≤ τ)`；`θ/β/τ` 与窗口 `W` 由部署侧在 CHG 定义。
- 动作：超阈触发“切换白名单/停写/回滚”剧本；退出条件模板：若【唯一判据】在窗口 `W` 内持续满足，则执行【停止/退出/回滚】（默认 UTC）。

#### 分析方法（信息性，不进入守卫）
- 单调性检验、分位/秩回归、断点/DiD、离群点告警；用于分析与告警，不改变合约语义。

## 8. 版本化与变更管理

### 8.1 语义版本
- 状态机/不变量/API/指标任一变更 → 次版本以上；破坏性变更 → 主版本。
### 8.2 变更卡（CHG）
- 记录影响面（状态机→接口/事件→不变量→指标链路）、迁移/回滚步骤、兼容窗口。
### 8.3 兼容别名（信息性）
- （预留）为降低集成断裂，可在小版本周期内提供入口别名，明确弃用周期与移除时点。
## 9. 结果与性质（博弈观点，信息性）

### 9.1 定义（R1–R4）
- R1 付款不劣：`E − A ≥ 0`；无争议 A=E；协商 A≤E。
- R2 没收为劣（常见条件）：若 `R(t) < A`，则卖方 `A − R(t) > 0 ≥ −I(t)`；买方 `V−A ≥ −E`。
- R3 均衡路径存在：存在 `A ∈ (C, min(V,E)]` 且 `κ(Review/Dispute)=1` 时，“交付并结清”为子博弈完美均衡路径。
- R4 Top‑up 单调：`E` 单调增加把买方偏好由 `forfeit/tie` 推向 `pay`。

### 9.2 证明草图与观测锚点
- R1：由 INV.1–3 与 `A≤E` 直接得出；观测：`Settled/Balance{Credited,Withdrawn}`。
- R2：对卖方 `A−R(t)` 相对没收 `−I(t)` 优；观测：`GOV.1` 没收率与 `MET.5` 时延分布。
- R3：窗口有界与 `κ=1` 支撑有限步终止；观测：最长时长 ≤ `D_due+D_rev+D_dis` 的路径覆盖。
- R4：`E` 通过 `depositEscrow` 单调增加，协商在 `A ≤ E` 守卫下进行；观测：`GOV.2` 的 `A/E` 分布与 `EscrowDeposited` 曲线。

### 9.3 反例库（信息性）
反例映射（信息性）：
- Ex‑1 → R1；Ex‑2 → R3；Ex‑3 → R4。

## 10. 有效性判据与参数（Effectiveness）

### 10.1 判定谓词
- `Effectiveness(W) := (R1 ∧ R2 ∧ R3 ∧ R4) ∧ SLO_T(W) ∧ Δ_BASELINE(W) ≥ 0`。

### 10.2 统一参数表
- `W`：观测窗口（如 7/14/30 天）
- `θ`：没收率上限（`forfeit_rate ≤ θ`）
- `β`：协商接受率下限（`acceptance_rate ≥ β`）
- `τ`：结清 P95 延迟上限（`p95_settle ≤ τ`）
- `f`：对照加权函数（对 succ/forf/p95/acc 的加权）；上述参数/数据源应记录在 CHG 工件（例如 CHG:SLO-Runbook 或 Effective-Params）中便于版本化。

### 10.3 判定流程
- 先验收 `SLO_T(W)`，再计算 `Δ_BASELINE(W)`，最后核对 R1–R4 的观测证据。
## 11. 基线对照与适用性（Baselines & Applicability）

### 11.1 对照口径（相同窗口/来源/字段）
- `succ = #Settled / (#Settled + #Forfeited + #Cancelled)`
- `forf = #Forfeited / (#Settled + #Forfeited + #Cancelled)`
- `p95_settle`（按指标定义）
- `acc`（按指标定义）
- `Δ_BASELINE(W) = f(succ, forf, p95_settle, acc)_NESP − f(…)_Baseline`

### 11.2 选择指引
- 倾向 NESP：主观性交付/一次性交换，需最小内核/公共审计能力；需要 `A∈[0,E]` 的部分结清与对称威慑；可接受“限时协商 + 对称没收”。
- 倾向中心化托管/仲裁（类外）：复杂证据/强监管/KYC、可接受平台费与裁量。
- 其他：原子交换/客观条件 → HTLC；高频低争议 → 状态通道；投票裁决可接受 → 去中心化仲裁（类外）。
## 12. 工程实现与安全护栏（Engineering & Safety）

### 12.1 最小工程实现清单
- 接口/事件/错误：采用第 6 章最小充分集。
- 签名域绑定：订单/资产/数额/截止/链标识/随机数；跨单/跨链/过期/域错路径测试。
- Pull/CEI/授权/重入：提现前清零、`nonReentrant`、授权校验与来源记录。
- 非标资产：由适配层与白名单策略处理；异常资产路径显式失败。
- 治理提款：实现 `forfeitBalance` 记账、`onlyGovernance` 守卫、CEI 顺序与 `nonReentrant`、ETH/ERC‑20 余额差核验；失败路径返回自定义错误（如 `ErrUnauthorized/ErrInsufficientForfeit`）。
 - 手续费 Hook（结清记账）：
   - 存储：订单固化 `feeHook` 与 `feeCtxHash`（创建即锁定，不可修改；`feeHook=0` 表示不计费）。
   - 调用：结清时以 STATICCALL 调用 Hook 只读计算 `fee` 与受益地址，内核仅记账三笔 `Payout/Refund/Fee` 并清零 `escrow`；`fee=0` 的 `Fee` 事件可省略；Cancelled/Forfeited 不计费。

### 12.2 测试与验证（代表性）
- 代表性用例：
  - 无争议全额/签名金额/超时没收；覆盖 A≤E、计时器边界、Pull/CEI、授权与签名重放。
  - 手续费（FeeHook）结清三笔记账：`Payout=A−fee`、`Refund=E−A`、`Fee=onSettleFee(...)`，且 `escrow=0`、每种 kind≤1。
  - 费率边界：`fee=0`（bps=0）与 `fee` 上限（`bps=bpsMax` 或 10_000）均应通过；签名结清（settleWithSigs）同样计费。
## 13. 分阶段开放与治理（Phased Opening & Governance）

- 渗透度三档（低/中/高）：观测重点、门槛字段（W/θ/β/τ）、开放动作。
- 开桥动作（应用层）：额度/清算/缓冲/熔断等均在应用层实施，不改变合约内核。
- 参数与变更：用版本化记录窗口/阈值/权重与对照数据源；提供变更卡与回退剧本。

## 14. 风险与残余（Risks & Residuals）

- 行为与外溢：破坏型对手、策略波动、协商失败导致的外部性（高没收期）。
- 技术与运行：MEV/排序、非标资产精度/费率、代付路径的授权/来源伪装。
- 缓解与回退：护栏（授权/冻结/时间窗）、SLO 阈值与停写/白名单/回滚动作、审计与复现。

## 15. 运行与对照的变更卡绑定（CHG 必须项）

- Effective-Params：`{ W, θ, β, τ, f, version, updated_at }`
- Baseline-Data：`{ source, fields_map, window=W, version }`
- SLO-Runbook：`{ thresholds_ref, runbook_uri, rollback_steps, contacts }`

## 16. 附录（Appendices）

### 16.1 术语与符号表（选摘）
- `E` 托管额；`A` 结清额；`V` 买方价值；`C` 卖方成本；
- `D_due/D_rev/D_dis` 履约/评审/争议窗口；`startTime/readyAt/disputeStart` 锚点；
- `ForfeitPool` 罚没逻辑账户（默认沉淀；仅治理提款；默认用于协议费用，其他用途须经社区决议）。
 - `Provider` 服务商（第三方服务平台，白名单内）；`feeBps` 费率（bps，1/10_000）；`fee = floor(A*feeBps/10_000)`；`payoutToSeller = A − fee`。

### 16.2 指标与事件口径表（简）
- 事件：`OrderCreated/EscrowDeposited/Accepted/DisputeRaised/Settled/AmountSettled/Forfeited/Cancelled/Balance{Credited(kind=Fee 含在内),Withdrawn}/ProtocolFeeWithdrawn`。

### 16.3 博弈附录：立即妥协的唯一 SPE（信息性）
模型与前提（可检验）
- 争议期有限：存在 `D_dis`；超时未达成一致则进入没收 `Forfeited`，外部选项为买方 `U_b^D = −E`、卖方 `U_s^D = −C`（均严格更差）。
- 出价与可行集：在争议期内交替出价结清额 `A ∈ [0, E]`；买方效用 `U_b(A) = V − A`、卖方效用 `U_s(A) = A − C`，其中 `E ≥ C`、`V ≥ 0`。
- 等待代价（至少其一成立）：
  - 贴现：每期贴现因子 `δ_b, δ_s ∈ (0, 1)`；或
  - 硬截止：有限轮交替出价（最后一轮后即没收）。
- 可用性门控：在达成和解/结清前，买方不能完全、不可逆地实现全部 `V`（例如采用密钥后置/承诺‑揭示/访问令牌等工程手段），避免“先得 V 再谈价”破坏外部选项结构。

命题（唯一 SPE：立即妥协）
- 在上述前提下，交替出价博弈的子博弈完美均衡（SPE）唯一，并在最早可成约时刻达成（“立即妥协”）。

二期模型（逆推示例，显式解）
- 两轮模型：买方先出价（t=0），若拒绝则卖方最后一轮出价（t=1），若仍拒绝则没收（t=2）。
  1) 末轮（t=1）：卖方出价 `A = E`，买方接受（因 `−E < V − E` 对任何 `V ≥ 0` 成立）。卖方的贴现续期价值为 `δ_s · (E − C)`。
  2) 首轮（t=0）：为让卖方“现在接受”而非“等待一轮再提 E”，买方提出使卖方无差异的最小可接受报价：
     `A* = C + δ_s · (E − C)`，且满足 `C < A* < E`（贴现使解落在内点，体现“妥协”）。
  —— 由逆推法可唯一确定每个子博弈的接受阈值，因而均衡路径与 `A*` 唯一，且在 t=0 即达成。

一般情形（有限期/贴现 ⇒ 唯一与即时）
- 有限期限的多轮交替出价：自末轮起逆推得到唯一的接受阈值序列，均衡唯一并在最早可成约时刻达成（即时）。
- 无限期但存在贴现 `δ_b, δ_s ∈ (0, 1)`：Rubinstein 范式给出唯一 SPE，亦为即时达成；NESP 的没收仅改变外部选项值，不破坏“唯一与即时”的结构（参数不同，均衡分配不同）。

何时“不成立”（边界与反例）
- 无贴现且无限期（`δ_b=δ_s=1` 且无截止）：存在多重 SPE，拖延不吃亏，既无唯一性，也无法保证妥协出现在内点。
- 仅有硬截止、无贴现：虽可唯一，但常呈“一边倒”的首轮成交（由最后一轮提案方的威胁值主导），不一定是“妥协”的内点解。
- 买方先得全部 `V`：若在和解前买方已不可逆获得全部价值，其外部选项可能不劣于部分和解，破坏上述不等式与唯一性；工程上需通过可用性门控抑制该情形。

工程映射与参数校准（可操作）
- 有效贴现的现实来源：资本占用机会成本 `r` 与临近到期的失败/审查/拥堵风险 `λ`。可近似 `δ_eff ≈ exp(−(r+λ)·Δt)`（`Δt` 为一轮或决策间隔）。
- 窗口建议：选取 `D_dis` 与通知/缓冲策略，使 `δ_eff < 1` 在观察期内显著成立；避免“无限轮/无等待代价”的交互设计（例如禁止无限频率报价）。
- 可用性门控：采用密钥后置/加密交付/承诺‑揭示等手段，保持未结清前的买方有效收益不至于大于“没收”外部选项。

注与参考（信息性）
- 本附录与 §9“结果与性质（信息性）”一致：当窗口有界且可用性系数 `κ=1` 时，均衡路径有限步终止并偏向迅速达成一致。
- 经典交替出价均衡结构参考 Rubinstein（1982，AER）等；本附录仅给直观骨架，详证可见标准博弈论教材与论文。
- 指标：MET.1/2/3/4/5 与 GOV.1/2/3；窗口/来源版本化（CHG）。

### 16.4 Trace 示意（状态→接口/事件→不变量→指标）
- 示例 0：E3（Executing→Reviewing，markReady） → `ReadyMarked` →（锚点固化）→ GOV.3/时间路径重放。
- 示例 1：E4（Executing→Settled，approveReceipt） → `Settled` → INV.1 → MET.1/MET.3。
- 示例 2：E12（Disputing→Settled，settleWithSigs） → `AmountSettled`（终态 Settled） → INV.2 → MET.4。
- 示例 3：E13（Disputing→Forfeited，timeoutForfeit） → `Forfeited` → INV.8 → GOV.1/GOV.3（争议时长）。

### 16.5 目标与条款对照（WHY→WHAT）

* **无仲裁（最小内置）** → §1.1 禁止裁量清单、§3.1 允许转换清单、§3.3 守卫（Condition/Subject/Effects/Failure）、§6.1 最小函数集
* **协作自促进（对称没收威慑）** → §2.7 "不可达一致"触发器（限时到期）、§4.3 INV.8（罚没资产留存合约）、§9.1 性质 R1–R4、§16.3 唯一 SPE（立即妥协）
* **可信中立** → §1.2 确定性时间窗/对称规则/开放事件、§2.2 时间与计时器、§5.1 签名与重放、§7.1 指标（公共审计）
* **可验证与可重放** → §1.3 最小证据集、§2.3 金额口径（A≤E）、§4.2 不变量 INV.1–13、§6.2 事件（最小字段）
* **A2A 生命周期对接** → §1.4 调用路径、§6.3 授权与来源、§6.4 证据承诺
* **分阶段开放与门槛治理** → §1.5 统一参数表 {W,θ,β,τ}、§10.2 有效性判据、§13 渗透度三档、§15 CHG 绑定（Effective-Params/Baseline-Data/SLO-Runbook）

## 版权与许可
- 本白皮书遵循 `LICENSES/CC0.txt` 所载许可条款。
