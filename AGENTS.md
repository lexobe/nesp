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

## Security & Configuration Tips
- No secrets in repo; no env needed for docs
- Contracts (later): pull-based withdraw, CEI, nonReentrant, EIP-712/1271 checks, ERC-2771/4337 subject resolution
