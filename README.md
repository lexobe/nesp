# NESP：A2A 无仲裁托管结算协议（No‑Arbitration Escrow Settlement Protocol）

副题：Trust‑Minimized · Timed‑Dispute · Symmetric‑Forfeit · Zero‑Fee

本仓库包含 NESP 白皮书（中文为唯一语义源）、英文镜像、EIP 草案、Solidity 参考实现与最小示例。English README can be added on request.

要点概览
- 规范（SSOT）：`SPEC/zh/whitepaper.md`（中文为唯一规范性来源）
- 英文镜像：`SPEC/en/whitepaper.md`（保持语义等价）
- EIP 草案：`EIP-DRAFT/eip-nesp.md`（EIP‑1 风格，CC0）
- 参考实现：`CONTRACTS/`（核心合约与接口）
- 测试：`TESTS/`（Foundry 测试，已统一目录名）
- 示例：`EXAMPLES/zh/minimal-flow.md`、`EXAMPLES/en/minimal-flow.md`
- TypedData：`EXAMPLES/settlement_typed_data.json`

目录结构（当前）
```
nesp/
├─ SPEC/
│  ├─ zh/                      # 中文创作（SSOT）
│  │  ├─ whitepaper.md
│  │  ├─ spec-full.md
│  │  ├─ game-theory.md
│  │  ├─ nespay-spec.md
│  │  └─ research/
│  │     ├─ NESP_协议深度研究报告.md / .pdf
│  │     └─ NESP_Magicians_Discussion.md
│  └─ en/                      # 英文发布（镜像）
│     ├─ whitepaper.md
│     └─ research/NESP_Magicians_Discussion.md
├─ EIP-DRAFT/
│  └─ eip-nesp.md
├─ CONTRACTS/
│  ├─ core/                    # NESPCore 与 Types
│  ├─ interfaces/              # INESP / IFeeHook / INESPEvents
│  └─ mocks/                   # 测试/示例 Mock
├─ TESTS/                      # Foundry 测试（已统一）
│  ├─ BaseTest.t.sol
│  └─ unit/*.t.sol
├─ EXAMPLES/
│  ├─ zh/minimal-flow.md
│  ├─ en/minimal-flow.md
│  └─ settlement_typed_data.json
├─ L10N/                       # 翻译映射/规则/状态
│  ├─ mapping.yml
│  ├─ status.md
│  └─ rules.md
├─ LICENSES/                   # 许可：CC0（文本）、MIT（代码）
│  ├─ CC0.txt
│  └─ MIT.txt
└─ 其它：`SECURITY.md`, `ROADMAP.md`, `.github/workflows/ci.yml`
```

环境与依赖
- 需要安装 Foundry（包含 `forge`/`anvil`/`cast`）。
- 校验安装：`forge --version && anvil --version && cast --version`
- 如命令不可用，请参考 Foundry 安装脚本：`curl -L https://foundry.paradigm.xyz | bash && foundryup`

快速开始
- 预览文档：打开 `SPEC/zh/whitepaper.md` 或 `SPEC/en/whitepaper.md`
- 构建合约：`forge build --sizes`
- 运行测试：`FOUNDRY_DISABLE_REMOTE_LOOKUPS=1 forge test -vvv`
- 搜索规范锚点：`rg "E[0-9]+|INV\.[0-9]+|EVT\.|MET\.|GOV\." SPEC/zh`

测试目录已统一
- 原有同时存在 `test/` 与 `TESTS/` 的情况已合并为 `TESTS/`（大写，符合顶层目录命名约定）。
- Foundry 配置已更新为 `test = "TESTS"`，CI 仍可通过 `forge test` 自动发现用例。

贡献与双语流程
- 影响协议语义的改动：先改 `SPEC/zh`，再同步 `SPEC/en`；更新 `EIP-DRAFT/eip-nesp.md`；在 `L10N/status.md` 记录同步状态。
- 变更事件/状态/不变式：同时更新示例与测试覆盖（至少：A≤E、零费守恒、超时优先级、签名争议、Pull 提现幂等）。
- 提交信息简洁、命令式；PR 附带受影响的规范锚点（E.x/INV.x/EVT.x）。

许可与安全
- 文本内容（白皮书与 EIP）：CC0；代码：MIT。
- 不要提交任何密钥或敏感信息；当前文档无需环境变量。

参考
- 文件列表：`git ls-tree -r --name-only HEAD`
- CI：见 `.github/workflows/ci.yml`（构建与测试）
