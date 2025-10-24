# Repository Guidelines

## Project Structure & Module Organization
- SPEC/zh: Chinese SSOT (canonical) — whitepaper.md, spec-full.md, game-theory.md, api.md, invariants.md, glossary.md
- SPEC/en: English publication mirrors (keep semantics equivalent to zh)
- SPEC/commons: shared diagrams/tables/snippets for both languages
- EIP-DRAFT/eip-nesp.md: English ERC draft (EIP-1 style) mapped from SPEC/en
- CONTRACTS: Solidity reference (placeholders now) — NESP.sol, interfaces/INESP.sol
- TESTS: test config and suites (placeholder)
- EXAMPLES: zh/en minimal flows and settlement_typed_data.json
- L10N: translation mapping/status/rules; LICENSES: CC0 (text), MIT (code)

## Build, Test, and Development Commands
- Docs preview: open SPEC/zh/whitepaper.md or SPEC/en/whitepaper.md
- List tracked files: `git ls-tree -r --name-only HEAD`
- Search spec anchors: `rg "E[0-9]+|INV\.[0-9]+|EVT\.|MET\.|GOV\." SPEC/zh`
- Optional: Foundry tests `forge test`; Hardhat tests `npx hardhat test` (after adding tool configs)

## Coding Style & Naming Conventions
- Dirs: UPPERCASE at top level (SPEC, EIP-DRAFT, CONTRACTS, TESTS, EXAMPLES, LICENSES, L10N)
- Solidity (when added): 4-space indent, SPDX header, pragma ^0.8.x; functions camelCase, events PascalCase, errors PascalCase (ErrX)
- EIP text: follow EIP-1 in EIP-DRAFT/eip-nesp.md; license CC0
- Specs: SPEC/zh is canonical; SPEC/en mirrors; shared tables/diagrams in SPEC/commons

## Testing Guidelines
- Framework: Foundry (preferred) or Hardhat
- Names: `TESTS/NESP.t.sol`, `TESTS/NESP.spec.ts`
- Coverage: `forge coverage` or `npx hardhat coverage`
- Must test: A<=E, zero-fee conservation, timeout precedence, dispute signatures, pull-withdraw idempotence

## Commit & Pull Request Guidelines
- Commits: imperative, concise; optional scope prefix (docs:, chore:, refactor:)
- PRs: link issues, describe changes, note impacted spec sections (E.x/INV.x/EVT.x), add before/after for events/anchors, keep diffs small
- Bilingual flow: update SPEC/zh first, then sync SPEC/en; record in `L10N/status.md`

## Review Workflow（RWO）
- 采用 RWO v1.9（Recursive · WHW · Only），默认模式为 Deep-Dive；信息性段落在标题处注明即可跳过评审。
- 保持固定输出顺序：`TL;DR → 一页表 → 第一性分解 → 缺口与风险 → 修复集 → 验证计划 → 未决问题 → 证据与引用`。
- 对枚举/表格型内容（函数、事件、守卫）视为“列举检查”，不用强行压缩到 ≤3 步；引用外部工件时提供具体路径或仓库位置即可。
- 快速校验提醒：信息性段落加注“不计入规范评审”；多守卫/事件可用脚本批量校验；缺口真属红线时才升 P0。

## Expert Personas
- 详细角色说明存放于 `.claude/experts/`（如 `blade.md`, `bob.md`, `glen.md`, `nenade.md`, `tim.md`, `vitalik.md`, `vale.md`）。
- 根据评审场景选择 Persona，触发短句示例：`使用白隼：Deep-Dive`、`召唤 Bob：平台工程评审`、`召唤 Vale：合约审计 Deep-Dive` 等。
- 产出需与 Persona 约定保持一致（结构、口吻、评分项等）；如需切换，先在评论中声明新的 Persona 与模式。

## Security & Configuration Tips
- No secrets in repo; no env needed for docs
- Contracts (later): pull-based withdraw, CEI, nonReentrant, EIP-712/1271 checks, and (if using meta-transactions) ERC-2771/4337 subject resolution
