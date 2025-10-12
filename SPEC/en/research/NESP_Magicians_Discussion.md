# [DISCUSSION] NESP — No-Arbitration Escrow Settlement (Bounded Disputes · Symmetric Forfeiture · Zero Fees)

**Tags**: EIPs, ERC, escrow, dispute, symmetric-forfeit, zero-fee, 2771, 4337

> This draft mirrors `SPEC/en/whitepaper.md` (the SSOT). Function names, events, states, and invariants reference the whitepaper anchors (E.x / INV.x / MET.x).

---

## TL;DR

NESP (No-Arbitration Escrow Settlement Protocol) targets agent-to-agent (A2A) marketplaces and wallets that need credibly neutral, one-shot settlement without delegating judgement to multisigs or governance committees.

Key mechanics for those integrators:

1. **Bounded timers**: performance `D_due`, review `D_rev`, dispute `D_dis` (§2.2, §3.1) map to “work due”, “client confirmation”, “cool-off” messages in the A2A workflow.  
2. **Symmetric forfeiture (E13 / INV.8)**: when the dispute window lapses unresolved both parties lose the escrow, deterring stalemates without relying on arbiters.  
3. **Zero protocol fee (§1.3 / INV.14 / MET.5)**: every path keeps `escrow_before = payout + refund`, otherwise `ErrFeeForbidden`, so platforms add fees explicitly at a higher layer.  
4. **Pull settlement (INV.10)**: state transitions only credit balances; `withdraw` moves funds and carries `nonReentrant`, reducing external attack surface.

Lifecycle recap:  
`Initialized` → (E1) `Executing` → (E3) `Reviewing` → (E4/E9) `Settled` or (E5/E10) `Disputing` → (E12) `Settled` / (E13) `Forfeited`; guarded cancellations (E2/E6/E7/E11) stay available when preconditions fail.

---

## Motivation

- Centralised escrow relies on fee-taking arbiters; decentralised arbitration adds governance complexity.  
- Rollups and account abstraction (ERC-2771 / ERC-4337) favour **minimal, auditable escrow primitives** that integrate with wallets and marketplaces.  
- Prior Magicians A2A conversations (e.g., delegated execution controllers, account-bound agents) still lean on discretionary multisigs or governance overrides; this proposal explores the zero-arbitration, timer-enforced alternative.  
- NESP reframes “dispute authority” as “timer + collateral” deterrence. With INV.13 (unique pathways), cooperation dominates flawed strategies.

---

## Scope & Non-Goals

**In scope**
- Single escrow (ETH / ERC-20) for Client → Contractor one-shot deliveries.  
- Minimal functions / events / errors (§6.1 / §6.2) including 2771/4337 provenance guards (§6.3).  
- Observability metrics and SLO baseline (§7.1 / §7.2).

**Out of scope**
- Multi-stage milestones, baskets, arbitration/governance/rating systems.  
- Platform fees, revenue sharing, higher-layer risk controls (left to applications).

---

## State Machine (§3)

| Edge | Function | Key guard | Outcome | A2A message mapping |
|------|----------|-----------|---------|----------------------|
| E1 | `acceptOrder` | `state = Initialized`, subject = contractor | Enter `Executing`, set `startTime` | Contractor: “I’ve taken the job.” |
| E3 | `markReady` | `now < startTime + D_due` | Lock `readyAt`, enter `Reviewing` | Contractor: “Deliverable is ready / shipped.” |
| E4 / E9 | `approveReceipt` / `timeoutSettle` | `state ∈ {Executing, Reviewing}` / `now ≥ readyAt + D_rev` | Full payout (INV.1) | Client: “Looks good.” / Timer expiry without response. |
| E5 / E10 | `raiseDispute` | subject ∈ {client, contractor} | Freeze escrow, record `disputeStart` | Either side: “There’s a problem—pause the order.” |
| E12 | `settleWithSigs` | `A ≤ escrow`, dual signatures | Negotiated payout (INV.2 / INV.3) | Both parties sign a negotiated amount. |
| E13 | `timeoutForfeit` | `now ≥ disputeStart + D_dis` | Symmetric forfeiture (INV.8) | System: “Dispute expired—both lose escrow.” |
| E2 / E6 / E7 / E11 | `cancelOrder` | Guards G.E6 / G.E7 / G.E11 | Cancel the order | Either side aborts before commitment per guard. |

> Before any mutation, evaluate freeze / terminal guards: `state ∈ {Disputing}` → `ErrFrozen`; terminal states → `ErrInvalidState`.

---

## Minimal Interface (§6.1)

Normative function set (all entries observe CEI and pull semantics):

```
createOrder(tokenAddr, contractor, dueSec, revSec, disSec) -> orderId
createAndDeposit(tokenAddr, contractor, dueSec, revSec, disSec, amount) payable
depositEscrow(orderId, amount) payable
acceptOrder(orderId)
markReady(orderId)
approveReceipt(orderId)
timeoutSettle(orderId)
raiseDispute(orderId)
settleWithSigs(orderId, payload, sigClient, sigContractor)
timeoutForfeit(orderId)
cancelOrder(orderId)
withdraw(tokenAddr)
getOrder(orderId) view -> {client, contractor, tokenAddr, state, escrow, dueSec, revSec, disSec, startTime, readyAt, disputeStart}
withdrawableOf(tokenAddr, account) view -> uint256
extendDue(orderId, newDueSec)
extendReview(orderId, newRevSec)
```

Error set: `ErrInvalidState`, `ErrExpired`, `ErrBadSig`, `ErrOverEscrow`, `ErrFrozen`, `ErrFeeForbidden`, `ErrAssetUnsupported`, `ErrReplay`, `ErrUnauthorized` (§5.2).

2771 / 4337: resolve the business subject `subject` for all guards; write `via` into events (§6.3).

---

## Events & Observability (§6.2, §7)

Minimal events:
```
OrderCreated(orderId, client, contractor, tokenAddr, dueSec, revSec, disSec, ts)
EscrowDeposited(orderId, from, amount, newEscrow, ts, via)
Accepted(orderId, escrow, ts)
ReadyMarked(orderId, readyAt, ts)
DueExtended(orderId, oldDueSec, newDueSec, ts, actor)
ReviewExtended(orderId, oldRevSec, newRevSec, ts, actor)
DisputeRaised(orderId, by, ts)
Settled(orderId, amountToSeller, escrow, ts, actor)   // actor ∈ {Client, Timeout}
AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce, ts)
Forfeited(orderId, ts)
Cancelled(orderId, ts, cancelledBy)                   // cancelledBy ∈ {Client, Contractor}
BalanceCredited(orderId, to, tokenAddr, amount, kind, ts) // kind ∈ {Payout, Refund}
BalanceWithdrawn(to, tokenAddr, amount, ts)
```

Suggested public metrics (§7.1):
- `MET.1` settlement latency P95, `MET.4` negotiated acceptance rate, `MET.5` zero-fee violations (target 0).  
- `GOV.1` terminal distribution, `GOV.3` dispute duration.  
- Counting / dedupe rules follow §7.1.

SLO predicate (§7.2): `SLO_T(W) := (MET.5 = 0) ∧ (forfeit_rate ≤ θ) ∧ (acceptance_rate ≥ β) ∧ (p95_settle ≤ τ)`.

---

## Security Considerations (§5)

- **Signatures & replay**: `settleWithSigs` adopts an EIP-712/1271 domain `{chainId, contract, orderId, tokenAddr, amountToSeller, proposer, acceptor, nonce, deadline}` (§5.1).  
- **CEI & reentrancy**: no external calls inside state mutations except `withdraw` and ERC-20 `transferFrom`; `withdraw` is `nonReentrant` (§5.3).  
- **Timer rules**: `D_due/D_rev` may only extend before Disputing; `D_dis` is fixed (INV.12).  
- **Zero-fee enforcement**: breaking INV.14 must revert `ErrFeeForbidden`; monitor with `MET.5`.  
- **Non-standard assets**: if balance deltas mismatch transfer amount, revert `ErrAssetUnsupported` (INV.7).
- **Symmetric forfeiture & Sybil cost**: stalling yields the same loss as cooperation unless the attacker pre-funds both sides; escrow plus timers push rational sybils toward cooperation, but we invite mitigations (reputation, staking) for low-cost identity pools.

---

## Compatibility & Extensibility

- Assets: ETH / ERC-20 (native ETH must honour `msg.value`; ERC-20 uses SafeERC20).  
- Call provenance: direct, trusted forwarder (2771), EntryPoint (4337); multi-hop relays are forbidden.  
- Higher layers may add deposits, ratings, multi-milestone flows, provided they respect the core state machine and invariants.

---

## Open Questions

1. **Timer defaults**: preferred ranges and chain-specific minimum/maximum for `D_due`, `D_rev`, `D_dis`.  
2. **Timeout outcome**: should implementers be allowed to switch the default (e.g., refund instead of forfeit)?  
3. **Signature domain**: do we need optional fields such as `termsHash` or `deliveryHash`?  
4. **Observability**: is an aggregated `Outcome` event useful for indexers?  
5. **Multi-asset / multi-stage**: should we reserve hooks at the standard layer or stay minimal?
6. **Multi-agent A2A**: what is the right pattern for co-ops or squads that have >2 principals but still want no arbitration?  
7. **Reputation / Sybil guardrails**: which identity-cost primitives (SBT, staking, credit scoring) should the standard reference as recommended companions?

---

## References

- `SPEC/en/whitepaper.md` (canonical source)  
- `EIP-DRAFT/eip-nesp.md` (in-progress ERC skeleton)  
- `SPEC/commons` (planned state-machine diagrams)  
- `TESTS/` (planned Foundry / Hardhat harness)

---

## Next Steps

1. Collect Magicians feedback, documenting how it differs from prior A2A threads (delegated execution, account-bound agents) and fold accepted changes into `EIP-DRAFT/eip-nesp.md` (Rationale, Security, Open Issues).  
2. Publish a complementary game-theory note on ethresear.ch (drawing from §9 and §16.3) and cross-link both directions so readers can compare models.  
3. Work with wallet / marketplace / AA implementers to validate 2771/4337 flows, sample signatures, and event semantics, then publish test harness pointers.  
4. Capture recommended reputation / Sybil guardrail patterns in `SPEC/commons` once consensus emerges.

---

**Abstract**  
NESP defines a zero-fee, no-arbitration escrow settlement standard with bounded performance/review/dispute windows and symmetric forfeiture. The minimal interface (`createOrder`, `raiseDispute`, `settleWithSigs`, `timeoutForfeit`, etc.), event schema, invariants (`A ≤ E`, zero-fee identity), and AA-friendly provenance rules (2771/4337) are aligned with the SSOT whitepaper. Feedback is requested on timeout outcomes, timer bounds, optional signature fields, observability requirements, multi-agent variants, and recommended reputation / Sybil guardrails before the ERC draft advances.
