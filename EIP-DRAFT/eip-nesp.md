# ERC: No-Arbitration Escrow Settlement Protocol (NESP)

1. Preamble

- EIP: TBA  
- Title: ERC: No-Arbitration Escrow Settlement Protocol (NESP)  
- Author(s): TBA  
- Status: Draft  
- Type: Standards Track (ERC)  
- Category: ERC  
- Created: 2025-10-09  
- Requires: ERC-20, ERC-712, ERC-2771, ERC-4337 (informative)  
- Replaces: None  
- License: CC0-1.0

2. Abstract

This proposal standardises a trust-minimised escrow settlement protocol for agent-to-agent (A2A) transactions. Buyers deposit funds into a smart-contract escrow before delivery. Sellers accept, fulfil, and can request settlement. If both parties agree, the escrow is released in full. If a dispute occurs, the parties negotiate an amount off-chain and co-sign a settlement message; otherwise, the escrow is forfeited symmetrically after a fixed dispute window. The protocol enforces zero protocol fees (gas only), supports third-party gifting/top-ups, and emits auditable events for monitoring and service-level objectives (SLOs).

3. Motivation

Centralised escrow platforms introduce counterparty risk, custodial control, fees, and discretionary adjudication. Decentralised arbitration frameworks add governance complexity and require L1 social consensus. NESP provides a minimal on-chain core: escrow accounting, limited-time dispute resolution, and symmetric forfeiture.

4. Specification

4.1 Terminology & Roles

- Client: buyer funding the escrow.  
- Contractor: seller delivering the agreed work/goods.  
- Resolved Subject: the business-level caller resolved from a transaction (direct `msg.sender`, `ERC2771` `_msgSender()`, or `ERC4337` `userOp.sender`).  
- Escrow (E): total funds deposited for the order, denominated in ETH or an ERC-20 token.  
- Settlement Amount (A): amount released to contractor after settlement (`0 ≤ A ≤ E`).  
- ForfeitPool: logical bucket holding forfeited escrow (remains in contract balance; never redistributed).  
- States: Initialized, Executing, Reviewing, Disputing, Settled, Forfeited, Cancelled.  
- Timers: absolute anchors (startTime, readyAt, disputeStart) and configurable windows (D_due, D_rev, D_dis).

... (Trimmed for brevity; see SPEC/zh/whitepaper.md for normative details. License: LICENSES/CC0.txt)
