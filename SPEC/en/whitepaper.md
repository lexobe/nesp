# A2A No-Arbitration Escrow Settlement Protocol (NESP) Whitepaper
Subtitle: Trust-Minimised · Timed Disputes · Symmetric Forfeiture Deterrence · Zero Protocol Fees

## Edition Notes
- This whitepaper is a self-contained, reproducible document. All definitions, criteria, and metrics are scoped inside the text without relying on external references.
- The whitepaper is the single source of normative semantics. It contains the complete rule set, interfaces, and metric definitions.

## 1. Abstract
As the internet evolved, permissionless creation, publication, and exchange proved essential for sustained growth. Yet unconstrained freedom can slide into a “bad money drives out good” wilderness. To avoid falling from freedom into disorder, an agent-to-agent (A2A) settlement substrate must stay neutral, arbitration-free, and self-reinforcing. “No arbitration” means the settlement core refuses discretionary judgement and centralised outcomes while committing to zero protocol fees. “Self-reinforcing cooperation” means rational participants find collaboration and compromise to be their dominant strategy; the game is designed so that delay, extortion, and deceit yield no marginal benefit—or even incur losses.

NESP delivers precisely that substrate: **negotiate off-chain, enforce on-chain. Symmetric forfeiture acts as the deterrent that pushes parties toward maximum cooperation, and the zero-fee pledge keeps the protocol neutral and sustainable.**

### 0.1 Core Flow (Quick Guide, Non-Normative)
- Step 1 Escrow: the buyer deposits the payable amount into escrow (E).
- Step 2 Delivery: the seller accepts the order and completes the work or ships the goods.
- Step 3 Approval & Full Payout (no dispute): the buyer approves the delivery and the protocol releases the entire escrow (E) to the seller.
- Step 4 Raise Dispute (optional): either party raises a dispute within the configured window.
- Step 5 Negotiated Settlement: during the dispute window the parties agree on a settlement amount A (A ≤ E); the contract pays A to the seller and refunds the remainder to the buyer.
- Step 6 Timeout Deterrence: if no agreement is reached by the deadline, the entire escrow is forfeited symmetrically. The funds move into the ForfeitPool, default to remain inside the protocol, and may later be withdrawn via governance for protocol fees; any other use requires an explicit community mandate.

Note: This subsection is a reading aid. Chapters 3–6 (state machine, invariants, security, interfaces, and events) are normative. Anchor hints in this overview are non-normative.

## 1. Principles (Design Principles)

### 1.1 Minimal Enshrinement
- Constraint: the settlement core must avoid discretion and value judgements. It MUST NOT enshrine arbitration, voting, or restaking dependencies. The chain stores only the verifiable minimum: order state, monetary amounts (A ≤ E, E is non-decreasing), verifiable triggers, and consistent time windows.
- Boundary: identity, reputation, allocation, or mission-specific logic belongs to the application layer. When used, account abstraction / trusted relays (AA/2771/4337) act purely as call channels—they cannot alter monetary or timing semantics.
- Prohibited: embedding “who is right” logic on-chain, deducting protocol-level fees, or using governance votes to determine settlement outcomes.

### 1.2 Credible Neutrality
- Constraint: deterministic windows, symmetric rules, and open events allow anyone to replay history for audit.
- Evidence: publicly consistent monetary/time semantics and minimal event fields make results verifiable even for non-trusting observers.

### 1.3 Zero Protocol Fees
- Constraint: the settlement contract MUST NOT deduct any protocol fee from escrow E or settlement A. Participants only pay network gas.
- Evidence: zero-fee violations MUST remain at zero; any detected deduction MUST revert.
- Disclosure: external fees (wallet relays, batching, bridge spreads, routing premiums) may be disclosed but sit outside protocol semantics.

### 1.4 Verifiable & Replayable
- Minimal evidence set:
  - Signature commitments use structured signatures (EIP-712/EIP-1271). The domain MUST include {orderId, tokenAddr, amount, chainId, nonce, deadline} to prevent cross-order / cross-chain replay; wrong domain, wrong contract, or expired deadline MUST revert.
  - Monetary invariants: E is non-decreasing, A ≤ E.
  - Trigger families: define verifiable “cannot reach agreement” signals. Timeout is normative; inconsistent signatures, minimum verifiability failures, or handshake breakdowns are informative additions.
  - Clocks & windows: unified time semantics and expiry judgements so any third party can replay execution paths.

### 1.5 Alignment with the A2A Lifecycle
- Principle: settlement adapts to the messaging semantics of the A2A workflow without reshaping them. Provide a clear mapping from application messages to settlement actions, and from settlement events back to threads or conversations.
- Call paths: direct calls and gas-sponsored or relayed calls must record provenance (`via`) for auditability. Call channels MUST NOT modify settlement semantics.

### 1.6 Phased Opening with Guardrails
- Thresholds: the unified parameter set {W, θ, β, τ} governs acceptance checks and operational gates (windows, forfeiture ceiling, acceptance floor, settlement P95 cap) with explicit versioning.
- Actions: quotas, clearing cycles, buffers, and circuit breakers execute at the application layer; the core contract remains unchanged.
- Goal: maintain determinism, reproducibility, traceability, and rollback capability as adoption grows, preventing a slide back to discretionary control.

## 2. Model & Notation (A ≤ E Semantics)

### 2.1 Participants & Information Structure
- Participants: Client (buyer) and Contractor (seller).
- Public information: order state, timestamps, escrow value E, events, and logs.
- Private information: V (buyer value), C (seller cost), subjective quality signals.

### 2.2 Time & Timers
- Absolute anchors: `startTime`, `readyAt`, `disputeStart`—set once and never rewound.
- Relative windows: `D_due`, `D_rev`, `D_dis` (seconds). `D_due` and `D_rev` may extend monotonically; `D_dis` is fixed once set.

### 2.3 Amounts & Units
- `E` (escrow amount): non-decreasing and only increased through `depositEscrow`.
- `A` (settlement amount actually released): constrained by `0 ≤ A ≤ E` measured at settlement time.
- Units: monetary values use the smallest unit of the asset; time uses `block.timestamp` (seconds).

### 2.4 Terms & Symbols (Informative)
- `V`: buyer value; `C`: seller cost.
- `κ(t)`: availability/state coefficient (Executing ∈ [0,1]; Reviewing/Disputing = 1).
- `R(t)` / `I(t)`: seller opportunity return / buyer sunk cost.

### 2.5 Assets & Tokens
- `tokenAddr` identifies the asset (ERC-20 or a sentinel for native ETH).
- ETH: deposit entry points are `payable` and MUST satisfy `msg.value == amount`; withdrawals use `call` and are `nonReentrant`.
- ERC-20: `msg.value == 0`; use SafeERC20 `transferFrom` and credit only upon success.
- Recommendation: support a WETH adapter layer as an engineering choice, but the normative spec MUST support native ETH.

### 2.6 Parameter Negotiation & Bounds (Normative)
- Negotiation scope & timing: `E`, `D_due`, `D_rev`, `D_dis` are agreed per order between Client and Contractor. Implementations MUST persist them at order creation/acceptance.
- Defaults: if `dueSec/revSec/disSec` are passed as 0, use protocol defaults `D_due = 1d = 86_400s`, `D_rev = 1d = 86_400s`, `D_dis = 7d = 604_800s`; store and emit the effective values.
- Mutation rules: `E` may only increase; `D_due/D_rev` may extend monotonically before a dispute; `D_dis` is immutable once set.
- Finiteness: all three MUST be finite and greater than zero. To resist chain reorgs, enforce `D_dis ≥ 2 · T_reorg` (deployment-specific estimate).
- Zero-value convention: only creation entry points may take 0 as “use default”; persisted fields and other entry points MUST NOT hold zero.

### 2.7 “Cannot Reach Agreement” Triggers (Normative & Informative)
- Normative trigger (sole): timeout expiry. WHEN `state = Disputing` AND `now ≥ disputeStart + D_dis`, `timeoutForfeit` MAY advance the state to `Forfeited`.
- Informative / optional triggers (non-normative): missing or conflicting signatures, minimum verifiability failures, handshake breakdowns, etc. These support product diagnostics or external governance, but DO NOT enter contract guards or state transitions. Strong warning: informative triggers are for analysis only.

## 3. State Machine & Guards

### 3.1 Allowed Transitions (No Others)
- E1 `Initialized -acceptOrder-> Executing` (actor: contractor).
- E2 `Initialized -cancelOrder-> Cancelled` (actor: client or contractor).
- E3 `Executing -markReady-> Reviewing` (actor: contractor).
- E4 `Executing -approveReceipt-> Settled` (actor: client).
- E5 `Executing -raiseDispute-> Disputing` (actor: client or contractor).
- E6 `Executing -cancelOrder-> Cancelled` (actor: client).
- E7 `Executing -cancelOrder-> Cancelled` (actor: contractor).
- E8 `Reviewing -approveReceipt-> Settled` (actor: client).
- E9 `Reviewing -timeoutSettle-> Settled` (actor: anyone).
- E10 `Reviewing -raiseDispute-> Disputing` (actor: client or contractor).
- E11 `Reviewing -cancelOrder-> Cancelled` (actor: contractor).
- E12 `Disputing -settleWithSigs-> Settled` (actor: counterparty—client or contractor).
- E13 `Disputing -timeoutForfeit-> Forfeited` (actor: anyone).

### 3.2 State-Invariant Actions (SIA)
- SIA1 `extendDue(orderId, newDueSec)` (client only) requires `newDueSec > current D_due` (strict extension).
- SIA2 `extendReview(orderId, newRevSec)` (contractor only) requires `newRevSec > current D_rev` (strict extension).
- SIA3 `depositEscrow(orderId, amount)` (`payable`) requires `amount > 0` and credits `escrow += amount`. Caller may be any address:
  - If the deployment configures trusted paths (e.g., 2771/4337), resolve the business subject `subject` accordingly and ensure `subject == client`, otherwise revert with `ErrUnauthorized`.
  - Other addresses count as unconditional gifts and bear the forfeiture risk; rights and obligations of the order do not change. The caller must provide or approve the assets as appropriate.
- Guard order: if `state ∈ {Disputing}` → `ErrFrozen`; if `state ∈ {Settled, Forfeited, Cancelled}` → `ErrInvalidState`; otherwise proceed to monetary/asset checks.
- Asset semantics: for ETH orders, require `msg.value == amount`; for ERC-20 orders, require `msg.value == 0`, set `payer ≡ subject`, and credit only after `SafeERC20.transferFrom(payer, address(this), amount)` succeeds. On trusted paths `payer = client`; on gifts the caller is the payer and must have prior approval.
- Applicability: SIA3 is allowed while the order is `Initialized`, `Executing`, or `Reviewing`. Deposits are forbidden in `Disputing` or any terminal state.

### 3.3 Guards & Side Effects
- Parameter persistence: persist `D_due/D_rev/D_dis` at order creation/acceptance. Do not rely on implicit defaults.
- One-time anchors: `startTime/readyAt/disputeStart` transition only from unset → set once.
- Resolved subject: direct call ⇒ `subject = msg.sender` (`via = address(0)`). When a deployment supports trusted forwarding, it MUST define `subject` per the chosen scheme (e.g., 2771 ⇒ `_msgSender()`, 4337 ⇒ `userOp.sender`).
- Subject constraints (MUST):
  - `markReady`, `extendReview`: `subject == contractor`.
  - `approveReceipt`, `extendDue`: `subject == client`.
  - `raiseDispute`, `settleWithSigs`: `subject ∈ {client, contractor}`.
  - `cancelOrder`: enforce `subject == client` for G.E6, `subject == contractor` for G.E7/G.E11.
  - `timeoutSettle`, `timeoutForfeit`: any address may call.
  - G.E12: `settleWithSigs` requires `state = Disputing`, `amountToSeller ≤ E`, and valid EIP-712/1271 signatures, nonce, and deadline.
- G.E1: `acceptOrder` only in `state = Initialized`; resolved subject MUST equal the order’s `contractor` or revert `ErrUnauthorized`. Side effect: `startTime = now`.
- G.E3: `markReady` only when `now < startTime + D_due`; side effect: `readyAt = now` and start `D_rev`.
- G.E4/E8: `approveReceipt` applies only to `state ∈ {Executing, Reviewing}`.
- G.E9: `timeoutSettle` only when `state = Reviewing` AND `now ≥ readyAt + D_rev`.
- G.E5/E10: `raiseDispute` may be invoked in Executing/Reviewing; side effect: `disputeStart = now`. Once in Disputing, escrow E is frozen and any deposit MUST revert (`ErrFrozen`).
- G.E11: contractor `cancelOrder` only when `state = Reviewing`.
- G.E13: `timeoutForfeit` only when `state = Disputing` AND `now ≥ disputeStart + D_dis`; side effect: transition to Forfeited, credit the escrow amount into the ForfeitPool balance, and leave the assets under governance custody for potential authorised withdrawals.
- G.E6: client `cancelOrder` only when `readyAt` is unset AND `now ≥ startTime + D_due`.
- G.E7: contractor `cancelOrder` is permitted (no further guards).

### 3.4 Terminal Constraints
- `Settled`, `Forfeited`, and `Cancelled` are absorbing states. Once reached, further state changes or monetary adjustments are forbidden. Only withdrawal entry points may read and claim already credited balances.

## 4. Settlement & Invariants (Pull Semantics)

### 4.1 Monetary Calculations
- INV.1 Full settlement: `amountToSeller = escrow` (approve/timeout paths).
- INV.2 Negotiated settlement: `amountToSeller = A` with `0 ≤ A ≤ escrow` (signature path).
- INV.3 Refund: `refundToBuyer = escrow − amountToSeller` when `A < escrow`.

### 4.2 Fund Safety
- INV.4 Single credit: each order credits payout/refund into aggregate balances at most once (single_credit) to avoid double-counting withdrawable amounts.
- INV.5 Idempotent withdrawal: read and zero the credited balance before transfer; repeated calls observe zero and have no side effects.
- INV.6 Timeout precedence: entry points MUST prioritise `timeout*` operations when overdue to block delay attacks.
  - Audit criterion: if an entry runs while timeout conditions hold (e.g., `now ≥ readyAt + D_rev` or `now ≥ disputeStart + D_dis`), it MUST yield the relevant timeout result or revert with an expiry error. Failing to do so violates this invariant.
- INV.7 Asset reconciliation: combine SafeERC20 with balance delta checks. If non-standard tokens (fee-on-transfer, rebase, freezing) cannot satisfy `post - pre == amount`, revert with `ErrAssetUnsupported`.

(Informative) Non-standard ERC-20 reconciliation pseudocode
```
function _safeTransferIn(token, payer, amount) internal {
    uint256 pre = IERC20(token).balanceOf(address(this));
    SafeERC20.safeTransferFrom(IERC20(token), payer, address(this), amount);
    uint256 post = IERC20(token).balanceOf(address(this));
    if (post - pre != amount) revert ErrAssetUnsupported();
}
```
Note: for fee-on-transfer, rebase, pausable, or freezable assets, if the equality `post - pre == amount` cannot hold, the call MUST fail explicitly.

### 4.3 Fund Destination & Compatibility
- INV.8 Forfeiture destination: `escrow → ForfeitPool` (governance-controlled withdrawals). The ForfeitPool is a logical account; forfeited assets stay in the contract balance by default and may only be withdrawn through `withdrawForfeitPool` after validating governance authorisation (governance contract/Timelock/Snapshot proof), with `amount ≤ forfeitPoolBalance`. Each withdrawal MUST emit `ForfeitPoolWithdrawn` including `governanceRef` (the decision handle) and `reasonHash` (purpose fingerprint). ETH and ERC-20 share identical semantics and must not burn additional value.
- INV.9 Ratio settlement (optional): `amountToSeller = floor(escrow * num / den)` with the remainder refunded to the buyer. Implementations MUST use safe “mulDiv down” or equivalent overflow-safe logic; any overflow/underflow MUST revert. No rounding up or precision adjustments.
- INV.10 Pull semantics: state changes only credit claimable balances (`balance[token][addr]`). Actual transfers occur solely via `withdraw(token)`. State-changing entry points MUST NOT transfer value inline.
- INV.11 One-shot anchors: once `startTime/readyAt/disputeStart` are set, they MUST NOT be modified or rewound.
- INV.12 Timer rules: `D_due/D_rev` may extend monotonically (before entering Disputing); `D_dis` is fixed and inextensible.
- INV.13 Unique mechanisms: non-dispute paths always settle the full escrow; dispute paths settle via signed amounts. Monetary semantics always respect `A ≤ E`; the contract records only escrow and settlement figures.
- INV.14 Zero-fee identity: every settlement/forfeiture satisfies `escrow_before = amountToSeller + refundToBuyer` (or equals the forfeited amount). Any violation MUST revert with `ErrFeeForbidden`.

#### Audit Tips (Informative)
- HOW (≤3):
  1) For forfeiture paths, group by `tokenAddr` and verify “contract balance delta = Σ(Forfeited.amount)” with no subsequent `BalanceCredited/BalanceWithdrawn` outflow.
  2) Confirm per-order `owed/refund` fields clear to zero.
  3) Apply identical balance + event checks for ETH and ERC-20.
- WHAT: forfeited assets remain inside the contract until an authorised governance withdrawal occurs; cross-check `ForfeitPoolWithdrawn` events, `governanceRef`, and contract balance deltas to confirm legitimacy.

## 5. Security & Threat Model

### 5.1 Signatures & Replay
- Use EIP-712/EIP-1271. The domain MUST include `{chainId, contract, orderId, tokenAddr, amountToSeller (=A), proposer, acceptor, nonce, deadline}`.
- Enforce `amountToSeller ≤ E`; the `nonce` scope is at least `{orderId, signer}` and consumes once; `deadline` evaluates against `block.timestamp`.
- Prevent cross-order, cross-contract, and cross-chain replay.

(Informative) EIP-712 TypedData sample (excerpt)
```
{
  "types": {
    "EIP712Domain": [
      {"name":"name","type":"string"},
      {"name":"version","type":"string"},
      {"name":"chainId","type":"uint256"},
      {"name":"verifyingContract","type":"address"}
    ],
    "Settlement": [
      {"name":"orderId","type":"uint256"},
      {"name":"tokenAddr","type":"address"},
      {"name":"amountToSeller","type":"uint256"},
      {"name":"proposer","type":"address"},
      {"name":"acceptor","type":"address"},
      {"name":"nonce","type":"uint256"},
      {"name":"deadline","type":"uint256"}
    ]
  },
  "primaryType": "Settlement",
  "domain": {
    "name": "NESP",
    "version": "1",
    "chainId": 1,
    "verifyingContract": "0x0000000000000000000000000000000000000000"
  },
  "message": {
    "orderId": 1,
    "tokenAddr": "0x0000000000000000000000000000000000000000",
    "amountToSeller": 1000000,
    "proposer": "0x0000000000000000000000000000000000000001",
    "acceptor": "0x0000000000000000000000000000000000000002",
    "nonce": 7,
    "deadline": 1924992000
  }
}
```

### 5.2 Error Mapping (Unified)
- `ErrInvalidState`, `ErrExpired`, `ErrBadSig`, `ErrOverEscrow`, `ErrFrozen`, `ErrFeeForbidden`, `ErrAssetUnsupported`, `ErrReplay`, `ErrUnauthorized`.

### 5.3 Call Order & Reentrancy
- Withdrawals are `nonReentrant` and follow the checks-effects-interactions (CEI) pattern. Timeout entry points run before other actions when overdue. Withdrawals use `call` and MUST check return values.
- CEI scope (normative): apart from withdrawal and ERC-20 `transferFrom`, all state-changing entry points MUST NOT transfer value to or call untrusted contracts inline. Every entry point obeys “validate → mutate → interact”.

### 5.4 Time Bounds & Residual Risks
- Use a unified block timestamp. `D_due/D_rev` may only extend monotonically; `D_dis` stays fixed.
- Residual risk: a destructive adversary may push forfeiture-driven externalities. Mitigate with social-layer qualification, reputation, audits, and operational guardrails.
  - Observation → action binding: when anomalies emerge (e.g., soaring forfeiture rate, collapsing acceptance rate), apply §7.2 `SLO_T(W)` and follow the CHG:SLO-Runbook for pause/whitelist/rollback actions.

## 6. API & Events (Minimal Sufficient Set)

### 6.1 Functions (Minimal Set)
- `createOrder(tokenAddr, contractor, dueSec, revSec, disSec) -> orderId`: creates an order and fixes asset and timer anchors. Emits `OrderCreated`.
- `createAndDeposit(tokenAddr, contractor, dueSec, revSec, disSec, amount)` (payable): creates an order and immediately deposits `amount`. For ETH require `msg.value == amount`; for ERC-20 perform `transferFrom(subject, this, amount)`. Emits `OrderCreated` and `EscrowDeposited` in the same transaction.
- `depositEscrow(orderId, amount)` (payable): tops up escrow for the client or third-party gifts. Respects asset and freeze guards. Emits `EscrowDeposited`.
- `acceptOrder(orderId)`: contractor accepts the order, sets `startTime`, and emits `Accepted`.
- `markReady(orderId)`: contractor declares readiness, sets `readyAt`, starts the review window, and emits `ReadyMarked`.
- `approveReceipt(orderId)`: client approves delivery, triggers settlement, emits `Settled(actor = Client)`, and leads to `BalanceCredited` / refund bookkeeping.
- `timeoutSettle(orderId)`: any address may trigger full settlement after review expiry. Emits `Settled(actor = Timeout)` and subsequent `BalanceCredited`.
- `raiseDispute(orderId)`: enters Disputing for either party, records `disputeStart`, and emits `DisputeRaised`.
- `settleWithSigs(orderId, payload, sig1, sig2)`: during the dispute window, settles amount A via signatures (`A ≤ escrow`). Emits `AmountSettled` and the corresponding `BalanceCredited/Refund` (terminal state `Settled`).
- `timeoutForfeit(orderId)`: any address may trigger symmetric forfeiture after the dispute deadline. Emits `Forfeited`.
- `cancelOrder(orderId)`: client or contractor cancels according to guards G.E6/G.E7/G.E11. Emits `Cancelled`.
- `withdraw(tokenAddr)`: withdraws accumulated payouts or refunds (pull semantics, `nonReentrant`). Emits `BalanceWithdrawn`.
- `withdrawForfeitPool(to, tokenAddr, amount, governanceProof, reasonHash)`: governance-controlled withdrawal of forfeited funds. Validates the governance proof (e.g., Timelock execution, DAO proposal, Snapshot attestation), enforces `amount ≤ forfeitPoolBalance`, and emits `ForfeitPoolWithdrawn`.
- `getOrder(orderId) view`: read-only query returning `{client, contractor, tokenAddr, state, escrow, dueSec, revSec, disSec, startTime, readyAt, disputeStart}`.
- `withdrawableOf(tokenAddr, account) view`: read-only query exposing the aggregated withdrawable balance (Payout/Refund) for wallets and monitoring tools.
- `extendDue(orderId, newDueSec)`: client extends the performance window monotonically. Emits `DueExtended` with old/new values.
- `extendReview(orderId, newRevSec)`: contractor extends the review window monotonically. Emits `ReviewExtended` with old/new values.

### 6.2 Events (Minimal Fields)
- `OrderCreated(orderId, client, contractor, tokenAddr, dueSec, revSec, disSec, ts)`: emitted on creation, fixing roles and timing parameters.
- `EscrowDeposited(orderId, from, amount, newEscrow, ts, via)`: emitted after escrow top-up; records funding source and call channel.
- `Accepted(orderId, escrow, ts)`: emitted when the order enters Executing via acceptance; confirms current escrow and sets `startTime`.
- `ReadyMarked(orderId, readyAt, ts)`: emitted when the contractor marks readiness, entering Reviewing and persisting `readyAt`.
- `DisputeRaised(orderId, by, ts)`: emitted when entering Disputing, recording the initiator.
- `DueExtended(orderId, oldDueSec, newDueSec, ts, actor)`: emitted when the client extends the performance window (strictly increasing). `actor` MUST equal the order’s client.
- `ReviewExtended(orderId, oldRevSec, newRevSec, ts, actor)`: emitted when the contractor extends the review window (strictly increasing). `actor` MUST equal the order’s contractor.
- `Settled(orderId, amountToSeller, escrow, ts, actor)` with `actor ∈ {Client, Timeout}`: emitted for non-dispute settlement or review timeout.
- `AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce, ts)`: emitted when signatures agree on amount A.
- `Forfeited(orderId, ts)`: emitted when the dispute times out and forfeiture occurs.
- `Cancelled(orderId, ts, cancelledBy)` with `cancelledBy ∈ {Client, Contractor}`: emitted when an order is cancelled.
- `BalanceCredited(orderId, to, tokenAddr, amount, kind, ts)` with `kind ∈ {Payout, Refund}`: emitted when funds are credited to withdrawable balances.
- `BalanceWithdrawn(to, tokenAddr, amount, ts)`: emitted on successful withdrawals.
- `ForfeitPoolWithdrawn(governanceRef, to, tokenAddr, amount, reasonHash, ts)`: emitted on governance-authorised ForfeitPool usage; `governanceRef` points to the decision artefact and `reasonHash` fingerprints the intended purpose.

### 6.3 Authorisation & Provenance (optional trusted paths)
- `EscrowDeposited.via` defaults to `address(0)` for direct calls (`msg.sender == tx.origin`). Deployments MAY opt into trusted forwarding (e.g., ERC-2771 forwarders or ERC-4337 EntryPoints); when enabled, `via` captures the configured contract address.
- For each allowed forwarder/EntryPoint, record the address and ensure `isTrustedForwarder(via) = true` (2771) or `via == entryPoint` (4337). Other callers MUST revert with `ErrUnauthorized`.
- Multi-hop forwarding or nesting remains disallowed; detection MUST revert. On failed authorisation, revert without emitting `EscrowDeposited`.

#### Definitions & Observable Anchors (Supplementary, Non-Normative)
- “Multi-hop” refers to routing through multiple relay contracts within the same call path (beyond the trusted forwarder or configured EntryPoint). Any such chain MUST revert with `ErrUnauthorized`.
- Suggested artefacts:
  - Custom error signature: `ErrUnauthorized()` (optionally `ErrUnauthorized(address caller, address via)`).
  - Event topic example: `EscrowDeposited(uint256 orderId, address from, uint256 amount, uint256 newEscrow, uint256 ts, address via)` hashed with `keccak256` so auditors can detect missing events.

## 7. Observability & SLO (Public Audit)

### 7.1 Metrics (Definition / Unit / Window)
- MET.1 Settlement latency P95 and timeout trigger rate.
- MET.2 Withdrawal failure rate and retry rate.
- MET.3 Stranded balance levels.
- MET.4 Acceptance rate = `#AmountSettled / #DisputeRaised` (count the first `AmountSettled` per order).
- MET.5 Zero-fee violation count; target value = 0 (source: transactions reverting with `ErrFeeForbidden`).
- GOV.1 Terminal distribution (Settled / Forfeited / Cancelled).
- GOV.2 `A/E` baseline distribution, measured when entering Reviewing/Disputing.
- MET.6 Transition latency/throughput (non-terminal transitions such as E1/E3/E5/E10).
- GOV.3 Dispute duration distribution: windowed statistics (P50/P95/histogram) of `DisputeRaised.ts → Settled/Forfeited.ts` for orders that entered Disputing.
- GOV.4 ForfeitPool ledger: cumulative forfeitures, governance-authorised withdrawals, `reasonHash` fingerprints, and remaining balance sanity checks.

#### Counting & De-duplication Rules (Semantic Constraints)
- Once per order: `OrderCreated`, `Accepted`, `ReadyMarked`, `DisputeRaised`, `Settled`, `AmountSettled`, `Forfeited`, `Cancelled`.
- `BalanceCredited`: deduplicate by `kind ∈ {Payout, Refund}`—at most one per kind per order (max two credits per order).
- Repeatable events per order:
  - `EscrowDeposited` (multiple top-ups or gifts).
  - `BalanceWithdrawn` (withdrawals may repeat).
  - `DueExtended`, `ReviewExtended` (record each monotonic extension with before/after values).

#### Addition: GOV.3 Dispute Duration
- Definition: duration from `DisputeRaised.ts` to terminal `Settled/Forfeited.ts`.
- Unit / window: seconds; aggregate via windowed P50/P95/histograms.
- Scope: include Settled and Forfeited; exclude Cancelled.

### 7.2 SLO & Rollback Playbooks
- Predicate: `SLO_T(W) := (MET.5 = 0) ∧ (forfeit_rate ≤ θ) ∧ (acceptance_rate ≥ β) ∧ (p95_settle ≤ τ)`. Parameters `θ/β/τ` and window `W` are defined in change artefacts (e.g., CHG:SLO-Runbook).
- Actions: breaching the predicate triggers the pause/whitelist/rollback playbook. Exit template: once the predicate holds throughout window `W`, execute the defined stop/exit/rollback steps (default timezone UTC).

#### Analytical Methods (Informative, Non-Normative)
- Monotonicity checks, quantile or rank regression, breakpoint or DiD analysis, and outlier alerts assist investigation and alarms but DO NOT alter contract semantics.

## 8. Versioning & Change Management

### 8.1 Semantic Versioning
- Any change to the state machine, invariants, APIs, or metrics increments at least the minor version. Breaking changes bump the major version.

### 8.2 Change Tickets (CHG)
- Record impact radius (state machine → interfaces/events → invariants → metric chains), migration/rollback steps, and compatibility windows.

### 8.3 Compatibility Aliases (Informative)
- Reserved: to reduce integration breakage, minor release cycles may temporarily expose alias entry points with clear deprecation and removal timelines.

## 9. Outcomes & Properties (Game-Theoretic, Informative)

### 9.1 Definitions (R1–R4)
- R1 Payment non-inferiority: `E − A ≥ 0`; without dispute A = E; negotiated settlements satisfy A ≤ E.
- R2 Forfeiture is worse (common conditions): if `R(t) < A`, then seller payoff `A − R(t) > 0 ≥ −I(t)` and buyer payoff `V − A ≥ −E`.
- R3 Equilibrium path exists: when some `A ∈ (C, min(V, E)]` and `κ(Review/Dispute) = 1`, “deliver and settle” forms a subgame-perfect equilibrium path.
- R4 Top-up monotonicity: increasing `E` pushes the buyer’s preference from `forfeit/tie` toward `pay`.

### 9.2 Proof Sketch & Observability Anchors
- R1: follows directly from INV.1–3 and `A ≤ E`; observe via `Settled` and `Balance{Credited,Withdrawn}`.
- R2: seller prefers `A − R(t)` to forfeiture `−I(t)`; observe via `GOV.1` forfeiture rates and `MET.6` latency distributions.
- R3: bounded windows with `κ = 1` ensure finite termination; verify paths bounded by `D_due + D_rev + D_dis`.
- R4: `E` grows via `depositEscrow`; negotiation respects `A ≤ E`; observe via `GOV.2` (`A/E`) distribution and `EscrowDeposited` curves.

### 9.3 Counterexample Library (Informative)
- Mapping: Ex-1 → R1; Ex-2 → R3; Ex-3 → R4.

## 10. Effectiveness Criteria & Parameters

### 10.1 Predicate
- `Effectiveness(W) := (R1 ∧ R2 ∧ R3 ∧ R4) ∧ SLO_T(W) ∧ Δ_BASELINE(W) ≥ 0`.

### 10.2 Unified Parameter Table
- `W`: observation window (e.g., 7/14/30 days).
- `θ`: forfeiture-rate ceiling (`forfeit_rate ≤ θ`).
- `β`: acceptance-rate floor (`acceptance_rate ≥ β`).
- `τ`: settlement P95 latency cap (`p95_settle ≤ τ`).
- `f`: weighting function over success/forfeit/p95/acceptance. Record parameters and data sources in CHG artefacts (e.g., CHG:SLO-Runbook or Effective-Params) for versioning.

### 10.3 Evaluation Flow
- Validate `SLO_T(W)` first, then compute `Δ_BASELINE(W)`, and finally confirm evidence for R1–R4.

## 11. Baselines & Applicability

### 11.1 Comparable Metrics (Same Window / Source / Fields)
- `succ = #Settled / (#Settled + #Forfeited + #Cancelled)`.
- `forf = #Forfeited / (#Settled + #Forfeited + #Cancelled)`.
- `p95_settle` per metric definition.
- `acc` per metric definition.
- `Δ_BASELINE(W) = f(succ, forf, p95_settle, acc)_NESP − f(…)_Baseline`.

### 11.2 Selection Guidance
- Prefer NESP for subjective delivery or one-off exchanges requiring a minimal core, public auditability, zero protocol fees, partial settlement `A ∈ [0, E]`, and symmetric deterrence. Timed negotiation plus symmetric forfeiture is acceptable in this context.
- Prefer centralised escrow/arbitration (out of scope) when heavy evidence review, strong regulation/KYC, or platform fees and discretion are acceptable.
- Alternatives: atomic swaps or objective conditions → HTLC; high-frequency low-dispute flows → state channels; acceptable voted adjudication → decentralised arbitration (out of scope).

## 12. Engineering & Safety Guardrails

### 12.1 Minimal Engineering Checklist
- Implement the minimal interface, events, and errors defined in Chapter 6.
- Bind signature domains to order/asset/amount/deadline/chain identifiers/nonces; test cross-order, cross-chain, expired, and domain-mismatch failure paths.
- Pull/CEI/authorisation/replay controls: zero balances before transfer, enforce `nonReentrant`, perform authorisation checks, and record provenance.
- Non-standard assets: handle through adapter layers and whitelists; abnormal asset flows MUST fail explicitly.

### 12.2 Testing & Verification (Representative)
- Representative scenarios: dispute-free full settlement, signed negotiated settlement, timeout forfeiture. Cover A ≤ E, timer boundaries, pull/CEI behaviour, authorisation, and replay resistance.

## 13. Phased Opening & Governance

- Three penetration tiers (low/medium/high) determine monitoring focus, threshold parameters (W/θ/β/τ), and opening actions.
- Bridge or operational measures (quotas, clearing, buffers, circuit breakers) run at the application layer without modifying the core.
- Track parameters and changes via versioned records of windows/thresholds/weights and baseline data sources. Provide change tickets and rollback playbooks.

## 14. Risks & Residuals

- Behavioural externalities: sabotage, strategic oscillation, or failed negotiation leading to forfeiture-heavy periods.
- Technical & operational: MEV/order manipulation, non-standard asset precision or fees, spoofed authorisation on sponsorship paths.
- Mitigation & rollback: enforce guardrails (authorisation, freezes, windows), define SLO thresholds with pause/whitelist/rollback actions, and maintain auditability and reproducibility.

## 15. Operational & Baseline Artefact Binding (Mandatory in CHG)

- Effective-Params: `{ W, θ, β, τ, f, version, updated_at }`.
- Baseline-Data: `{ source, fields_map, window = W, version }`.
- SLO-Runbook: `{ thresholds_ref, runbook_uri, rollback_steps, contacts }`.

## 16. Appendices

### 16.1 Glossary & Symbols (Selection)
- `E` escrow amount; `A` settlement amount; `V` buyer value; `C` seller cost.
- `D_due/D_rev/D_dis` performance/review/dispute windows; `startTime/readyAt/disputeStart` anchors.
- `ForfeitPool` logical forfeiture account (defaults to protocol custody; withdrawals require governance authorisation).

### 16.2 Metric & Event Catalogue (Summary)
- Events: `OrderCreated`, `EscrowDeposited`, `Accepted`, `DisputeRaised`, `Settled`, `AmountSettled`, `Forfeited`, `Cancelled`, `Balance{Credited,Withdrawn}`, `ForfeitPoolWithdrawn`.

### 16.3 Game-Theory Appendix: Immediate Compromise as the Unique SPE (Informative)
Model & premises (verifiable):
- Finite dispute window: `D_dis` exists; failure to agree before expiry leads to `Forfeited`, with outside options `U_b^D = −E` for the buyer and `U_s^D = −C` for the seller (strictly worse outcomes).
- Offers & feasible set: parties alternate offers for `A ∈ [0, E]`. Buyer utility `U_b(A) = V − A`; seller utility `U_s(A) = A − C`, assuming `E ≥ C` and `V ≥ 0`.
- Waiting costs (at least one holds):
  - Discounting: per-round factors `δ_b, δ_s ∈ (0, 1)`; or
  - Hard deadline: finite alternating offers where the post-deadline outcome is forfeiture.
- Availability gating: before settlement, the buyer cannot irreversibly realise full `V` (e.g., key release, commit-reveal, access tokens) to prevent “take V then negotiate” external options.

Proposition (unique SPE: immediate compromise):
- Under these premises, the alternating-offer game has a unique subgame-perfect equilibrium (SPE) that settles at the earliest feasible round (“immediate compromise”).

Two-period illustration (explicit backward induction):
- Two rounds: buyer offers at t = 0; if rejected, seller offers at t = 1; rejection again ⇒ forfeiture at t = 2.
  1) Final round (t = 1): seller offers `A = E`, buyer accepts because `−E < V − E` for any `V ≥ 0`. Seller’s discounted continuation value is `δ_s · (E − C)`.
  2) Initial round (t = 0): to make the seller accept now rather than wait and propose `E`, the buyer offers the minimum acceptable `A* = C + δ_s · (E − C)`, satisfying `C < A* < E` (discounting yields an interior compromise).
- Backward induction fixes a unique acceptance threshold for every subgame, so the equilibrium path and `A*` are unique and immediate.

General cases (finite horizon / discounting ⇒ uniqueness & immediacy):
- Finite alternating offers with a deadline: backward induction yields unique acceptance thresholds, leading to immediate agreement at the earliest opportunity.
- Infinite horizon with discounting `δ_b, δ_s ∈ (0, 1)`: Rubinstein bargaining yields a unique SPE that also settles immediately. NESP’s forfeiture changes outside option values but preserves uniqueness.

Failure modes (boundaries & counterexamples):
- No discounting and infinite horizon (`δ_b = δ_s = 1`, no deadline): multiple SPEs exist; delay has no cost, so uniqueness and compromise disappear.
- Hard deadline without discounting: unique outcome but often “one-sided” (dominated by the last mover) rather than an interior compromise.
- Buyer already realises full `V`: if the buyer irreversibly captures full value before settlement, outside options can dominate partial agreement. Engineering measures must block this via availability gating.

Engineering mapping & parameter calibration (operational):
- Effective discount arises from capital cost `r` plus imminent failure/audit/congestion risk `λ`. Approximate `δ_eff ≈ exp(-(r + λ) · Δt)` for round interval `Δt`.
- Window guidance: choose `D_dis` plus notification/buffer policies so that `δ_eff < 1` holds materially during observation; avoid “infinite rounds / zero waiting cost” designs (e.g., disallow unbounded-frequency offers).
- Availability gating: use key escrow, encrypted delivery, or commit-reveal so the buyer’s payoff before settlement stays below the forfeiture outside option.

Notes & references (informative):
- Consistent with §9 “Outcomes & Properties”: bounded windows and `κ = 1` yield finite termination and favour rapid agreement.
- Classical alternating-offer equilibrium structure follows Rubinstein (1982, AER); this appendix gives intuition—see standard game-theory texts for full proofs.
- Metrics: MET.1/2/3/4/5/6 and GOV.1/2/3/4 with window/source versioning documented in CHG artefacts.

### 16.4 Trace Examples (State → Interface/Event → Invariant → Metric)
- Example 0: E3 (Executing → Reviewing via `markReady`) → `ReadyMarked` → anchor fixation → GOV.3 / time-path replay.
- Example 1: E4 (Executing → Settled via `approveReceipt`) → `Settled` → INV.1 → MET.1 / MET.3.
- Example 2: E12 (Disputing → Settled via `settleWithSigs`) → `AmountSettled` (terminal Settled) → INV.2 → MET.4.
- Example 3: E13 (Disputing → Forfeited via `timeoutForfeit`) → `Forfeited` → INV.8 → GOV.1 / GOV.3 (dispute duration).
- Example 4: Governance withdrawal (`withdrawForfeitPool`) → `ForfeitPoolWithdrawn` → INV.8 → GOV.4 (usage audit).

### 16.5 Goals-to-Clause Mapping (WHY → WHAT)

## Copyright & Licensing
- The zero-fee commitment applies at the contract layer. This whitepaper follows the licence terms in `LICENSES/CC0.txt`.
