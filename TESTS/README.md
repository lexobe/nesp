# 测试指南

- 工具：Foundry
- 样例：直通结清（无争议）、签名协商结清、争议超时没收
- 守卫：时间窗口与主体约束（E1–E13），终态清零与三笔记账守恒

## 运行所有测试

建议关闭远程签名查询，避免在部分 macOS 环境触发 SystemConfiguration 崩溃：

```
FOUNDRY_DISABLE_REMOTE_LOOKUPS=1 forge test
```

首次环境如需下载 solc，对网络有要求；此与 `FOUNDRY_DISABLE_REMOTE_LOOKUPS` 无冲突。

## CI

本仓库已配置 GitHub Actions（.github/workflows/ci.yml），在 push/PR 时自动执行：
- `forge build --sizes`
- `forge test -vvv`

并设置 `FOUNDRY_DISABLE_REMOTE_LOOKUPS=1` 以提高稳定性。
