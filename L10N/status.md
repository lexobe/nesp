# 翻译同步状态

- zh source commit: main@6e9bc40（2025‑10‑23）
- en equivalence: false（白皮书未同步，需对齐以下章节改动）
  - 受影响章节：§2.6（feeRecipient/feeBps + 全局验证器）、§4.1（BPS 取整与守恒引用 §2.3）、§5.1（EIP‑712 Domain/消息字段命名）、§6.1（API 与 payload 锚点、setFeeValidator）、§6.2（事件最小集与 via 说明）、§6.3（主体解析与审计：4337 MUST/2771/签名 MAY）、§12.1（验证器约束 MUST/SHOULD）
  - 动作：更新 `SPEC/en/whitepaper.md` 以保持语义等价；完成后将本项改为 true 并记录对应 commit。
- nespay-spec: 已更新 `SPEC/zh/nespay-spec.md`（P1/P2 修正）；`SPEC/en` 暂无对应文件，后续需新增并对齐（待办）
