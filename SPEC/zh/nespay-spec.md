# NESPAY 扩展规范（基于 NESP 白皮书）

发布状态：草案（Draft）
版本：0.1
发布日期：2025-10-01

概述（信息性）
- WHY：以去中心化荷兰拍卖的方式，为“供应商槽位（Provider/Slot）”提供价格发现与准入；同时定义与 NESP 内核（A≤E、Pull/CEI）兼容的 EVC/FeeHook/Registry 扩展接口。
- WHAT：本扩展新增拍卖状态机与事件；EVC/FeeHook/Registry 为集成模块；不改变 NESP 内核状态机与不变量（仅扩展只读计算与外部事件）。
- HOW：所有扩展入口 permissionless + 幂等；金额单位与取整方向一致（USDC 1e6、向下取整）；失败路径可复现；事件可重放审计。

## 0) 规范与追溯锚点

WHY
- 与 `SPEC/zh/spec-full.md` 的风格一致，提供可追溯锚点与一致性关键字。

WHAT
- 一致性关键字：采用 RFC2119/RFC8174（MUST/SHOULD/MAY/MUST NOT）。
- 锚点命名：
  - 状态转换：E.PAY.x
  - 不变量：INV.PAY.x
  - 接口/事件：API.PAY.x / EVT.PAY.x
  - 指标：MET.PAY.x；治理：GOV.PAY.x
- Trace 原则：每条 E.PAY.x 映射至少一个 API/EVT，覆盖相关 INV.PAY.x 与至少一项 MET.PAY.x/GOV.PAY.x。

HOW
- 在每节内采用 WHW（WHY/WHAT/HOW）递归表达；信息性段落显式标注“信息性”。

## 1) 设计原则与范围（Minimal Enshrinement）

WHY
- 保持内核极简、可信中立；扩展仅增功能，不改变 A≤E、Pull/CEI、Forfeit 恒等式。

WHAT
- 不改变内核状态机与不变量（MUST）。
- 扩展入口 permissionless + 幂等（MUST）。
- 单位与定点：USDC（ERC‑20，6 位小数），以 token 计量，定点 1e6，统一向下取整（MUST）。
- 失败语义可复现，事件最小充分字段可重放（MUST）。

HOW
- 将拍卖、EVC、FeeHook、ProviderRegistry 定义为扩展层模块；核心订单仅在创建/结清时读取/固化必要字段（信息性）。

## 2) 模型与记号（NESPAY：Provider/Slot + 定点口径）

WHY
- 统一术语与计量，避免实现歧义与跨语言差异。

 WHAT
 - 术语：`slotId = providerId`（可取 provider 地址或 Registry 分配的 ID）；`feeReceiver` 为 Registry 登记的收款地址。
 - 资产与单位：USDC（6 位小数）；内部以 token 计量（1e6）；所有插值/比例计算统一向下取整；`price ≥ floorPrice`（MUST）。本规范版本仅支持单一 `paymentToken`（USDC 6 位小数）；如部署侧维护多资产白名单，属于信息性配置，不改变本规范的 API/事件含义。
 - 拍卖参数：`auctionDur=42h`；`floorPrice=100 USDC`；`maxInitialPrice`（治理上限，防极值）。
 - 状态记录（每槽/每场）：`{ startTs, endTs, initialPrice, floorPrice(=100USDC), cleared(bool), providerId, feeReceiver, clearingPrice, paymentToken }`。
 - 系统地址：`treasury` 为金库地址（MUST 非零地址）；`paymentToken` 为单一稳定币（USDC 6dec），配置于全局参数。

HOW
- 价格轨迹（线性下降）：`price(t) = max(floor, initial − (initial − floor) * (t − start) / auctionDur)`，在实现中按 1e6 定点向下取整。
- 伪代码（信息性，实现示例，向下取整）：
```
function priceAt(
  uint256 initial,
  uint256 floor,
  uint64 startTs,
  uint64 endTs,
  uint64 nowTs
) pure returns (uint256 p) {
  if (nowTs <= startTs) return initial;
  if (nowTs >= endTs) return floor;
  uint256 delta = initial - floor;              // initial ≥ floor 保证不下溢
  uint256 elapsed = uint256(nowTs - startTs);
  uint256 dur = uint256(endTs - startTs);
  uint256 dec = (delta * elapsed) / dur;        // 向下取整
  p = initial - dec;                            // p ≥ floor；若出现精度误差，外层再取 max(p,floor)
}
```

## 3) 槽位荷兰拍卖：状态机与守卫

WHY
- 通过线性降价实现去中心化准入与价格发现；任何人可在任意时刻接受当前价格达成清算。

WHAT
- 允许转换（仅此）：
  - E.PAY.1 NotRunning -startAuction-> Running
  - E.PAY.2 Running -acceptCurrentPrice-> Cleared
  - E.PAY.3 Running -endAuction(Expired)-> Ended
  - E.PAY.4 Cleared -endAuction(Cleared)-> Ended（信息性：实现可在 accept 时即标记 cleared=true，end 用于统一落幕与下一场参数设置）
- 守卫条目（MUST，缩写）：
  - startAuction(slotId)：上一场已结束；设置窗口与 initial；幂等（重复不改状态）。
  - acceptCurrentPrice(slotId, feeAddr)：`now ∈ [startTs,endTs]` 且 `!cleared`；一致性：`feeAddr == Registry.feeReceiver(slotId)`。
  - endAuction(slotId)：`now ≥ endTs`；若 `!cleared` 记流拍；幂等（重复不改状态）。

HOW
- 单位/定点：USDC 1e6，向下取整；倍增采用 `uint256`，当 `lastClearingPrice*2 > maxInitialPrice` 时 MUST 采用 `min(lastClearingPrice*2, maxInitialPrice)`（禁止回滚）。
- 金流：USDC 通过 `SafeERC20.safeTransferFrom(payer → treasury)` 入账；不与 NESP 内核托管 `E` 交叉（模块隔离）。
- 审计（信息性）：`acceptCurrentPrice` 的 `payer` 等于解析后的调用主体（Resolved Subject）；本扩展未引入 `via` 字段，归因可由交易来源与合约地址推导。

## 4) 扩展与集成模块

WHY
- 将扩展模块与内核职责解耦，保持最小内置。

 WHAT
 - 4.1 Evidence Commitments（EVC，信息性）：记录离链证据指纹；不改变订单金额与状态；仅事件。
 - 4.2 FeeHook（结清扩展）：结清时按 Hook 只读计算手续费 `(fee,to)`；`0 ≤ fee ≤ A`；守恒 `(A−fee)+(E−A)+fee=E`。
 - 4.3 ProviderRegistry：`providerId → {feeReceiver, hook, hookCtxHash, …}`；订单创建时解析为 `feeHook, feeCtxHash` 并固化；运行期变更不影响已固化订单。拍卖进行中（Running）禁止变更 `feeReceiver`（MUST），变更应在 `Ended` 后生效，以避免与 `acceptCurrentPrice` 的一致性竞态。

HOW
- EVC/Hook/Registry 的接口、错误、事件遵循各自模块说明（信息性引用自相关章节/实现）。

## 5) API 与事件契约（映射 E.PAY.x/INV.PAY.x）

WHY
- 提供最小充分接口与事件，确保拍卖可操作、可重放审计。

WHAT（API.PAY.*）
- API.PAY.1 `startAuction(uint256 slotId)`
  - Condition：上一场已结束；
  - Effects：设置 `startTs/endTs/initialPrice` 并发 EVT.PAY.1；保证 `initialPrice ≥ floorPrice`（MUST）；若已 Running，幂等无副作用。
  - Failure：`ErrAlreadyRunning`（已在进行中）；`ErrInvalidParam`（初始价小于 floor）；`ErrOverflow`（计算初始价溢出时）。
- API.PAY.2 `acceptCurrentPrice(uint256 slotId, address feeAddr)`
  - Condition：`now ∈ [startTs,endTs]`，`!cleared`，且 `feeAddr == Registry.feeReceiver(slotId)`；`payer = 解析后的调用主体（Resolved Subject）`；`IERC20(paymentToken).allowance(payer, address(this)) ≥ currentPrice(slotId)`；`paymentToken == getParams().paymentToken`（MUST）。
  - Effects：计算 `clearingPrice = currentPrice(slotId)`；从 `payer` `safeTransferFrom(paymentToken)` 至 `treasury`；标记 `cleared=true`，写入 `providerId/feeReceiver/clearingPrice`，并发 EVT.PAY.2；
  - Failure：`ErrAuctionNotOpen`、`ErrAlreadyCleared`、`ErrFeeAddrMismatch`、`ErrExpired`。
- API.PAY.3 `endAuction(uint256 slotId)`
  - Condition：`now ≥ endTs`；
  - Effects：若 `!cleared` 发 EVT.PAY.3(reason=Expired) 并设置下一场 `initialPrice = floorPrice` 后发 EVT.PAY.4(reason=ResetFloor)；若已清算，设置下一场 `initialPrice = min(lastClearingPrice*2, maxInitialPrice)` 并发 EVT.PAY.4(reason=DoubleLast)；重复调用幂等。
  - Failure：`ErrAuctionNotOpen`（尚未开始）。
- 只读视图（信息性）：
  - API.PAY.4 `getAuction(uint256 slotId) view -> AuctionRound`
  - API.PAY.5 `currentPrice(uint256 slotId) view -> uint256`
  - API.PAY.6 `getParams() view -> Params`
  - 视图行为（MUST）：当 `slotId` 对应的拍卖未处于 Running 时，`currentPrice(slotId)` MUST `revert`（`ErrAuctionNotOpen`）。

WHAT（EVT.PAY.*）
- EVT.PAY.1 `AuctionStarted(slotId, startTs, endTs, initialPrice, floorPrice, paymentToken)`
- EVT.PAY.2 `AuctionCleared(slotId, providerId, feeReceiver, clearingPrice)`
- EVT.PAY.3 `AuctionEnded(slotId, reason)`（`reason ∈ {Cleared,Expired}`）
- EVT.PAY.4 `NextInitialPriceSet(slotId, newInitial, reason)`（`reason ∈ {DoubleLast,ResetFloor}`）
 - 信息性：当 `reason=DoubleLast` 且 `newInitial == getParams().maxInitialPrice` 时，可推断“倍增被上限（clamped）”；本规范不另设事件字段，索引器可据此判断。

HOW（Solidity 参考接口，信息性）
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface INESPAYAuction {
  /// Params & Views
  struct Params { uint64 auctionDur; uint256 floorPrice; uint256 maxInitialPrice; address paymentToken; address treasury; }
  struct AuctionRound {
    uint64 startTs; uint64 endTs; uint256 initialPrice; uint256 floorPrice;
    bool cleared; uint256 providerId; address feeReceiver; uint256 clearingPrice; address paymentToken;
  }
  enum EndReason { Cleared, Expired }
  enum NextInitReason { DoubleLast, ResetFloor }

  function startAuction(uint256 slotId) external;
  function acceptCurrentPrice(uint256 slotId, address feeAddr) external;
  function endAuction(uint256 slotId) external;

  function getAuction(uint256 slotId) external view returns (AuctionRound memory r);
  function currentPrice(uint256 slotId) external view returns (uint256 p);
  function getParams() external view returns (Params memory p);

  event AuctionStarted(uint256 indexed slotId, uint64 startTs, uint64 endTs, uint256 initialPrice, uint256 floorPrice, address paymentToken);
  event AuctionCleared(uint256 indexed slotId, uint256 providerId, address feeReceiver, uint256 clearingPrice);
  event AuctionEnded(uint256 indexed slotId, EndReason reason);
  event NextInitialPriceSet(uint256 indexed slotId, uint256 newInitial, NextInitReason reason);
}
```

## 5.A 类型与枚举（信息性）

WHY
- 约束实现的 ABI 外形与读写结构，便于多语言 SDK 对齐。

WHAT
- 类型：`slotId/providerId: uint256`；`feeReceiver/paymentToken/treasury: address`；`startTs/endTs: uint64`；金额：`uint256`（token 最小单位）。
- 枚举：`EndReason = {Cleared, Expired}`；`NextInitReason = {DoubleLast, ResetFloor}`。
- 视图结构体：`Params`、`AuctionRound` 如上。

HOW
- 事件主题：对 `slotId` 使用 `indexed` 便于筛选；原因枚举按 `uint8` 编码（Solidity 默认）。

## 5.B 错误与失败语义

WHY
- 明确回滚路径与错误映射，保障集成一致性。

WHAT（错误码表，规范名）
- `ErrAuctionNotOpen`：拍卖未开始或已结束但调用不合时；
- `ErrAlreadyRunning`：尝试在 Running 期间重复 `startAuction`；
- `ErrAlreadyCleared`：重复清算或清算后状态不允许再次 `accept`；
  - `ErrFeeAddrMismatch`：`feeAddr` 与 Registry 登记不一致；
  - `ErrOverflow`：价格计算内部算术溢出；
  - `ErrExpired`：超出允许时间窗口。
  - `ErrInvalidParam`：初始价或参数非法（如 `initialPrice < floorPrice`）。

HOW
- 错误名为规范名，实施可采用等价自定义错误签名；语义必须一致。
- 事件字段顺序/类型稳定；金额单位为 token 最小单位；金额为 0 的次要事件可省略（信息性）。

## 6) 不变量与边界（INV.PAY.*）

WHY
- 约束实现空间，保障审计可复现与运行一致性。

WHAT
- INV.PAY.1 单位与定点：USDC 1e6，所有插值/比例计算向下取整。
- INV.PAY.2 价格轨迹：`price(t)` 单调不增，且 `price(t) ≥ floorPrice`。
- INV.PAY.3 一致性：`slotId = providerId`；`feeAddr == Registry.feeReceiver(slotId)` 不满足则 `revert`。
- INV.PAY.4 幂等：`startAuction/endAuction` 多次调用不改变状态；已清算拒绝重复清算。
 - INV.PAY.5 倍增极值：`initialPrice = cleared ? min(lastClearingPrice*2, maxInitialPrice) : floorPrice`（MUST）。
- INV.PAY.6 隔离性：不同 `slotId` 的状态互不影响。
 - INV.PAY.7 起拍价下界：任一场 `initialPrice ≥ floorPrice`（MUST）。

HOW
- 审计提示：重放 `Auction*` 事件核对状态与价格轨迹；跨槽位独立比对。

## 7) 安全与威胁模型

WHY
- 防止重入、溢出、竞态与资产对账异常。

WHAT
 - SafeERC20；不在扩展入口直接外转；遵循 CEI；必要时 `nonReentrant`。
 - 溢出/极值：当 `lastClearingPrice*2 > maxInitialPrice` 时，MUST 采用 `min(lastClearingPrice*2, maxInitialPrice)` 作为下一场起拍价（禁止回滚）。
- 竞态与幂等：清算与结束路径幂等，重复调用无副作用。
- 资产与对账：若采用白名单稳定币（信息性），需在部署文档指明；非标准代币需回滚或隔离。

HOW
- 价格计算采用“先乘后除”的有界实现或 `mulDiv` 风格，保证不提升精度且向下取整。

## 8) 代表性测试与覆盖

WHY
- 在实现层复现规范条款并提供审计用例。

WHAT
- 价格轨迹与下界（P2）验证；起拍倍增与溢出保护。
- 单位/定点与向下取整一致性。
- permissionless+幂等路径：`start/end` 重复；`accept` 仅首次成功。
- 一致性校验：`slotId/feeAddr` 映射。
- 多槽位并发与事件重放。

HOW
- 以事件重放与视图函数为准绳，构造单元与集成测试用例。

## 9) 可观测性与 SLO（信息性）

WHY
- 建立运行期目标与报警阈值，支撑运维与治理。

WHAT
- 指标：清算率、流拍率、拍卖 P95 时长、价格分布。
- 指标（可选扩展）：“被上限倍增（clamped）”占比（DoubleLast 但 `newInitial == maxInitialPrice`）。
- 目标（示例）：清算率 ∈ [60%, 95%]；流拍率 < 30%；P95 成交时长 < 36h；clamped 占比 < 20%。

HOW
- 以 `Auction*` 事件为数据源，滚动窗口统计并对外发布。

## 10) 部署与兼容性（信息性）

WHY
- 参数治理与资产白名单等部署差异需公开说明。

WHAT
- 参数表（规范字段 + 建议默认/上界）：
  - `auctionDur: uint64`（默认 151,200 秒=42h；MUST > 0）
  - `floorPrice: uint256`（默认 `100 * 1e6`；MUST > 0）
  - `maxInitialPrice: uint256`（默认 `type(uint128).max`；当 `lastClearingPrice*2 > maxInitialPrice` 时 MUST 采用 `min(lastClearingPrice*2, maxInitialPrice)`，禁止回滚）
  - `paymentToken: address`（USDC 地址；MUST 为 6 小数稳定币或在部署文档声明精度差异与适配）
  - `treasury: address`（金库地址；不可为零地址）
  - `tokenWhitelist?: address[]`（信息性，可选；不改变“单一 `paymentToken`”的规范约束；若启用，`paymentToken` 必须在白名单内）
- 生效时点与事件：参数变更需事件记录，明确新旧值与生效块。
- 与内核集成：FeeHook/Registry 在订单创建与结清时的固化与只读计算口径。

HOW
- 建议以治理模块或 Timelock 管理关键参数；多链部署需标注单位与时间口径一致性。

## 11) 版本化与变更管理

WHY
- 保证兼容性与演进的可追溯性。

WHAT
- 语义版本：状态机/INV/API/EVT 任一变更 → 次版本以上；破坏性变更 → 主版本。
- 变更卡（CHG）：记录影响面、迁移/回滚步骤、兼容窗口与指标对照。

HOW
- 提供事件别名的过渡期（信息性），在下个主版本移除。

## 12) 附录（追溯矩阵）

WHY
- 明确覆盖关系，便于审计与实现对照。

WHAT（全量覆盖）
- E.PAY.1 NotRunning->Running（startAuction） -> API.PAY.1 -> EVT.PAY.1 -> INV.PAY.4/7 -> MET.PAY.*（开场成功率/并发时延）
- E.PAY.2 Running->Cleared（acceptCurrentPrice） -> API.PAY.2 -> EVT.PAY.2 -> INV.PAY.2/3/4 -> MET.PAY.*（成交率/价格分布/P95 成交时长）
- E.PAY.3 Running->Ended（Expired） -> API.PAY.3 -> EVT.PAY.3 -> INV.PAY.4/5/7 -> MET.PAY.*（流拍率/下一场初始化及时性）
- E.PAY.4 Cleared->Ended（Cleared） -> API.PAY.3 -> EVT.PAY.3/4 -> INV.PAY.4/5/7 -> MET.PAY.*（下一场初始价规则与极值保护）

HOW
- 若实现引入更多内部状态（信息性），需确保与上述 E.PAY.* 映射保持单调与可复现，且事件覆盖不减少。
