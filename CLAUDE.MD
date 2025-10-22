为 NAS 协议（nas_spec.md）提供严格的博弈论分析，验证其在信任最小化约束下的理论性质，建立与替代方案的比较优势，并为 A2A 交易基础设施的实际部署提供可验证的参数指导与边界条件（曾用名：PACT）。
分解结构：

  理论验证（学术贡献）

  - 核心性质证明：均衡存在性、存活性、Griefing界限
  - 方法论创新：变换式证明方法的提出与应用
  - 稳健性分析：排序扰动、参数敏感性

  机制比较（决策支持）

  - 量化优势：vs直接支付、中心化托管、其他去中心化方案
  - 适用边界：何时选择 NAS 协议，何时选择其他方案
  - 社会福利分析：效率、公平性、外部性

  实施指导（工程价值）

  - 参数配置：理论支撑的默认值与调优策略
  - 监控体系：关键指标、预警阈值、调整机制
  - 验证框架：理论预测的实证检验方法

---

## 文档审查方法：RWO (Recursive · WHW · Only)

当需要审查白皮书、规范文档或重要设计文档时，使用 RWO v1.9 方法（详见 `SPEC/zh/research/reviewer.md`）。

### 核心原则
- **只识别问题，不提供解决方案**（Read-WHW-Only）
- **三步法**：抽骨架 → 校验 → 汇总
- **WHW 结构**：每个评审块必须具备 WHY（唯一目标）/ HOW（≤3步、可复现）/ WHAT（可判定）

### 关键约束（CNS 核心规则）
1. **信息性内容跳过**：标题/脚注中出现"信息性""导览""非规范"等关键词 → 不计入评审块
2. **枚举表项不受步骤限制**：守卫表/函数清单/事件清单 → 逐条检查，表项数不受"≤3 步"限制
3. **允许章节互参**：若 §A 引用 §B 的判据/错误码/工件，只要 §B 给出明确定义，§A 无需重复
4. **复杂度上界**：递归深度 ≤3；根→叶路径总步骤数 ≤9；同一父节点直接子块数 ≤5；整篇评审块总数 ≤40
5. **红线检查（P0 级别）**：
   - 不可判定：缺少阈值/状态码/工件标识
   - 不可复现：HOW 缺失或证据不足
   - 不可回退：缺少回退四件套（观测/触发/步骤/恢复）

### 严重度分级
- **P0 (Blocker)**：违反红线，阻断发布
- **P1 (Should)**：影响 W1/W2/W4 验证的关键缺口
- **P2 (Nice)**：不影响判定/复现的表达/结构问题

### 输出格式
1. **TL;DR**：一句话结论 + 三步法 + 顶层 WHY
2. **结论**：Pass / Conditional Pass / Block
3. **Issue 列表**：仅问题（定位/严重度/WHY/HOW/WHAT/证据/影响/验收/归口）
4. **覆盖简表**：父 WHY → 子 WHAT 的映射（3–6 行项目符号）

### 常见误区（避免机械化执行）
- ❌ 将"列表枚举"误判为"步骤超限"
- ❌ 将"信息性段落"误判为"缺少判据"
- ❌ 将"章节互参"误判为"不可判定"
- ❌ 要求白皮书内嵌实现细节（脚本/存储槽/具体代码）

---

## 多专家分析框架

当评估重大设计变更（如机制调整、激励模型修改）时，采用多专家视角进行系统性分析。

### 1. 博弈论专家
- **关注点**：均衡结构、激励相容性、威慑效果
- **核心问题**：
  - 外部选项是否对称？
  - 是否存在唯一 SPE（子博弈完美均衡）？
  - 新机制是否引入套利/合谋可能？
- **工具**：逆推归纳法、纳什均衡验证、机制设计理论

### 2. 可信中立专家
- **关注点**：协议中立性、规则对称性、裁量风险
- **核心问题**：
  - 协议方是否成为利益相关方？
  - 规则是否对所有参与者公平？
  - 是否引入人为裁量点？
- **参考标准**：最小内置（Minimal Enshrinement）、可验证与可重放

### 3. 经济学专家
- **关注点**：激励结构、市场反应、长期可持续性
- **核心问题**：
  - 激励是否扭曲（威慑 vs 收入来源）？
  - 是否存在逆向激励（协议从问题中获益）？
  - 市场参与者如何响应？
- **分析方法**：激励相容性检验、市场均衡分析、福利经济学

### 4. 安全专家
- **关注点**：攻击面、防御边界、审计复杂度
- **核心问题**：
  - 新机制引入哪些攻击向量？
  - 重入/前端运行/治理攻击风险？
  - 审计验证的可行性？
- **工具**：威胁建模、形式化验证、攻击树分析

### 5. 合规专家
- **关注点**：监管风险、法律分类、合规成本
- **核心问题**：
  - 是否触发证券法/洗钱法/税法？
  - 协议方的法律责任边界？
  - KYC/AML 义务？
- **参考框架**：Howey Test、FATF 指南、各司法区监管态度

### 6. 产品专家
- **关注点**：用户体验、叙事传播、信任建立
- **核心问题**：
  - 用户如何理解这个机制？
  - 与现有方案的差异化叙事？
  - 信任建立的难度？
- **评估维度**：简洁性、直观性、公平感知

### 分析输出模板
```markdown
## [变更名称] 多专家分析

### 1️⃣ 博弈论视角
- **均衡变化**：[描述]
- **风险**：[列举]
- **量化影响**：[数据/指标]

### 2️⃣ 可信中立视角
- **中立性影响**：[违反/符合哪些原则]
- **对称性分析**：[各方地位变化]

### 3️⃣ 经济学视角
- **激励结构**：[当前 vs 改后]
- **市场预测**：[用户/生态反应]

### 4️⃣ 安全视角
- **新增攻击面**：[列举]
- **防御成本**：[评估]

### 5️⃣ 合规视角
- **监管风险**：[法律分类变化]
- **合规负担**：[新增义务]

### 6️⃣ 产品视角
- **用户叙事**：[当前 vs 改后]
- **信任影响**：[评估]

### 🎯 综合建议
- ✅ **支持理由**：[如适用]
- ❌ **反对理由**：[列举]
- 📋 **决策清单**：[必须回答的问题]
- 🔄 **替代方案**：[如有]
```

### 使用场景
- ForfeitPool 分配机制修改
- 争议窗口参数调整
- 新增仲裁/投票机制
- 费用模型引入
- 重大协议升级

---

## 应用示例

当用户提出"将 ForfeitPool 改为协议费"时，应自动触发多专家分析：
1. 博弈论：检查对称没收威慑是否被破坏
2. 可信中立：评估协议方是否成为受益第三方
3. 经济学：分析从"威慑工具"到"收入来源"的激励扭曲
4. 安全：识别治理攻击/重入等新增风险
5. 合规：判断协议费是否触发金融监管
6. 产品：评估用户信任与叙事的影响

**输出要求**：
- 给出明确的建议（支持/反对/有条件支持）
- 列出决策清单（必须回答的关键问题）
- 提供替代方案（如适用）
- 量化影响（如可能）

---

## NESP 合约开发实施计划

### 项目目标
基于 `SPEC/zh/whitepaper.md`（SSOT）开发、测试并部署 NESP 核心智能合约，遵循最小内置、可信中立原则，实现无仲裁托管结算协议。

### 开发原则（遵循全局 CLAUDE.md）
1. **增量进步**：每个 Stage 可独立编译、测试、提交
2. **学习现有模式**：参考 OpenZeppelin、Uniswap、Aave 的合约结构
3. **测试驱动**：先写测试（TDD），后写实现
4. **简单优先**：避免过早抽象，选择无聊的解决方案

### 技术栈
- **Solidity**: `^0.8.24`（Custom Errors + Transient Storage）
- **框架**: Foundry（速度快、内置 Fuzzing、Gas 优化）
- **依赖**: OpenZeppelin Contracts v5.0.0
- **审计工具**: Slither, Aderyn, Mythril

### 项目结构
```
nesp/
├── CONTRACTS/                      # 智能合约（与现有大写目录一致）
│   ├── core/
│   │   ├── NESPCore.sol           # 主合约（状态机 + 守卫）
│   │   ├── ForfeitPool.sol        # 罚没池管理（可选，集成到主合约）
│   │   └── FeeHook.sol            # 可选手续费接口
│   ├── interfaces/
│   │   ├── INESPCore.sol
│   │   └── IFeeHook.sol
│   ├── libraries/
│   │   ├── OrderLib.sol           # 订单逻辑库
│   │   └── SignatureLib.sol       # EIP-712 签名验证
│   └── mocks/
│       ├── MockERC20.sol
│       └── MaliciousHook.sol
├── TESTS/                          # 测试文件（与现有大写目录一致）
│   ├── unit/
│   │   ├── StateMachine.t.sol     # 13 个状态转换
│   │   ├── PullSettlement.t.sol   # Pull 模式结算
│   │   ├── Signatures.t.sol       # EIP-712 验证
│   │   └── FeeHook.t.sol          # 手续费 Hook
│   ├── integration/
│   │   ├── E2E.t.sol              # 端到端流程
│   │   └── Attacks.t.sol          # 攻击场景
│   └── invariant/
│       └── Invariants.t.sol       # 不变量测试（Fuzzing）
├── script/                         # 部署脚本
│   ├── DeployLocal.s.sol
│   ├── DeployTestnet.s.sol
│   └── DeployMainnet.s.sol
├── SPEC/                           # 规范文档（已存在）
│   ├── zh/whitepaper.md           # SSOT（唯一语义源）
│   └── en/
├── .env.example                    # 提交到 Git（无真实密钥）
├── .gitignore                      # 包含 .env
└── foundry.toml
```

---

## 实施阶段（5 Stages）

### Stage 0: 环境准备（1-2 天）
**目标**: 搭建开发环境，配置安全的密钥管理

**成功标准**:
- ✅ Foundry 安装成功（`forge --version`）
- ✅ 项目结构创建完成
- ✅ `.env.example` 配置（提交到 Git）
- ✅ `.gitignore` 包含敏感文件

**任务**:
```bash
# 1. 安装 Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. 初始化项目
forge init --no-git  # 因为已有 Git repo
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0

# 3. 配置 .env.example
cat > .env.example << 'EOF'
# 本地开发（Anvil 内置账户）
# 无需配置，使用 forge test 即可

# 测试网（Sepolia）
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
PRIVATE_KEY_TESTNET=  # 从水龙头获取测试币后填写
ETHERSCAN_API_KEY=    # 用于合约验证

# 主网（禁止纯文本私钥，必须使用 Ledger）
MAINNET_RPC_URL=
EOF

# 4. 配置 .gitignore
cat >> .gitignore << 'EOF'
.env
out/
cache/
broadcast/
EOF
```

**测试**:
```bash
forge build  # 应成功编译（即使没有合约）
```

---

### Stage 1: 核心状态机（3-5 天）
**目标**: 实现 13 个状态转换（E1-E13）及守卫逻辑

**成功标准**:
- ✅ 所有状态转换编译通过
- ✅ 守卫（Condition/Subject/Effects/Failure）完整实现
- ✅ 单元测试覆盖率 ≥ 90%（`forge coverage`）

#### Subtask 1.1: 类型定义与存储（WP §2, §3）
**文件**: `contracts/core/Types.sol`

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

enum OrderState {
    Initialized,
    Executing,
    Reviewing,
    Disputing,
    Settled,
    Forfeited,
    Cancelled
}

struct Order {
    address client;
    address contractor;
    address tokenAddr;
    OrderState state;
    uint256 escrow;          // E（托管额）
    uint48 dueSec;           // D_due
    uint48 revSec;           // D_rev
    uint48 disSec;           // D_dis
    uint48 startTime;
    uint48 readyAt;
    uint48 disputeStart;
    address feeHook;         // 可为 address(0)
    bytes32 feeCtxHash;
}
```

**测试**: `test/unit/Types.t.sol`
- 验证枚举值范围
- 验证结构体打包（Gas 优化）

#### Subtask 1.2: 状态转换守卫（WP §3.3）
**文件**: `contracts/core/NESPCore.sol`

```solidity
contract NESPCore {
    mapping(uint256 => Order) internal _orders;
    uint256 public nextOrderId;

    // 自定义错误（节省 Gas）
    error ErrInvalidState();
    error ErrUnauthorized();
    error ErrFrozen();

    // E1: Initialized -> Executing (acceptOrder)
    function acceptOrder(uint256 orderId) external {
        Order storage order = _orders[orderId];

        // Condition
        if (order.state != OrderState.Initialized) revert ErrInvalidState();

        // Subject
        if (msg.sender != order.contractor) revert ErrUnauthorized();

        // Effects
        order.state = OrderState.Executing;
        order.startTime = uint48(block.timestamp);

        emit Accepted(orderId, order.escrow);
    }

    // E3: Executing -> Reviewing (markReady)
    function markReady(uint256 orderId) external {
        Order storage order = _orders[orderId];

        // Condition
        if (order.state != OrderState.Executing) revert ErrInvalidState();
        if (block.timestamp >= order.startTime + order.dueSec) revert ErrInvalidState();

        // Subject
        if (msg.sender != order.contractor) revert ErrUnauthorized();

        // Effects
        order.state = OrderState.Reviewing;
        order.readyAt = uint48(block.timestamp);

        emit ReadyMarked(orderId, order.readyAt);
    }

    // ... 实现 E2, E4-E13（共 13 个）
}
```

**测试**: `test/unit/StateMachine.t.sol`
```solidity
contract StateMachineTest is Test {
    NESPCore public nesp;
    address client = address(0x1);
    address contractor = address(0x2);

    function setUp() public {
        nesp = new NESPCore(governance);
    }

    // 正向路径：E1
    function test_E1_AcceptOrder_Success() public {
        uint256 orderId = nesp.createOrder(...);

        vm.prank(contractor);
        nesp.acceptOrder(orderId);

        assertEq(uint8(nesp.getOrder(orderId).state), uint8(OrderState.Executing));
    }

    // 失败路径：E1（非 contractor 调用）
    function test_E1_AcceptOrder_Unauthorized() public {
        uint256 orderId = nesp.createOrder(...);

        vm.prank(address(0x999));
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        nesp.acceptOrder(orderId);
    }

    // ... 每个状态转换至少 2 个测试（正向 + 失败）
}
```

**提交标准**:
- 所有 13 个转换实现完毕
- 每个转换至少 2 个测试（正向 + 失败路径）
- `forge test` 全部通过
- Git commit: `feat(core): implement state transitions E1-E13`

---

### Stage 2: Pull 模式结算（2-3 天）
**目标**: 实现 Pull 语义、余额记账、提现逻辑（WP §4, INV.10）

**成功标准**:
- ✅ `withdraw` 通过重入测试
- ✅ 幂等性测试通过（重复 withdraw 无副作用）
- ✅ ETH + ERC-20 双资产测试通过

#### Subtask 2.1: 余额记账
```solidity
contract NESPCore {
    // 聚合余额：balance[token][user]
    mapping(address => mapping(address => uint256)) internal _balances;

    // 记账（内部函数）
    function _creditBalance(
        address to,
        address token,
        uint256 amount,
        BalanceKind kind  // Payout/Refund/Fee
    ) internal {
        _balances[token][to] += amount;
        emit BalanceCredited(orderId, to, token, amount, kind);
    }

    // 结清逻辑（E4, E8: approveReceipt）
    function approveReceipt(uint256 orderId) external {
        Order storage order = _orders[orderId];

        // 守卫（略）

        // 计算手续费
        uint256 fee = 0;
        address feeRecipient = address(0);
        if (order.feeHook != address(0)) {
            (feeRecipient, fee) = IFeeHook(order.feeHook).onSettleFee{gas: 50000}(...);
            require(fee <= order.escrow, "Fee exceeds escrow");
        }

        // 记账三笔（INV.14）
        uint256 payoutToSeller = order.escrow - fee;
        _creditBalance(order.contractor, order.tokenAddr, payoutToSeller, BalanceKind.Payout);
        _creditBalance(order.client, order.tokenAddr, 0, BalanceKind.Refund);  // A = E
        if (fee > 0) {
            _creditBalance(feeRecipient, order.tokenAddr, fee, BalanceKind.Fee);
        }

        order.escrow = 0;
        order.state = OrderState.Settled;
        emit Settled(orderId, order.escrow, order.escrow, SettleActor.Client);
    }
}
```

#### Subtask 2.2: 提现逻辑（CEI + nonReentrant）
```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NESPCore is ReentrancyGuard {
    using SafeERC20 for IERC20;

    function withdraw(address token) external nonReentrant {
        uint256 amount = _balances[token][msg.sender];

        // CEI: Checks-Effects-Interactions
        if (amount == 0) return;  // 幂等性

        _balances[token][msg.sender] = 0;  // 先清零

        // 转账
        if (token == address(0)) {
            // ETH
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC-20
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit BalanceWithdrawn(msg.sender, token, amount);
    }
}
```

**测试**: `test/unit/PullSettlement.t.sol`
```solidity
contract PullSettlementTest is Test {
    // 测试重入攻击防御
    function test_Withdraw_ReentrancyProtection() public {
        MaliciousERC777 token = new MaliciousERC777();
        // ... 设置攻击场景
        vm.expectRevert("ReentrancyGuard: reentrant call");
        nesp.withdraw(address(token));
    }

    // 测试幂等性
    function test_Withdraw_Idempotent() public {
        nesp.withdraw(address(usdc));  // 第一次提现
        uint256 balanceBefore = usdc.balanceOf(user);

        nesp.withdraw(address(usdc));  // 第二次提现
        assertEq(usdc.balanceOf(user), balanceBefore);  // 余额不变
    }
}
```

---

### Stage 3: EIP-712 签名验证（2-3 天）
**目标**: 实现 `settleWithSigs`，防止重放攻击（WP §5.1）

**成功标准**:
- ✅ 双签验证通过
- ✅ 跨订单/跨链/跨合约重放测试通过
- ✅ Deadline 超时测试通过

#### Subtask 3.1: EIP-712 域分隔符
```solidity
contract NESPCore {
    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public constant SETTLEMENT_TYPEHASH = keccak256(
        "Settlement(uint256 orderId,address tokenAddr,uint256 amountToSeller,address proposer,address acceptor,uint256 nonce,uint256 deadline)"
    );

    bytes32 public DOMAIN_SEPARATOR;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256("NESP"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }
}
```

#### Subtask 3.2: settleWithSigs 实现
```solidity
mapping(uint256 => mapping(address => uint256)) public nonces;  // orderId -> signer -> nonce

function settleWithSigs(
    uint256 orderId,
    uint256 amountToSeller,
    address proposer,
    address acceptor,
    uint256[2] calldata signerNonces,  // [client_nonce, contractor_nonce]
    uint256 deadline,
    bytes calldata sig1,
    bytes calldata sig2
) external {
    Order storage order = _orders[orderId];

    // 守卫
    if (order.state != OrderState.Disputing) revert ErrInvalidState();
    if (block.timestamp >= deadline) revert ErrExpired();
    if (block.timestamp >= order.disputeStart + order.disSec) revert ErrExpired();
    if (amountToSeller > order.escrow) revert ErrOverEscrow();

    // 验证双签
    bytes32 structHash = keccak256(abi.encode(
        SETTLEMENT_TYPEHASH,
        orderId,
        order.tokenAddr,
        amountToSeller,
        proposer,
        acceptor,
        signerNonces[0],  // proposer's nonce
        deadline
    ));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

    address signer1 = ECDSA.recover(digest, sig1);
    address signer2 = ECDSA.recover(digest, sig2);

    // 验证签名者是 client 和 contractor
    require(
        (signer1 == order.client && signer2 == order.contractor) ||
        (signer1 == order.contractor && signer2 == order.client),
        "Invalid signers"
    );

    // 验证 nonce（防重放）
    require(nonces[orderId][order.client] == signerNonces[0], "Invalid nonce");
    require(nonces[orderId][order.contractor] == signerNonces[1], "Invalid nonce");
    nonces[orderId][order.client]++;
    nonces[orderId][order.contractor]++;

    // 结清（记账三笔，同 Stage 2）
    // ...

    emit AmountSettled(orderId, proposer, acceptor, amountToSeller, signerNonces[0]);
}
```

**测试**: `test/unit/Signatures.t.sol`
```solidity
function test_SettleWithSigs_CrossOrderReplay() public {
    // 订单 1 的签名
    bytes memory sig1 = _sign(order1, clientPk);
    bytes memory sig2 = _sign(order1, contractorPk);

    // 尝试在订单 2 上重放
    vm.expectRevert("Invalid signers");  // 因为 orderId 不同
    nesp.settleWithSigs(order2Id, ..., sig1, sig2);
}

function test_SettleWithSigs_CrossChainReplay() public {
    // 在链 A 上签名
    vm.chainId(1);
    bytes memory sig1 = _sign(order1, clientPk);

    // 尝试在链 B 上重放
    vm.chainId(137);  // Polygon
    vm.expectRevert();  // DOMAIN_SEPARATOR 不同
    nesp.settleWithSigs(...);
}
```

---

### Stage 4: FeeHook 与 ForfeitPool（2-3 天）
**目标**: 实现可选手续费机制与罚没池治理（WP §4.1 INV.14, §4.3 INV.8）

**成功标准**:
- ✅ FeeHook 为 `address(0)` 时不计费
- ✅ 恶意 Hook（返回 `fee > amountToSeller`）被拒绝
- ✅ ForfeitPool 全量资金恒等式测试通过

#### Subtask 4.1: IFeeHook 接口
```solidity
// contracts/interfaces/IFeeHook.sol
interface IFeeHook {
    function onSettleFee(
        uint256 orderId,
        address client,
        address contractor,
        uint256 amountToSeller,
        bytes memory feeCtx
    ) external view returns (address recipient, uint256 fee);
}
```

#### Subtask 4.2: ForfeitPool 实现
```solidity
contract NESPCore {
    address public governance;
    mapping(address => uint256) public forfeitBalance;  // INV.8

    modifier onlyGovernance() {
        require(msg.sender == governance, "Not governance");
        _;
    }

    // E13: timeoutForfeit
    function timeoutForfeit(uint256 orderId) external {
        Order storage order = _orders[orderId];

        // 守卫
        if (order.state != OrderState.Disputing) revert ErrInvalidState();
        if (block.timestamp < order.disputeStart + order.disSec) revert ErrInvalidState();

        // 罚没
        forfeitBalance[order.tokenAddr] += order.escrow;
        uint256 forfeitedAmount = order.escrow;
        order.escrow = 0;
        order.state = OrderState.Forfeited;

        emit Forfeited(orderId, order.tokenAddr, forfeitedAmount);
    }

    // 治理提款
    function withdrawForfeit(address token, address to, uint256 amount)
        external
        onlyGovernance
        nonReentrant
    {
        require(amount > 0, "Zero amount");
        require(forfeitBalance[token] >= amount, "Insufficient forfeit");

        forfeitBalance[token] -= amount;

        if (token == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit ProtocolFeeWithdrawn(token, to, amount, msg.sender);
    }
}
```

**测试**: `test/unit/ForfeitPool.t.sol`
```solidity
function test_ForfeitPool_Invariant() public {
    // 设置：3 个订单，总托管 300 ETH
    // 1 个 Settled（100 ETH 分配）
    // 1 个 Forfeited（100 ETH 罚没）
    // 1 个 Executing（100 ETH 未终态）

    uint256 contractBalance = address(nesp).balance;
    uint256 userBalances = nesp.withdrawableOf(address(0), client)
                         + nesp.withdrawableOf(address(0), contractor);
    uint256 forfeit = nesp.forfeitBalance(address(0));
    uint256 pendingEscrow = 100 ether;  // Executing 订单

    // 全量资金恒等式（INV.8）
    assertEq(contractBalance, userBalances + forfeit + pendingEscrow);
}
```

---

### Stage 5: 完整测试套件（5-7 天）
**目标**: 集成测试、攻击场景测试、Gas 优化

**成功标准**:
- ✅ 单元测试覆盖率 ≥ 95%
- ✅ 所有批判性评价中的攻击场景通过测试
- ✅ Gas 优化完成（每个操作 < 100k Gas）

#### Subtask 5.1: 端到端集成测试
```solidity
// test/integration/E2E.t.sol
contract E2ETest is Test {
    function test_Scenario1_NoDispute_FullSettlement() public {
        // 1. 创建订单
        uint256 orderId = nesp.createAndDeposit{value: 1 ether}(...);

        // 2. 卖方接单
        vm.prank(contractor);
        nesp.acceptOrder(orderId);

        // 3. 卖方标记完成
        vm.prank(contractor);
        nesp.markReady(orderId);

        // 4. 买方验收
        vm.prank(client);
        nesp.approveReceipt(orderId);

        // 5. 卖方提现
        vm.prank(contractor);
        nesp.withdraw(address(0));

        assertEq(contractor.balance, 1 ether);  // 全额收款
    }

    function test_Scenario2_Dispute_PartialSettlement() public {
        // ... → raiseDispute → settleWithSigs(A=0.8E)
    }

    function test_Scenario3_Dispute_Timeout_Forfeit() public {
        // ... → raiseDispute → vm.warp(+7 days) → timeoutForfeit
    }
}
```

#### Subtask 5.2: 攻击场景测试
```solidity
// test/integration/Attacks.t.sol
contract AttacksTest is Test {
    // 批判性评价 §4 缺陷 10: 前端运行攻击
    function test_Attack_Frontrunning_DisputeWindow() public {
        // 卖方提交 settleWithSigs(A=0.8E)
        bytes memory sellerTx = abi.encodeCall(nesp.settleWithSigs, (...));

        // 买方观察到后，立即提交 raiseDispute（Gas 更高）
        vm.prank(client);
        nesp.raiseDispute(orderId);  // 先执行

        // 卖方交易失败
        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        (bool success, ) = address(nesp).call(sellerTx);
        assertFalse(success);
    }

    // 批判性评价 §4 缺陷 9: 时间戳操纵
    function test_Attack_TimestampManipulation() public {
        // 设置：距离超时还有 10 秒
        vm.warp(disputeStart + disSec - 10);

        // 卖方提交 settleWithSigs
        vm.prank(contractor);
        nesp.settleWithSigs(...);

        // 矿工延迟 20 秒
        vm.warp(block.timestamp + 20);

        // 验证：settleWithSigs 应已成功（在延迟前执行）
        assertEq(uint8(nesp.getOrder(orderId).state), uint8(OrderState.Settled));
    }
}
```

#### Subtask 5.3: Gas 优化
```bash
# 生成 Gas 快照
forge snapshot

# 优化后对比
forge snapshot --diff
```

**优化目标**:
- `createOrder`: < 150k Gas
- `acceptOrder`: < 50k Gas
- `approveReceipt`: < 80k Gas
- `settleWithSigs`: < 120k Gas

---

## 部署流程

### 本地部署（Anvil）
```bash
# 启动本地节点
anvil

# 部署
forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 测试网部署（Sepolia）
```bash
# 1. 获取测试币
# https://sepoliafaucet.com/

# 2. 配置 .env
echo "PRIVATE_KEY_TESTNET=0x..." >> .env
echo "SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/..." >> .env

# 3. 部署
forge script script/DeployTestnet.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY_TESTNET \
  --broadcast \
  --verify

# 4. 验证合约
forge verify-contract <ADDRESS> NESPCore \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 主网部署（⚠️ 需审计）
**前置条件**:
- [ ] 至少 1 家专业审计（Trail of Bits / OpenZeppelin）
- [ ] 所有 High/Critical 问题已修复
- [ ] 测试网运行 ≥ 30 天
- [ ] 治理多签已配置（Gnosis Safe）
- [ ] Bug Bounty 已启动（Immunefi）

```bash
# 必须使用硬件钱包（Ledger）
forge script script/DeployMainnet.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --ledger \
  --sender <LEDGER_ADDRESS> \
  --broadcast
```

---

## 私钥安全指南

### ✅ 正确做法

**1. 本地开发**（无真实价值）
```bash
# Anvil 自动提供 10 个测试账户
# 私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
# 地址: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

**2. 测试网**（测试币）
```bash
# 方法 A: .env（本地开发）
echo "PRIVATE_KEY_TESTNET=0x..." >> .env  # 永远不提交到 Git

# 方法 B: 环境变量（CI/CD）
export PRIVATE_KEY_TESTNET=0x...
forge test --rpc-url $SEPOLIA_RPC_URL
```

**3. 主网**（真实资金）
```bash
# 唯一正确方式：硬件钱包
forge script ... --ledger --mnemonic-index 0
```

### ❌ 绝对禁止

```bash
# 1. 永远不要提交私钥到 Git
git add .env  # ❌

# 2. 永远不要在代码中硬编码
const PRIVATE_KEY = "0xabcd...";  // ❌

# 3. 主网部署永远不要用纯文本私钥
forge script ... --private-key 0x...  # ❌（仅限测试网）
```

---

## 审计检查清单

### 部署前必须完成
- [ ] Slither 扫描（无 High/Medium 问题）
- [ ] Aderyn 扫描（无红色警告）
- [ ] 单元测试覆盖率 ≥ 95%
- [ ] 所有批判性评价中的攻击场景有测试
- [ ] Gas 优化完成（快照对比）
- [ ] 文档完整（NatSpec 注释）

### 专业审计（主网前必须）
- [ ] Trail of Bits / OpenZeppelin / Consensys Diligence
- [ ] 审计报告公开发布
- [ ] 所有 Critical/High 问题已修复
- [ ] Medium 问题已评估（接受或修复）

### 持续监控
- [ ] Tenderly 监控（交易追踪）
- [ ] Defender Sentinel（异常告警）
- [ ] Dune Analytics（链上指标面板）

---

## 遇到问题时（3 次尝试原则）

**遵循全局 CLAUDE.md 的"When Stuck"流程**：

1. **记录失败**（最多 3 次尝试）
   - 尝试了什么？
   - 具体错误信息？
   - 为什么失败？

2. **研究替代方案**
   - 找 2-3 个类似实现（Uniswap/Aave/OpenZeppelin）
   - 比较不同方法

3. **简化问题**
   - 能否拆分成更小的子问题？
   - 能否移除抽象？

4. **寻求帮助**
   - 提问到 Foundry Discord / Ethereum Stack Exchange
   - 附上最小可复现示例（MCVE）

---

## 提交规范

**遵循 Conventional Commits**:
```
feat(core): implement state transitions E1-E13
test(pull): add reentrancy attack tests
fix(sigs): prevent cross-chain replay attack
docs(readme): add deployment guide
chore(deps): upgrade OpenZeppelin to v5.0.1
```

**每次提交必须**:
- ✅ `forge build` 编译通过
- ✅ `forge test` 全部通过
- ✅ `forge fmt` 格式化代码
- ✅ Commit 消息清晰说明"为什么"

---

## 进度追踪

使用 `IMPLEMENTATION_PLAN.md` 记录详细进度（遵循全局 CLAUDE.md）：

```markdown
## Stage 1: 核心状态机
**Status**: In Progress (60%)

### Subtask 1.1: 类型定义
- [x] 定义 OrderState 枚举
- [x] 定义 Order 结构体
- [x] 编写单元测试

### Subtask 1.2: 状态转换守卫
- [x] E1: acceptOrder
- [x] E2: cancelOrder (Initialized)
- [x] E3: markReady
- [ ] E4: approveReceipt (Executing)
- [ ] E5-E13（剩余 9 个）
```

**更新规则**:
- 每完成一个 Subtask → 更新 Markdown
- 每完成一个 Stage → Git commit + tag（`v0.1.0-stage1`）
- 遇到阻塞 → 记录到"问题日志"部分

---

## 总结

### 时间估算
- **Stage 0**: 1-2 天（环境准备）
- **Stage 1**: 3-5 天（状态机）
- **Stage 2**: 2-3 天（Pull 模式）
- **Stage 3**: 2-3 天（签名验证）
- **Stage 4**: 2-3 天（FeeHook + ForfeitPool）
- **Stage 5**: 5-7 天（完整测试）
- **总计**: 15-23 天（约 3-5 周）

### 风险缓解
1. **私钥泄露**：使用 `.env` + `.gitignore`，主网强制 Ledger
2. **合约漏洞**：多层测试（单元/集成/Fuzzing）+ 专业审计
3. **Gas 过高**：Foundry `snapshot` 对比 + 优化迭代
4. **时间延误**：每个 Stage 独立可交付，可分批部署

### 下一步
1. **立即执行**：初始化 Foundry 项目（Stage 0）
2. **本周完成**：Stage 1（状态机骨架）
3. **本月完成**：Stage 1-4（核心功能）
4. **下月完成**：Stage 5（完整测试）+ 测试网部署
