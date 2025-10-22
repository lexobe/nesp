# NESP 合约测试指南

**最后更新**：2025-10-22
**Git 提交**：`cda930c` - test(contracts): add comprehensive unit tests for state machine

---

## 🎯 测试状态

### ✅ 已完成

**单元测试**（1 个文件，25+ 测试用例）
- ✅ `test/unit/StateMachine.t.sol` - E1-E13 状态转换测试
- ✅ `test/BaseTest.t.sol` - 测试基础设施

**辅助合约**（2 个）
- ✅ `contracts/mocks/MockERC20.sol` - ERC-20 测试代币
- ✅ `contracts/mocks/SimpleFeeHook.sol` - 手续费 Hook 测试实现

### ⏳ 待完成

**单元测试**
- [ ] `test/unit/Settlement.t.sol` - Pull 模式结算测试
- [ ] `test/unit/FeeHook.t.sol` - FeeHook 集成测试
- [ ] `test/unit/Governance.t.sol` - 治理功能测试
- [ ] `test/unit/Signatures.t.sol` - EIP-712 签名验证测试（E12）

**集成测试**
- [ ] `test/integration/EndToEnd.t.sol` - 端到端集成测试

**不变量测试**
- [ ] `test/invariant/Invariants.t.sol` - INV.1-INV.14 不变量测试

**模糊测试**
- [ ] `test/fuzz/StateMachineFuzz.t.sol` - 状态机模糊测试

---

## 📊 当前测试覆盖

### StateMachine.t.sol（25+ 测试用例）

| 转换 | 测试用例 | 状态 |
|------|----------|------|
| **E1** | acceptOrder (Initialized → Executing) | ✅ 3 个 |
| **E2** | cancelOrder (Initialized → Cancelled) | ✅ 2 个 |
| **E3** | markReady (Executing → Reviewing) | ✅ 3 个 |
| **E4** | approveReceipt (Executing → Settled) | ✅ 2 个 |
| **E5** | raiseDispute (Executing → Disputing) | ✅ 3 个 |
| **E6/E7** | cancelOrder (Executing → Cancelled) | ✅ 2 个 |
| **E8** | approveReceipt (Reviewing → Settled) | ✅ 1 个 |
| **E9** | timeoutSettle (Reviewing → Settled) | ✅ 3 个 |
| **E10** | raiseDispute (Reviewing → Disputing) | ✅ 1 个 |
| **E11** | cancelOrder (Reviewing → Cancelled) | ✅ 2 个 |
| **E13** | timeoutForfeit (Disputing → Forfeited) | ✅ 3 个 |
| **综合** | Happy Path & Dispute Path | ✅ 2 个 |

**关键测试场景**：
- ✅ 正常流程（Initialized → Executing → Reviewing → Settled）
- ✅ 争议流程（→ Disputing → Forfeited → 治理提款）
- ✅ 访问控制（`ErrUnauthorized`）
- ✅ 状态守卫（`ErrInvalidState`）
- ✅ 时间超时（`vm.warp` 模拟）

---

## 🛠 运行测试

### 前提条件

1. **安装 Foundry**（如果尚未安装）
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **安装依赖**
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
   forge install foundry-rs/forge-std --no-commit
   ```

### 基本命令

```bash
# 运行所有测试
forge test

# 运行详细模式（显示 Gas）
forge test -vv

# 运行超详细模式（显示 trace）
forge test -vvv

# 运行特定测试文件
forge test --match-path test/unit/StateMachine.t.sol

# 运行特定测试函数
forge test --match-test test_E1_AcceptOrder_Success

# 运行匹配模式的测试
forge test --match-test "test_E[1-5]"
```

### 高级选项

```bash
# 生成 Gas 报告
forge test --gas-report

# 生成覆盖率报告
forge coverage

# 生成 Gas 快照
forge snapshot

# 比较 Gas 快照差异
forge snapshot --diff .gas-snapshot

# 运行模糊测试（增加迭代次数）
forge test --fuzz-runs 10000
```

---

## 📝 测试结构

### BaseTest.t.sol（测试基础类）

**提供的功能**：

1. **通用设置**
   - 自动部署合约（NESPCore, SimpleFeeHook, MockERC20）
   - 创建测试账户（governance, client, contractor, provider, thirdParty）
   - 初始化余额（ETH 和 ERC-20）
   - 标记合约地址（便于追踪）

2. **辅助函数**
   ```solidity
   // 创建订单
   _createETHOrder()
   _createERC20Order()
   _createAndDepositETH(amount)
   _createAndDepositERC20(amount)

   // 充值
   _depositETH(orderId, amount, depositor)
   _depositERC20(orderId, amount, depositor)

   // 状态转换
   _toExecuting(orderId)
   _toReviewing(orderId)
   _toDisputing(orderId)
   _executeHappyPath() // 完整正常流程

   // 断言
   _assertState(orderId, expectedState)
   _assertEscrow(orderId, expectedAmount)
   _assertWithdrawable(token, account, expectedAmount)
   _assertETHBalance(account, expectedBalance)
   _assertTokenBalance(account, expectedBalance)
   ```

3. **测试常量**
   ```solidity
   INITIAL_BALANCE = 1000 ether
   ESCROW_AMOUNT = 10 ether
   FEE_BPS = 250 // 2.5%
   DUE_SEC = 1 days
   REV_SEC = 1 days
   DIS_SEC = 7 days
   ```

### StateMachine.t.sol（状态机测试）

**测试模式**：

1. **正向测试**（Happy Path）
   ```solidity
   function test_E1_AcceptOrder_Success() public {
       uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
       vm.prank(contractor);
       core.acceptOrder(orderId);
       _assertState(orderId, OrderState.Executing);
   }
   ```

2. **访问控制测试**
   ```solidity
   function test_E1_AcceptOrder_RevertWhen_NotContractor() public {
       uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
       vm.prank(client); // 错误的调用者
       vm.expectRevert(NESPCore.ErrUnauthorized.selector);
       core.acceptOrder(orderId);
   }
   ```

3. **状态守卫测试**
   ```solidity
   function test_E1_AcceptOrder_RevertWhen_WrongState() public {
       uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
       _toExecuting(orderId); // 已经是 Executing 状态
       vm.prank(contractor);
       vm.expectRevert(NESPCore.ErrInvalidState.selector);
       core.acceptOrder(orderId);
   }
   ```

4. **时间超时测试**
   ```solidity
   function test_E9_TimeoutSettle_Success() public {
       uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
       _toReviewing(orderId);

       // 快进时间
       Order memory order = core.getOrder(orderId);
       vm.warp(order.readyAt + order.revSec + 1);

       vm.prank(thirdParty);
       core.timeoutSettle(orderId);
       _assertState(orderId, OrderState.Settled);
   }
   ```

---

## 🔍 测试最佳实践

### 1. 命名规范

```solidity
// 格式：test_<功能>_<场景>
function test_E1_AcceptOrder_Success() public { ... }
function test_E1_AcceptOrder_RevertWhen_NotContractor() public { ... }
function test_E1_AcceptOrder_RevertWhen_WrongState() public { ... }
```

### 2. 使用 vm.prank

```solidity
// ✅ 正确：每次调用前都 prank
vm.prank(client);
core.approveReceipt(orderId);

// ❌ 错误：prank 只影响下一次调用
vm.prank(client);
core.getOrder(orderId); // 这里消耗了 prank
core.approveReceipt(orderId); // 这里没有 prank！
```

### 3. 使用 expectRevert

```solidity
// ✅ 正确：紧跟在会 revert 的调用前
vm.expectRevert(NESPCore.ErrUnauthorized.selector);
core.acceptOrder(orderId);

// ❌ 错误：中间有其他调用
vm.expectRevert(NESPCore.ErrUnauthorized.selector);
Order memory order = core.getOrder(orderId); // 这里不会 revert
core.acceptOrder(orderId); // expectRevert 已失效
```

### 4. 清理状态

```solidity
// 每个测试都是独立的，setUp() 会重新执行
function test_First() public {
    uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
    // ...
}

function test_Second() public {
    // 这里是全新的合约实例，orderId 从 1 重新开始
    uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
    // ...
}
```

### 5. 使用辅助函数

```solidity
// ✅ 推荐：使用辅助函数
function test_E10_RaiseDispute_FromReviewing() public {
    uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
    _toReviewing(orderId); // 简洁清晰
    // ...
}

// ❌ 不推荐：重复代码
function test_E10_RaiseDispute_FromReviewing() public {
    uint256 orderId = _createAndDepositETH(ESCROW_AMOUNT);
    vm.prank(contractor);
    core.acceptOrder(orderId);
    vm.prank(contractor);
    core.markReady(orderId);
    // 重复且难以维护
}
```

---

## 📈 下一步测试任务

### 优先级 P0（必须完成）

1. **Settlement.t.sol** - Pull 模式结算测试
   - 测试三笔记账（contractor, provider, client）
   - 测试手续费计算
   - 测试 withdraw 功能
   - 测试余额不足场景

2. **Signatures.t.sol** - EIP-712 签名验证（E12）
   - 测试签名协商结清
   - 测试 nonce 防重放
   - 测试签名过期
   - 测试签名不匹配

### 优先级 P1（强烈推荐）

3. **FeeHook.t.sol** - FeeHook 集成测试
   - 测试 SimpleFeeHook 手续费计算
   - 测试 Hook 调用失败容错
   - 测试手续费超出限制
   - 测试 Gas 限制（50k）

4. **Invariants.t.sol** - 不变量测试
   - INV.1-INV.14 完整覆盖
   - 使用 Foundry 的 invariant testing
   - 模糊测试结合

### 优先级 P2（可选）

5. **Governance.t.sol** - 治理功能测试
   - 测试 withdrawForfeit
   - 测试 setGovernance
   - 测试治理权限

6. **EndToEnd.t.sol** - 端到端集成测试
   - 多订单并发场景
   - 复杂交互场景
   - 真实用户工作流

---

## 🚀 运行测试清单

在推送代码前，确保：

- [ ] `forge test` 全部通过（无失败）
- [ ] `forge test -vv` 无 Gas 异常
- [ ] `forge coverage` 覆盖率 ≥ 95%
- [ ] `forge snapshot` 生成 Gas 快照
- [ ] 所有测试命名规范
- [ ] 所有测试有清晰注释
- [ ] 无跳过的测试（`skip = true`）

---

## 📚 相关资源

- **Foundry Book**：https://book.getfoundry.sh/
- **Forge Std Cheatcodes**：https://book.getfoundry.sh/cheatcodes/
- **OpenZeppelin Test Helpers**：https://docs.openzeppelin.com/test-helpers/
- **NESP 白皮书**：`SPEC/zh/whitepaper.md`（测试规范来源）

---

## 🎓 学习价值

这些测试展示了：

1. **Foundry 测试框架**：vm.prank, vm.warp, expectRevert
2. **状态机测试**：完整覆盖所有转换路径
3. **访问控制测试**：确保权限检查正确
4. **时间依赖测试**：使用 vm.warp 模拟超时
5. **模块化测试**：辅助函数复用，提高可维护性

---

**准备好运行测试了吗？** 🧪

```bash
# 一键运行（如果 Foundry 已安装）
forge test -vv

# 预期输出：
# Running 25+ tests for test/unit/StateMachine.t.sol
# [PASS] test_E1_AcceptOrder_Success (gas: ...)
# [PASS] test_E1_AcceptOrder_RevertWhen_NotContractor (gas: ...)
# ...
# Test result: ok. 25 passed; 0 failed; finished in X.XXs
```

**遇到问题？** 参考 Foundry Book 或查看 `test/BaseTest.t.sol` 中的注释。
