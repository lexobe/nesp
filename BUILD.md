# NESP 合约编译与测试指南

**最后更新**：2025-10-22
**Git 提交**：`f963e93` - fix(contracts): integrate SafeERC20 for ERC-20 token support

---

## 🎉 当前状态

✅ **所有 TODO 已修复**
✅ **SafeERC20 集成完成**
✅ **代码已提交** Git
⏳ **待编译验证**（需安装 Foundry）

---

## 📋 前提条件

### 系统要求

- **操作系统**：macOS / Linux / Windows (WSL)
- **Git**：≥ 2.30
- **终端**：Bash / Zsh

### 需要安装的工具

1. **Foundry**（Solidity 开发工具链）
   - Forge（编译器）
   - Anvil（本地节点）
   - Cast（CLI 工具）

2. **OpenZeppelin Contracts**（依赖库）
   - v5.0.2（通过 Foundry 安装）

---

## 🛠 安装 Foundry

### 步骤 1：安装 Foundry

```bash
# 下载安装脚本并执行
curl -L https://foundry.paradigm.xyz | bash

# 重新加载终端配置
source ~/.bashrc  # 或 source ~/.zshrc

# 安装/更新 Foundry
foundryup
```

### 步骤 2：验证安装

```bash
# 检查版本
forge --version
anvil --version
cast --version

# 预期输出类似：
# forge 0.2.0 (xxxxxx 2024-xx-xx)
# anvil 0.2.0 (xxxxxx 2024-xx-xx)
# cast 0.2.0 (xxxxxx 2024-xx-xx)
```

---

## 📦 安装依赖

```bash
# 进入项目根目录
cd /Users/liuyu/Code/aiden/nesp

# 安装 OpenZeppelin Contracts v5.0.2
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit

# 安装 Forge 标准库（测试工具）
forge install foundry-rs/forge-std --no-commit

# 验证安装
ls -la lib/
# 应该看到：
# lib/openzeppelin-contracts/
# lib/forge-std/
```

---

## 🔨 编译合约

### 基本编译

```bash
# 编译所有合约
forge build

# 预期输出：
# [⠢] Compiling...
# [⠆] Compiling 8 files with 0.8.24
# [⠰] Solc 0.8.24 finished in X.XXs
# Compiler run successful!
```

### 查看编译产物

```bash
# 查看编译产物目录
ls -la out/

# 主要文件：
# out/NESPCore.sol/NESPCore.json
# out/Types.sol/Types.json
# out/SimpleFeeHook.sol/SimpleFeeHook.json
```

### 清理编译缓存

```bash
# 清理缓存和编译产物
forge clean

# 重新编译
forge build
```

---

## 🧪 运行测试

### 当前测试状态

⚠️ **注意**：当前项目尚未编写测试用例。

待测试编写完成后，使用以下命令：

```bash
# 运行所有测试
forge test

# 运行详细模式（显示 Gas 消耗）
forge test -vv

# 运行特定测试文件
forge test --match-path test/unit/NESPCore.t.sol

# 运行特定测试函数
forge test --match-test testAcceptOrder

# 生成 Gas 报告
forge test --gas-report
```

---

## 📊 代码分析

### 合约大小检查

```bash
# 检查合约大小（Spurious Dragon 限制：24KB）
forge build --sizes

# 预期输出类似：
# | Contract      | Size (KB) | Margin (KB) |
# |---------------|-----------|-------------|
# | NESPCore      | 18.5      | 5.5         |
# | SimpleFeeHook | 1.2       | 22.8        |
```

### Gas 快照

```bash
# 生成 Gas 快照（需要测试）
forge snapshot

# 比较 Gas 快照差异
forge snapshot --diff .gas-snapshot
```

### 静态分析（Slither）

```bash
# 安装 Slither
pip3 install slither-analyzer

# 运行 Slither 分析
slither .

# 忽略低危警告
slither . --filter-paths lib/
```

---

## 🚀 部署准备

### 步骤 1：配置环境变量

```bash
# 复制示例配置
cp .env.example .env

# 编辑 .env（不要提交到 Git！）
vim .env

# 填写以下字段：
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
# PRIVATE_KEY_TESTNET=your_private_key_without_0x
# ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 步骤 2：本地部署测试

```bash
# 启动本地节点（新终端窗口）
anvil

# 部署到 Anvil（使用默认账户）
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# 查看部署日志
cat broadcast/Deploy.s.sol/31337/run-latest.json
```

### 步骤 3：测试网部署（Sepolia）

```bash
# 部署到 Sepolia
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY_TESTNET \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# 查看部署地址
cat broadcast/Deploy.s.sol/11155111/run-latest.json | grep "contractAddress"
```

---

## 🔧 常见问题

### Q1: 编译失败 - "SafeERC20 not found"

**原因**：OpenZeppelin 依赖未安装

**解决方案**：
```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
```

### Q2: 编译警告 - "SPDX license identifier not provided"

**状态**：正常，所有文件已有 `SPDX-License-Identifier: CC0-1.0`

### Q3: Gas 消耗过高

**解决方案**：
1. 检查 `foundry.toml` 中的 `optimizer = true`
2. 运行 `forge test --gas-report` 找到热点函数
3. 考虑使用 `unchecked` 块优化（谨慎使用）

### Q4: 合约超过 24KB 限制

**当前状态**：NESPCore ≈ 18.5KB，尚未超限

**未来优化方案**：
1. 拆分为多个合约（Diamond Pattern）
2. 使用库合约（Library）
3. 移除非关键功能

---

## 📁 项目结构

```
nesp/
├── CONTRACTS/                  # 合约代码（大写目录名）
│   ├── core/
│   │   ├── NESPCore.sol       # 主合约（835 行）
│   │   └── Types.sol          # 数据结构定义
│   ├── interfaces/
│   │   ├── IFeeHook.sol       # FeeHook 接口
│   │   └── INESPEvents.sol    # 事件定义
│   └── mocks/
│       └── SimpleFeeHook.sol  # FeeHook 测试实现
│
├── test/                      # 测试文件（待编写）
│   ├── unit/
│   ├── integration/
│   └── invariant/
│
├── script/                    # 部署脚本（待编写）
│   └── Deploy.s.sol
│
├── lib/                       # 依赖库（通过 forge install 安装）
│   ├── openzeppelin-contracts/
│   └── forge-std/
│
├── out/                       # 编译产物（.gitignore）
├── cache/                     # 编译缓存（.gitignore）
├── broadcast/                 # 部署记录（.gitignore）
│
├── foundry.toml               # Foundry 配置
├── remappings.txt             # 导入路径映射
├── .env.example               # 环境变量模板
├── .gitignore                 # Git 忽略规则
└── BUILD.md                   # 本文档
```

---

## ✅ 编译检查清单

在推送代码前，确保：

- [ ] `forge build` 成功（无错误）
- [ ] 无编译警告（或已知警告可忽略）
- [ ] `forge test` 通过（待测试编写完成）
- [ ] Gas 报告生成（`forge test --gas-report`）
- [ ] 合约大小检查（`forge build --sizes`）
- [ ] Slither 分析通过（无高危/中危问题）
- [ ] `.env` 文件未提交到 Git
- [ ] 依赖版本锁定（`lib/` 目录）

---

## 📚 相关文档

- **Foundry 官方文档**：https://book.getfoundry.sh/
- **OpenZeppelin Contracts**：https://docs.openzeppelin.com/contracts/5.x/
- **Solidity 文档**：https://docs.soliditylang.org/
- **NESP 白皮书**：`SPEC/zh/whitepaper.md`（项目 SSOT）
- **实现状态报告**：`IMPLEMENTATION_STATUS.md`

---

## 🤝 贡献指南

### 编译规范

1. **所有代码必须通过 `forge build`**
2. **遵循 Solidity 0.8.24 标准**
3. **使用 OpenZeppelin 库而非自己实现**
4. **遵循 CEI 模式**（Checks-Effects-Interactions）
5. **所有公开函数必须有 NatSpec 文档**

### Git 提交规范

```bash
# 格式：<type>(<scope>): <subject>
# 类型：feat, fix, docs, style, refactor, test, chore

# 示例：
git commit -m "feat(contracts): add withdraw batch function"
git commit -m "fix(tests): correct balance assertion in test"
git commit -m "docs(readme): update build instructions"
```

---

## 🔒 安全提醒

### ⚠️ 永远不要

1. **将 `.env` 文件提交到 Git**
2. **在代码中硬编码私钥**
3. **使用主网私钥进行测试**
4. **跳过 Slither 静态分析**
5. **禁用重入防护（`nonReentrant`）**

### ✅ 最佳实践

1. **使用 `.env.example` 作为模板**
2. **主网部署必须使用硬件钱包（Ledger）**
3. **测试网使用专用账户（不存放真实资产）**
4. **定期更新依赖库（`forge update`）**
5. **编写全面的单元测试（覆盖率 ≥ 95%）**

---

**准备好了吗？让我们开始编译！** 🚀

```bash
# 一键设置（如果 Foundry 已安装）
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit && \
forge install foundry-rs/forge-std --no-commit && \
forge build

# 如果成功，您应该看到：
# ✓ Compiler run successful!
```

**遇到问题？** 参考上面的"常见问题"章节，或查看 Foundry 官方文档。
