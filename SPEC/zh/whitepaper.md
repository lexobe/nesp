# A2A 无仲裁托管结算协议（NESP）白皮书
副题：信任最小化 · 限时争议 · 对称没收威慑 · 零手续费

## 版本说明
- 本白皮书为独立、可判定、可复现的完整文档；正文内自洽给出全部定义、判据与口径，不依赖外部引用。
- 本白皮书即为唯一规范性文档（唯一语义源），包含完整的规则、接口与指标口径。
## 1. 摘要
就像互联网的演化一样，唯有“自由创建（无审计）、自由发布（无预审）、自由交易（无许可）”，生态才会自发涌现并持续扩张。然而完全自由也可能滑向“劣币驱逐良币”的黑暗森林。为避免从自由坠入无序，需要设计一套A2A（Agent‑to‑Agent）的代理结算底座，其核心要求是：无仲裁，且能协作自促进。所谓无仲裁，是指结算层不设中心化裁判，不做价值判断与平台裁量，保持可信中立与零协议费的制度承诺；所谓协作自促进，是指在不引入裁量的前提下，使理性的合作与妥协成为参与者自己的最优选择，从博弈结构上使得拖延、敲诈和欺骗的边际收益为零，甚至是亏损。

NESP 正是这样的底座：**链下协商，链上约束；以对称没收威慑为核心，促进链下最大限度合作与妥协的交易结算协议，同时实现了在零手续费的条件下的可持续发展。**

### 0.1 核心流程（快速导览，非规范）
- Step 1 托管：买方把应付款先存入托管账户（E）。
- Step 2 交付：卖方接单并完成交付/发货。
- Step 3 验收放款（无争议）：买方验收通过，托管款一次性全额打给卖方（E）。
- Step 4 发起争议（如有）：在限定时间内提出分歧。
- Step 5 限时协商：双方在争议期内商定付款数额 A（A≤E）→ 按 A 付款，剩余返还买方。
- Step 6 超时威慑：若超时仍未达成一致，则对称没收这笔托管款（双方都拿不到，划入 ForfeitPool，罚没资产留存于合约中且不对外分配）。
说明：本小节为导览，规范性口径以第 3–6 章（状态机/不变量/安全/接口与事件）为准；本节中的“口径锚点”仅为阅读帮助，不构成规范条文。

## 1. 设计原则（Principles）

### 1.1 最小内置（Minimal Enshrinement）
- 约束：结算内核不承载裁量与价值判断，不引入仲裁/表决/再质押依赖；链上仅保存可验证的最小集合：状态（订单流转）、金额口径（A≤E，E 单调不减）、可被外界承认的触发信号，以及公开可验证的时钟/窗口。
- 边界：上层的身份/信誉/拍卖/任务分配/使命型机制在应用层实现；账户抽象/可信转发（AA/2771/4337）仅为调用通道，不改变金额/时间/事件口径。
- 禁止项：把“谁对谁错”的裁量写入合约、从结清/托管中扣取任何协议费、以治理投票决定结算结果等。

### 1.2 可信中立（Credible Neutrality）
- 约束：确定性时间窗、对称规则、开放事件；任意第三方可重放审计。
- 证据：公开统一金额/时间口径与最小事件字段，保证“别人不必相信我们，但可以检验我们”。

### 1.3 零协议费（Zero‑Fee）
- 约束：结算合约不从托管 E 或结清 A 中抽取任何协议内费用；仅存在网络 Gas 成本。
- 证据：零费违规计数应=0；如检测到扣费或内置费项，应视为违规并可回退。
- 披露：外部费（钱包/代付/打包/桥/路由价差等）作为信息披露而非协议口径。

### 1.4 可验证与可重放（Verifiable & Replayable）
- 最小证据集：
  - 签名承诺：采用结构化签名，域至少包含 {orderId, tokenAddr, amount, chainId, nonce, deadline}，防跨单/跨链/重放；合约/域错/过期均为统一回滚路径。
  - 金额与会计：E 单调不减、A≤E；
  - 触发器族：定义“不可达一致”的可验证触发信号（限时只是其一；亦可包含签名缺席/矛盾、最低可验证性失败、握手破裂等）；
  - 时钟与窗口：统一时间口径与到期判定，任何人可据此重放路径与结果。

### 1.5 与 A2A 生命周期的对接（Lifecycle Alignment）
- 原则：结算适配不改变 A2A 的消息语义；提供清晰的“消息→结算动作”映射与“结算事件→会话回填”路径，使会话/线程与订单上下文同源一致。
- 调用路径：直连与代付/转发均需记录来源（via 字段），以便审计与归因；调用通道不改变结算口径。

### 1.6 分阶段开放与门槛治理（Phased Opening）
- 门槛：以统一参数表 {W, θ, β, τ} 设定阶段验收与运行门槛（窗口、没收率上限、协商接受率下限、P95 结清上限），并版本化管理。
- 动作：额度/清算/缓冲/熔断等运营动作位于应用层执行，内核不变。
- 目标：随着渗透提升，保持可判定/可复现/可对照与可回退，避免规模外溢把系统推回裁量与黑箱。

## 2. 模型与记号（A ≤ E 口径）

### 2.1 参与者与信息结构
- 参与者：Client（买方）、Contractor（卖方）。
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
- ERC‑20：`msg.value == 0`，使用 SafeERC20 `transferFrom` 成功后记账；
- 建议：支持“WETH 适配层”作为工程选项，但规范层必须支持原生 ETH。

### 2.6 参数协商与范围（规范）
- 协商主体与生效时点：`E`、`D_due`、`D_rev`、`D_dis` 由 Client 与 Contractor 针对“每一笔订单”达成一致；实现必须在订单建立/接受时固化存储。
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
- SIA1：`extendDue(orderId, newDueSec)`（仅 client）要求 `newDueSec > 当前 D_due`（严格延后）。
- SIA2：`extendReview(orderId, newRevSec)`（仅 contractor）要求 `newRevSec > 当前 D_rev`（严格延后）。
- SIA3：`depositEscrow(orderId, amount)`（`payable`）要求 `amount > 0`，且 `escrow ← escrow + amount`。调用方可以为任意地址：
  - 若调用方为受信路径（2771/4337 等），实现 MUST 解析业务主体 `subject` 并确保 `subject == client`；失败 MUST `revert`（`ErrUnauthorized`）；
  - 其他任意地址视为无条件赠与且自担没收风险，不改变订单权利义务，同时需自行完成代币转移（见下）。
- 冻结/终态/金额守卫顺序：`state ∈ {Disputing}` → `ErrFrozen`；`state ∈ {Settled, Forfeited, Cancelled}` → `ErrInvalidState`；其余进入金额/资产校验。
- 资产口径：订单资产为 ETH 时需 `msg.value == amount`；为 ERC‑20 时需 `msg.value == 0`，令 `payer ≡ subject`，并在 `SafeERC20.transferFrom(payer, this, amount)` 成功后记账（受信路径下 payer=client；赠与路径下 payer 为调用主体，需要其提前授权）。
- 适用范围：SIA3 允许于 Initialized/Executing/Reviewing；在 Disputing 与任何终态禁止充值。

### 3.3 守卫与副作用
- 参数持久化：在订单建立/接受时固化 `D_due/D_rev/D_dis`；不得依赖“隐式默认”。
- 锚点一次性：`startTime/readyAt/disputeStart` 仅允许“未设置→设置一次”。
- 调用主体解析（Resolved Subject）：直连 `subject = msg.sender`（`via = address(0)`）；如调用来自受信转发器（2771），则 `subject = _msgSender()`；如来自 EntryPoint（4337），则 `subject = userOp.sender`。
- 主体约束（MUST）：
  - `markReady`、`extendReview`：`subject == contractor`；
  - `approveReceipt`、`extendDue`：`subject == client`；
  - `raiseDispute`、`settleWithSigs`：`subject ∈ {client, contractor}`；
  - `cancelOrder`：按守卫分支检查 `subject == client`（G.E6）或 `subject == contractor`（G.E7/G.E11）；
  - `timeoutSettle`、`timeoutForfeit`：主体不限（任意地址可触发）。
  - G.E12：`settleWithSigs` 仅当 `state=Disputing`，且 `amountToSeller ≤ E` 并通过 EIP‑712/1271 签名、`nonce`、`deadline` 校验。
- G.E1：`acceptOrder` 仅当 `state=Initialized`；发起主体（解析 2771/4337 后的业务主体）MUST 等于该订单的 `contractor`，否则 `ErrUnauthorized`；副作用：`startTime = now`。
- G.E3：`markReady` 仅当 `now < startTime + D_due`；副作用：`readyAt = now` 并起算 `D_rev`。
- G.E4/E8：`approveReceipt` 仅适用于 `state ∈ {Executing, Reviewing}`。
- G.E9：`timeoutSettle` 仅当 `state=Reviewing` 且 `now ≥ readyAt + D_rev`。
- G.E5/E10：`raiseDispute` 允许于 Executing/Reviewing 任意时刻进入 Disputing；副作用：`disputeStart = now`；进入 Disputing 后 E 冻结，任何充值 `revert`（ErrFrozen）。
- G.E11：`cancelOrder`（contractor）仅当 `state=Reviewing`。
- G.E13：`timeoutForfeit` 仅当 `state=Disputing` 且 `now ≥ disputeStart + D_dis`。
- G.E6：`cancelOrder`（client）仅当“从未 Ready（`readyAt` 未设置）且 `now ≥ startTime + D_due`”。
- G.E7：`cancelOrder`（contractor）允许（无额外守卫）。

### 3.4 终态约束
- `Settled/Forfeited/Cancelled` 为终态；到达终态后不得再改变状态或资金记账；仅允许提现入口读取并领取既有可领额（若有）。

## 4. 结算与不变量（Pull 语义）

### 4.1 金额计算
- INV.1 全额结清：`amountToSeller = escrow`（approve/timeout）。
- INV.2 金额型结清：`amountToSeller = A` 且 `0 ≤ A ≤ escrow`（签名协商）。
- INV.3 退款：`refundToBuyer = escrow − amountToSeller`（若 A < escrow）。

### 4.2 资金安全
- INV.4 单次入账：每单至多一次将结清额/退款额入账至聚合余额（single_credit），防止重复计入可提余额。
- INV.5 幂等提现：提现前先读取并清零聚合余额，转账成功即完成；重复调用无可提余额，返回无副作用。
- INV.6 入口前抢占：外部入口先处理 `timeout*`，防延迟攻击。
  - 审计判据：当入口被调用时，若超时条件已满足（例如 `now ≥ readyAt + D_rev` 或 `now ≥ disputeStart + D_dis`），应优先导致对应的 `timeoutSettle/timeoutForfeit` 结果或返回超期错误；若未发生优先处理，视为违反本不变量。
- INV.7 资产与对账：SafeERC20 + 余额差核验；对“费率/重基/非标准”代币如无法保证恒等对账，MUST `revert`（ErrAssetUnsupported）。

（信息性）非标准 ERC‑20 对账伪代码
```
function _safeTransferIn(token, payer, amount) internal {
    uint256 pre = IERC20(token).balanceOf(address(this));
    SafeERC20.safeTransferFrom(IERC20(token), payer, address(this), amount);
    uint256 post = IERC20(token).balanceOf(address(this));
    if (post - pre != amount) revert ErrAssetUnsupported();
}
```
注：对 fee‑on‑transfer/rebase/可冻结/可暂停等资产，若无法满足“余额差==amount”的恒等式，应显式失败。

### 4.3 资金去向与兼容
- INV.8 没收去向：`escrow → ForfeitPool`（不向外部分配）；ForfeitPool 为合约内逻辑账户，罚没资产留存合约中，不向任何外部地址（含零地址/黑洞）转移；ETH 与 ERC‑20 采用一致语义。
- INV.9 比例路径兼容（可选）：`amountToSeller = floor(escrow * num / den)`；余数全部计入买方退款。实现需使用安全“mulDiv 向下取整”或等效无溢出实现；任何溢出/下溢必须回滚；禁止四舍五入与提精度。
- INV.10 Pull 语义：状态变更仅“记账可领额”（聚合到 `balance[token][addr]`），实际转账仅在 `withdraw(token)` 发生；禁止在状态变更入口直接 `transfer`。
- INV.11 锚点一次性：`startTime/readyAt/disputeStart` 一旦设置，MUST NOT 修改或回拨。
- INV.12 计时器规则：`D_due/D_rev` 仅允许延后（单调增加，且在进入 Disputing 前）；`D_dis` 固定且不可延长。
- INV.13 唯一机制：无争议路径必须全额结清；争议路径采用签名金额结清；金额口径始终满足 `A ≤ E`，链上仅记录托管与结清。
- INV.14 零协议费恒等式：任一结清/没收动作发生时，满足 `escrow_before = amountToSeller + refundToBuyer` 或（没收）`escrow_before = forfeited`；不允许出现协议费扣减。违反恒等式必须 `revert`（ErrFeeForbidden）。

#### 审计提示（信息性）
- HOW（≤3）：
  1) 对没收路径：按 `tokenAddr` 分组比对“合约资产余额增量 = Σ(Forfeited.amount)”且随后无 `BalanceCredited/BalanceWithdrawn` 外流；
  2) 核对订单维度的 `owed/refund` 清零；
  3) 对 ETH 与 ERC‑20 采用一致口径（余额差 + 事件）。
- WHAT：罚没资产留存合约，不向外部分配或销毁。

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

### 5.2 错误映射（统一）
- `ErrInvalidState`、`ErrExpired`、`ErrBadSig`、`ErrOverEscrow`、`ErrFrozen`、`ErrFeeForbidden`、`ErrAssetUnsupported`、`ErrReplay`、`ErrUnauthorized`。

### 5.3 交互顺序与重入
- 提现 `nonReentrant`，遵循 CEI；优先处理 `timeout*` 入口；提现使用 `call` 并检查返回。
- CEI 范围（规范）：除提现与 ERC‑20 `transferFrom` 外，所有状态变更入口禁止直接向外部地址转账或调用外部不受信任合约；所有状态变更入口均遵循“先校验、再记账、后交互”的顺序。

### 5.4 时间边界与残余风险
- 统一区块时间；`D_due/D_rev` 仅允许延后（单调），`D_dis` 固定且不可延长。
- 残余风险：破坏型对手导致的没收外部性 → 由社会层资质/信誉/稽核约束与运营护栏缓解。
 - 绑定（观测→动作）：当观测到异常模式（如没收率异常升高、协商接受率显著下降）时，按 §7.2 的 `SLO_T(W)` 判据与 CHG:SLO-Runbook 执行停写/白名单/回滚等动作。

## 6. API 与事件（最小充分集）

### 6.1 函数（最小集）
- `createOrder(tokenAddr, contractor, dueSec, revSec, disSec) -> orderId`：创建订单，固化资产与时间锚点。
- `createOrder(...)` 触发事件：`OrderCreated`。
- `createAndDeposit(tokenAddr, contractor, dueSec, revSec, disSec, amount)`（payable） ：创建并立即充值指定金额（ETH：`msg.value == amount`；ERC‑20：`transferFrom(subject, this, amount)`）。
- `createAndDeposit(...)` 触发事件：`OrderCreated`、`EscrowDeposited`（同一交易）。
- `depositEscrow(orderId, amount)`（payable）：补充托管额，允许 client 或第三方赠与；入口遵守资产与冻结守卫。触发事件：`EscrowDeposited`。
- `acceptOrder(orderId)`：承接订单，需 `subject == contractor`，并设置 `startTime`。触发事件：`Accepted`。
- `markReady(orderId)`：卖方声明交付就绪，仅 `subject == contractor`，设置 `readyAt` 并启动评审窗口。触发事件：`ReadyMarked`。
- `approveReceipt(orderId)`：买方验证交付并触发结清（`subject == client`）。触发事件：`Settled(actor=Client)` 与后续 `BalanceCredited/Refund` 记账。
- `timeoutSettle(orderId)`：在评审超时后由任意主体触发全额结清。触发事件：`Settled(actor=Timeout)` 与后续 `BalanceCredited` 记账。
- `raiseDispute(orderId)`：进入争议状态，`subject ∈ {client, contractor}`，记录 `disputeStart`。触发事件：`DisputeRaised`。
- `settleWithSigs(orderId, payload, sig1, sig2)`：争议期内按签名报文结清金额 A（守卫 `A ≤ escrow`）。触发事件：`AmountSettled` 与后续 `BalanceCredited/Refund` 记账（终态为 `Settled`）。
- `timeoutForfeit(orderId)`：争议超时由任意主体触发对称没收。触发事件：`Forfeited`。
- `cancelOrder(orderId)`：根据守卫（G.E6/G.E7/G.E11）由 client 或 contractor 取消订单。触发事件：`Cancelled`。
- `withdraw(tokenAddr)`：提取累计收益或退款（Pull 语义，`nonReentrant`）。
- `extendDue(orderId, newDueSec)`：client 单调延长履约窗口。触发事件：`DueExtended`（记录 old/new）。
- `extendReview(orderId, newRevSec)`：contractor 单调延长评审窗口。触发事件：`ReviewExtended`（记录 old/new）。

### 6.2 事件（最小字段）
- `OrderCreated(orderId, client, contractor, tokenAddr, dueSec, revSec, disSec, ts)`：订单建立时触发，固化角色与时间参数。
- `EscrowDeposited(orderId, from, amount, newEscrow, ts, via)`：托管额充值成功后触发，记录充值来源与调用通道。
- `Accepted(orderId, escrow, ts)`：承接订单（进入 Executing）时触发，确认当前托管额（`ts` 即 `startTime` 锚点）。
- `ReadyMarked(orderId, readyAt, ts)`：卖方标记交付就绪时触发（进入 Reviewing），固化 `readyAt` 锚点。
- `DisputeRaised(orderId, by, ts)`：进入争议状态时触发，记录争议发起方。
- `DueExtended(orderId, oldDueSec, newDueSec, ts, actor)`：买方延长履约窗口时触发（单调增加）。
- `DueExtended(orderId, oldDueSec, newDueSec, ts, actor)` 字段：`actor` 为地址类型，且 MUST 等于该订单的 `client`。
- `ReviewExtended(orderId, oldRevSec, newRevSec, ts, actor)`：卖方延长评审窗口时触发（单调增加）。
- `ReviewExtended(orderId, oldRevSec, newRevSec, ts, actor)` 字段：`actor` 为地址类型，且 MUST 等于该订单的 `contractor`。
- `Settled(orderId, amountToSeller, escrow, ts, actor)`（`actor ∈ {Client, Timeout}`）：无争议或评审超时结清时触发。
- `AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce, ts)`：双方签名协商金额 A 后触发。
- `Forfeited(orderId, ts)`：争议期超时被没收时触发。
- `Cancelled(orderId, ts, cancelledBy)`（`cancelledBy ∈ {Client, Contractor}`）：订单被取消时触发。
- `BalanceCredited(orderId, to, tokenAddr, amount, kind, ts)`（`kind ∈ {Payout, Refund}`）：结清/退款记账到可提余额时触发。
- `BalanceWithdrawn(to, tokenAddr, amount, ts)`：用户提现成功时触发。

### 6.3 授权与来源（2771/4337）
- `EscrowDeposited.via ∈ {address(0), forwarderAddr, entryPointAddr}`；`address(0)` 表示直接调用（`msg.sender == tx.origin`）。
- 2771：记录转发合约地址，且 `isTrustedForwarder(via)=true`；4337：记录配置的 `EntryPoint` 地址。
- 除上述三类外的合约调用 MUST `revert`（ErrUnauthorized）。不支持多重转发/嵌套；检测到多跳 MUST `revert`。授权失败为回滚路径，不发 `EscrowDeposited` 事件。

#### 定义与可观测锚点（补充，不改变语义）
- “多跳（multi‑hop）”界定：在同一笔调用中，经由多个转发/中继合约层层转发至本合约的情形（除受信任的 `forwarder` 或配置的 `EntryPoint` 之外的额外一跳及以上），均视为“多跳”。
- 判定口径：若 `msg.sender` 为合约地址，且既不是受信任的 `forwarder` 也不是配置的 `EntryPoint`，则视为未授权；若检测到“多跳”链路，MUST `revert`（`ErrUnauthorized`）。
- 可选工件（建议）：
  - 自定义错误签名：`ErrUnauthorized()`（或 `ErrUnauthorized(address caller, address via)`）；
  - 事件主题示例：`EscrowDeposited(uint256 orderId, address from, uint256 amount, uint256 newEscrow, uint256 ts, address via)` 的主题 `keccak256` 值；外部审计据此核对“未发事件”。

## 7. 可观测性与 SLO（公共审计）

### 7.1 指标（定义/单位/窗口）
- MET.1 结清延迟 P95、超时触发率。
- MET.2 提现失败率、重试率。
- MET.3 资金滞留余额。
- MET.4 协商接受率 = `#AmountSettled / #DisputeRaised`（每单仅计首个 `AmountSettled`）。
- MET.5 零协议费违规计数：期望=0（来源：回执内 `ErrFeeForbidden` 回滚次数）。
- GOV.1 终态分布（成功/没收/取消）。
- GOV.2 `A/E` 基线分布（以进入 Reviewing/Disputing 时的 E 为基线）。
- MET.6 状态转换延迟/吞吐（E1/E3/E5/E10 等非终态转换的时延与速率）。
 - GOV.3 争议时长分布：`DisputeRaised.ts → Settled/Forfeited.ts` 的持续时间（仅对进入 Disputing 的订单），按窗口统计 P50/P95/直方。

#### 计数与去重规则（口径约束）
- 每单仅一次：`OrderCreated/Accepted/ReadyMarked/DisputeRaised/Settled/AmountSettled/Forfeited/Cancelled`。
- `BalanceCredited`：按 `kind ∈ {Payout, Refund}` 去重——每单每种 kind 至多 1 次（因此每单最多 2 次：一次给卖方 Payout，一次给买方 Refund）。
- 可重复事件（订单维度）：
  - `EscrowDeposited`（允许多次充值或第三方赠与）
  - `BalanceWithdrawn`（余额领取可多次提取）
  - `DueExtended`、`ReviewExtended`（窗口仅允许单调延长，重复记录前后值轨迹）

#### 新增：GOV.3 争议时长
- 定义：从 `DisputeRaised.ts` 到终态 `Settled/Forfeited.ts` 的持续时间；
- 单位/窗口：秒；按窗口聚合（P50/P95/直方）；
- 说明：Forfeited 与 Settled 均纳入；取消不计。

### 7.2 SLO 与回滚剧本
- 判据：`SLO_T(W) := (MET.5=0) ∧ (forfeit_rate ≤ θ) ∧ (acceptance_rate ≥ β) ∧ (p95_settle ≤ τ)`；`θ/β/τ` 与窗口 `W` 由部署侧在 CHG 定义。
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
- R2：对卖方 `A−R(t)` 相对没收 `−I(t)` 优；观测：`GOV.1` 没收率与 `MET.6` 时延分布。
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
- 倾向 NESP：主观性交付/一次性交换，需最小内核/公共审计/零协议费；需要 `A∈[0,E]` 的部分结清与对称威慑；可接受“限时协商 + 对称没收”。
- 倾向中心化托管/仲裁（类外）：复杂证据/强监管/KYC、可接受平台费与裁量。
- 其他：原子交换/客观条件 → HTLC；高频低争议 → 状态通道；投票裁决可接受 → 去中心化仲裁（类外）。
## 12. 工程实现与安全护栏（Engineering & Safety）

### 12.1 最小工程实现清单
- 接口/事件/错误：采用第 6 章最小充分集。
- 签名域绑定：订单/资产/数额/截止/链标识/随机数；跨单/跨链/过期/域错路径测试。
- Pull/CEI/授权/重入：提现前清零、`nonReentrant`、授权校验与来源记录。
- 非标资产：由适配层与白名单策略处理；异常资产路径显式失败。

### 12.2 测试与验证（代表性）
- 代表性用例：无争议全额/签名金额/超时没收；覆盖 A≤E、计时器边界、Pull/CEI、授权与签名重放。
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
- `ForfeitPool` 罚没逻辑账户（不对外分配）。

### 16.2 指标与事件口径表（简）
- 事件：`OrderCreated/EscrowDeposited/Accepted/DisputeRaised/Settled/AmountSettled/Forfeited/Cancelled/Balance{Credited,Withdrawn}`。

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
- 指标：MET.1/2/3/4/5/6 与 GOV.1/2/3；窗口/来源版本化（CHG）。

### 16.4 Trace 示意（状态→接口/事件→不变量→指标）
- 示例 0：E3（Executing→Reviewing，markReady） → `ReadyMarked` →（锚点固化）→ GOV.3/时间路径重放。
- 示例 1：E4（Executing→Settled，approveReceipt） → `Settled` → INV.1 → MET.1/MET.3。
- 示例 2：E12（Disputing→Settled，settleWithSigs） → `AmountSettled`（终态 Settled） → INV.2 → MET.4。
- 示例 3：E13（Disputing→Forfeited，timeoutForfeit） → `Forfeited` → INV.8 → GOV.1/GOV.3（争议时长）。

### 16.5 目标与条款对照（WHY→WHAT）
## 版权与许可
- 零协议费承诺适用于合约层；本白皮书遵循仓库同目录下 `LICENSE` 文件所载许可条款。
