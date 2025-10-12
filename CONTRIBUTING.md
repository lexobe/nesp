Contributing Guidelines (NESP)

Scope
- This repo hosts the NESP spec (SSOT), ERC-facing draft, and surrounding materials (whitepaper, references). Reference code and tests may be added under `contracts/` and `test/`.

Single Source of Truth (SSOT)
- Canonical semantics live in `docs/zh/nesp_spec.md` (Chinese). Keep `nesp_erc.md` in sync semantically (English ERC draft).
- Non-normative docs (whitepaper, game analysis) must not change protocol invariants.

How to Propose Changes
1) Open an issue describing the change, motivation, and impact on:
   - State machine and guards
   - Invariants (INV.*) and zero-fee conservation
   - Events schema and observability (MET.*, GOV.*)
   - Timers/dispute windows
2) Submit a PR updating SSOT first, then mirror changes to `nesp_erc.md`.
3) If adding code/tests, place them in `contracts/` and `test/` with a short README.

ERC/EIP Process (high level)
- Follow the EIPs process: Idea → Draft → Review → Last Call → Final. The file here is a draft to be upstreamed to ethereum/EIPs.
- Keep the ERC interface minimal; implementation details remain informative.

PR Checklist
- [ ] SSOT updated (`docs/zh/nesp_spec.md`)
- [ ] ERC draft updated (`nesp_erc.md`)
- [ ] Invariants unchanged or explicitly revised with rationale
- [ ] Events and metrics documented
- [ ] Tests plan updated (`test/README.md`)

Coding Style (if adding Solidity)
- Prefer checks-effects-interactions, pull-based withdrawals, nonReentrant on `withdraw`.
- EIP-712 payloads include per-signer nonces and deadlines; support IERC1271.

