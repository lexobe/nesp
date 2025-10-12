# NESP：A2A 无仲裁托管结算协议（No‑Arbitration Escrow Settlement Protocol）

副题：Trust‑Minimized · Timed‑Dispute · Symmetric‑Forfeit · Zero‑Fee

说明：本仓库承载 NESP 的白皮书、EIP 草案、参考实现规划与示例资料。白皮书为唯一规范性文档（SSOT），其语义与 EIP 草案保持等价。

- 规范（SSOT，白皮书）：SPEC/zh/whitepaper.md
- EIP 草案（英文）：EIP-DRAFT/eip-nesp.md
- 示例（端到端与 TypedData）：EXAMPLES/minimal-flow.md
- 讨论/研究：docs/zh/NESP_协议深度研究报告.md

目录结构（目标形态）
```
nesp/
├─ README.md
├─ SPEC/
│  ├─ zh/                      # 中文创作（SSOT）
│  │  ├─ whitepaper.md
│  │  ├─ api.md
│  │  ├─ invariants.md
│  │  └─ glossary.md
│  ├─ en/                      # 英文发布（镜像）
│  │  ├─ whitepaper.md
│  │  ├─ api.md
│  │  ├─ invariants.md
│  │  └─ glossary.md
│  └─ commons/
│     ├─ diagrams/
│     ├─ tables/
│     └─ snippets/
├─ EIP-DRAFT/
│  └─ eip-nesp.md
├─ L10N/
│  ├─ mapping.yml
│  ├─ status.md
│  └─ rules.md
├─ CONTRACTS/
│  ├─ NESP.sol                  # 占位（无代码）
│  └─ interfaces/INESP.sol
├─ TESTS/
│  ├─ README.md (占位)
│  └─ …
├─ EXAMPLES/
│  ├─ zh/minimal-flow.md
│  ├─ en/minimal-flow.md
│  └─ settlement_typed_data.json
├─ LICENSES/
│  ├─ CC0.txt
│  └─ MIT.txt
└─ SECURITY.md
```

贡献指南
- 任何影响协议语义的改动，首先更新白皮书（SPEC/nesp-whitepaper.md），并同步 EIP 草案（EIP-DRAFT/eip-nesp.md）。
- 新增/修改事件、状态或不变式，请一并更新示例与测试占位文档。
