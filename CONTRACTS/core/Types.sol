// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

enum OrderState {
    Initialized,
    Executing,
    Reviewing,
    Disputing,
    Settled,
    Forfeited,
    Cancelled
}

enum BalanceKind {
    Payout,
    Refund,
    Fee
}

enum SettleActor {
    Client,
    Timeout,
    Negotiated
}

struct Order {
    address client;
    address contractor;
    address tokenAddr;
    OrderState state;
    uint48 dueSec;
    uint48 revSec;
    uint256 escrow;
    uint48 startTime;
    uint48 readyAt;
    uint48 disputeStart;
    uint48 disSec;
    address feeRecipient;
    uint16 feeBps;
}

