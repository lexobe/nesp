// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {OrderState, BalanceKind, SettleActor} from "../core/Types.sol";

interface INESPEvents {
    event OrderCreated(
        uint256 indexed orderId,
        address indexed client,
        address indexed contractor,
        address tokenAddr,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec,
        address feeRecipient,
        uint16 feeBps
    );

    event EscrowDeposited(uint256 indexed orderId, address indexed from, uint256 amount, uint256 newEscrow, address via);
    event Accepted(uint256 indexed orderId, uint256 escrow);
    event ReadyMarked(uint256 indexed orderId, uint48 readyAt);
    event DisputeRaised(uint256 indexed orderId, address indexed by);
    event DueExtended(uint256 indexed orderId, uint48 oldDueSec, uint48 newDueSec, address actor);
    event ReviewExtended(uint256 indexed orderId, uint48 oldRevSec, uint48 newRevSec, address actor);
    event Settled(uint256 indexed orderId, uint256 amountToSeller, uint256 escrow, SettleActor actor);
    event AmountSettled(
        uint256 indexed orderId, address proposer, address acceptor, uint256 amountToSeller, uint256 nonce
    );
    event Forfeited(uint256 indexed orderId, address tokenAddr, uint256 amount);
    event Cancelled(uint256 indexed orderId, address cancelledBy);
    event BalanceCredited(uint256 indexed orderId, address indexed to, address tokenAddr, uint256 amount, BalanceKind kind);
    event BalanceWithdrawn(address indexed to, address tokenAddr, uint256 amount);
    event ProtocolFeeWithdrawn(address indexed tokenAddr, address to, uint256 amount, address actor);
    event FeeValidatorUpdated(address prev, address next);
}

