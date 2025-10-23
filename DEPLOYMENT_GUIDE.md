# NESP Base Sepolia 部署指南

## 📋 前提条件

1. **安装 Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **创建测试钱包**
   - 使用 Metamask 创建新账户
   - 导出私钥（Account Details → Show Private Key）
   - **⚠️ 警告**：仅用于测试网，不要发送真实资产！

3. **获取测试 ETH**
   - 访问 [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
   - 输入你的钱包地址
   - 每次可领取 ~0.05 ETH（24小时冷却）

---

## 🚀 快速部署（5 分钟）

### 步骤 1: 配置环境变量

```bash
# 1. 复制配置模板
cp .env.base-sepolia.example .env

# 2. 编辑 .env 文件
# 将 PRIVATE_KEY 替换为你的私钥（从 Metamask 导出）
vim .env  # 或使用你喜欢的编辑器
```

**`.env` 示例**:
```bash
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
PRIVATE_KEY=0x你的私钥（64位十六进制）
BASESCAN_API_KEY=你的BaseScan_API_Key（可选）
```

### 步骤 2: 模拟部署（不上链）

先在本地模拟部署，确保一切正常：

```bash
forge script script/DeployBaseSepolia.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

**预期输出**:
```
=== Deploying NESPCore ===
NESPCore deployed at: 0x...

=== Deploying Test Token ===
TestToken deployed at: 0x...

=== Deployment Summary ===
✅ All contracts deployed successfully
```

### 步骤 3: 实际部署到测试网

确认模拟成功后，执行真实部署：

```bash
forge script script/DeployBaseSepolia.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

**参数说明**:
- `--broadcast`: 实际发送交易到网络
- `--verify`: 自动验证合约源码（需要 BASESCAN_API_KEY）
- `--etherscan-api-key`: BaseScan API 密钥（注册：https://basescan.org/myapikey）

### 步骤 4: 验证部署

部署完成后，查看输出的合约地址：

```
=== Deployment Summary ===
NESPCore: 0x123...abc
TestToken: 0x456...def
FeeValidator: 0x789...ghi
```

访问 [BaseScan Sepolia](https://sepolia.basescan.org/) 查看合约：
- 搜索合约地址
- 查看交易历史
- 与合约交互（Read/Write）

---

## 🧪 部署后测试

### 1. 查看合约信息

```bash
# 读取 NESPCore 状态
cast call <NESP_CORE_ADDRESS> "nextOrderId()(uint256)" \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# 查看 governance 地址
cast call <NESP_CORE_ADDRESS> "governance()(address)" \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 2. 创建测试订单

```bash
# 从 Metamask 或使用 cast 发送交易
cast send <NESP_CORE_ADDRESS> \
  "createAndDeposit(address,address,uint48,uint48,uint48,address,uint16,uint256)" \
  0x0000000000000000000000000000000000000000 \ # tokenAddr (ETH)
  <CONTRACTOR_ADDRESS> \
  86400 \    # dueSec (1 day)
  86400 \    # revSec (1 day)
  604800 \   # disSec (7 days)
  0x0000000000000000000000000000000000000000 \ # feeRecipient
  0 \        # feeBps
  1000000000000000000 \  # amount (1 ETH)
  --value 1000000000000000000 \  # msg.value
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. 使用 Web3 前端交互（推荐）

部署后，可以创建简单的前端与合约交互：

```javascript
// 使用 ethers.js
import { ethers } from 'ethers';

const provider = new ethers.providers.JsonRpcProvider('https://sepolia.base.org');
const nespCore = new ethers.Contract(
  '0x你的NESPCore地址',
  NESPCoreABI,
  provider
);

// 读取订单信息
const order = await nespCore.getOrder(1);
console.log('Order:', order);
```

---

## 📊 部署成本估算

基于 Base Sepolia Gas 价格（约 0.001 gwei）：

| 合约 | 部署 Gas | 估算成本 |
|------|----------|----------|
| NESPCore | ~3,000,000 | ~0.003 ETH |
| MockERC20 | ~1,200,000 | ~0.0012 ETH |
| FeeValidator | ~200,000 | ~0.0002 ETH |
| **总计** | ~4,400,000 | **~0.0044 ETH** |

**建议**: 至少准备 **0.01 ETH** 用于部署和后续测试交易。

---

## 🔒 安全提醒

### ✅ 安全实践

1. **测试网私钥隔离**
   - 创建专门的测试钱包
   - 永远不要在测试网钱包中存放真实资产
   - 测试完成后可以丢弃私钥

2. **环境变量保护**
   ```bash
   # .gitignore 应包含
   .env
   .env.*
   !.env.example
   ```

3. **部署前检查**
   ```bash
   # 检查当前账户余额
   cast balance <YOUR_ADDRESS> --rpc-url $BASE_SEPOLIA_RPC_URL

   # 检查当前网络
   cast chain-id --rpc-url $BASE_SEPOLIA_RPC_URL
   # 应输出: 84532 (Base Sepolia)
   ```

### ❌ 危险操作（永远不要）

1. ❌ 将私钥提交到 Git
2. ❌ 在公共频道分享私钥
3. ❌ 在测试网钱包中存放真实资产
4. ❌ 使用主网钱包私钥部署测试网

---

## 🐛 常见问题

### Q1: 部署失败 "Insufficient funds"
```
Error: Insufficient funds for gas * price + value
```

**解决**:
1. 检查账户余额: `cast balance <YOUR_ADDRESS> --rpc-url $BASE_SEPOLIA_RPC_URL`
2. 前往 faucet 领取测试币
3. 确保至少有 0.01 ETH

### Q2: RPC 连接失败
```
Error: Failed to connect to RPC
```

**解决**:
1. 检查 RPC URL 是否正确（https://sepolia.base.org）
2. 尝试其他 RPC:
   - Alchemy: `https://base-sepolia.g.alchemy.com/v2/YOUR_KEY`
   - Infura: `https://base-sepolia.infura.io/v3/YOUR_KEY`
3. 检查网络连接

### Q3: 合约验证失败
```
Error: Failed to verify contract
```

**解决**:
1. 确保提供了 BASESCAN_API_KEY
2. 等待几分钟后手动验证:
   ```bash
   forge verify-contract \
     <CONTRACT_ADDRESS> \
     NESPCore \
     --chain base-sepolia \
     --etherscan-api-key $BASESCAN_API_KEY
   ```

### Q4: 如何获取部署的合约地址？

部署后会输出到控制台，也会保存到 `deployments/` 目录：

```bash
# 查看最新部署
ls -lt deployments/
cat deployments/base-sepolia-*.json
```

---

## 📚 下一步

部署成功后，你可以：

1. **创建测试订单**
   - 使用 Remix IDE 连接 Base Sepolia
   - 或使用 `cast send` 命令行工具
   - 或开发 Web3 前端

2. **邀请他人测试**
   - 分享合约地址
   - 提供测试 ETH（从你的钱包发送）
   - 收集反馈

3. **监控合约活动**
   - BaseScan: https://sepolia.basescan.org/address/<YOUR_CONTRACT>
   - Tenderly: https://dashboard.tenderly.co/

4. **准备主网部署**
   - 进行专业审计（Trail of Bits / OpenZeppelin）
   - 在测试网运行至少 30 天
   - 配置多签治理（Gnosis Safe）

---

## 📞 获取帮助

- **技术支持**: 在项目 GitHub Issues 提问
- **测试 ETH**: 告诉我你的地址，我会发送测试币
- **合约问题**: 查看 `TESTS/` 目录的单元测试示例

---

**祝部署顺利！🎉**
