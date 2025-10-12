# 端到端最小流程（中文 · 占位）

- 创建订单 → 充值托管 → 承接 → 标记就绪 → 验收结清 → 提现
- 争议路径：发起争议 → settleWithSigs（EIP‑712） → 提现
- 超时路径：发起争议 → timeoutForfeit

TypedData 样例见 `EXAMPLES/settlement_typed_data.json`

