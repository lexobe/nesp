// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Order, OrderState, BalanceKind, SettleActor} from "./Types.sol";
import {INESPEvents} from "../interfaces/INESPEvents.sol";
import {IFeeValidator} from "../interfaces/IFeeValidator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NESPCore is INESPEvents {
    using SafeERC20 for IERC20;

    // Errors
    error ErrInvalidState();
    error ErrUnauthorized();
    error ErrFrozen();
    error ErrExpired();
    error ErrBadSig();
    error ErrReplay();
    error ErrOverEscrow();
    error ErrAssetUnsupported();
    error ErrZeroAmount();
    error ErrInsufficientForfeit();
    error ErrZeroAddress();
    error ErrSelfDealing();

    // Reentrancy guard
    uint256 private _locked = 1;
    error ErrReentrant();
    modifier nonReentrant() {
        if (_locked != 1) revert ErrReentrant();
        _locked = 2;
        _;
        _locked = 1;
    }

    // Removed onlyGovernance modifier due to via-IR compiler bug with vm.prank()
    // Using inline checks with assembly workaround instead

    // Config
    uint48 public constant DEFAULT_DUE_SEC = 86400; // 1d
    uint48 public constant DEFAULT_REV_SEC = 86400; // 1d
    uint48 public constant DEFAULT_DIS_SEC = 604800; // 7d
    address public constant ETH_ADDRESS = address(0);

    // Storage
    address public governance;
    address public feeValidator; // global fee validator (optional)
    uint256 public nextOrderId;
    mapping(uint256 => Order) internal _orders;
    mapping(address => mapping(address => uint256)) internal _balances; // token => user => amount
    mapping(address => uint256) public forfeitBalance; // token => amount
    mapping(uint256 => mapping(address => uint256)) public nonces; // orderId => signer => nonce

    // EIP-712
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant SETTLEMENT_TYPEHASH = keccak256(
        "Settlement(uint256 orderId,address tokenAddr,uint256 amountToSeller,address proposer,address acceptor,uint256 nonce,uint256 deadline)"
    );

    constructor(address _governance) {
        if (_governance == address(0)) revert ErrZeroAddress();
        governance = _governance;
        nextOrderId = 1;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("NESP"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    // Views
    function getOrder(uint256 orderId) external view returns (Order memory order) { return _orders[orderId]; }
    function withdrawableOf(address tokenAddr, address account) external view returns (uint256) {
        return _balances[tokenAddr][account];
    }

    // Create
    function createOrder(
        address tokenAddr,
        address contractor,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec,
        address feeRecipient,
        uint16 feeBps
    ) external returns (uint256 orderId) {
        orderId = _createOrder(tokenAddr, contractor, dueSec, revSec, disSec, feeRecipient, feeBps);
    }

    function _createOrder(
        address tokenAddr,
        address contractor,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec,
        address feeRecipient,
        uint16 feeBps
    ) internal returns (uint256 orderId) {
        if (contractor == address(0)) revert ErrZeroAddress();
        if (contractor == msg.sender) revert ErrSelfDealing();

        if (dueSec == 0) dueSec = DEFAULT_DUE_SEC;
        if (revSec == 0) revSec = DEFAULT_REV_SEC;
        if (disSec == 0) disSec = DEFAULT_DIS_SEC;

        // Creation-time fee validation
        if (feeRecipient != address(0) && feeBps > 0) {
            if (feeBps > 10_000) revert ErrUnauthorized(); // reuse; Spec suggests ErrFeeBpsTooHigh
            address v = feeValidator;
            if (v == address(0)) revert ErrUnauthorized();
            if (!IFeeValidator(v).validate(feeRecipient, feeBps)) revert ErrUnauthorized();
        }

        orderId = nextOrderId++;
        Order storage order = _orders[orderId];
        order.client = msg.sender;
        order.contractor = contractor;
        order.tokenAddr = tokenAddr;
        order.state = OrderState.Initialized;
        order.escrow = 0;
        order.dueSec = dueSec;
        order.revSec = revSec;
        order.disSec = disSec;
        order.feeRecipient = feeRecipient;
        order.feeBps = feeBps;

        emit OrderCreated(orderId, msg.sender, contractor, tokenAddr, dueSec, revSec, disSec, feeRecipient, feeBps);
    }

    function createAndDeposit(
        address tokenAddr,
        address contractor,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec,
        address feeRecipient,
        uint16 feeBps,
        uint256 amount
    ) external payable returns (uint256 orderId) {
        orderId = _createOrder(tokenAddr, contractor, dueSec, revSec, disSec, feeRecipient, feeBps);
        _depositEscrow(orderId, amount, msg.sender, address(0));
    }

    // Deposit
    function depositEscrow(uint256 orderId, uint256 amount) external payable {
        _depositEscrow(orderId, amount, msg.sender, address(0));
    }

    function _depositEscrow(uint256 orderId, uint256 amount, address from, address via) internal {
        Order storage order = _orders[orderId];
        if (amount == 0) revert ErrZeroAmount();
        if (
            order.state == OrderState.Disputing ||
            order.state == OrderState.Settled ||
            order.state == OrderState.Forfeited ||
            order.state == OrderState.Cancelled
        ) revert ErrFrozen();

        if (order.tokenAddr == ETH_ADDRESS) {
            require(msg.value == amount, "ETH mismatch");
        } else {
            require(msg.value == 0, "No ETH for ERC20");
            uint256 beforeBal = IERC20(order.tokenAddr).balanceOf(address(this));
            IERC20(order.tokenAddr).safeTransferFrom(from, address(this), amount);
            uint256 afterBal = IERC20(order.tokenAddr).balanceOf(address(this));
            require(afterBal - beforeBal == amount, "Transfer amount mismatch");
        }

        order.escrow += amount;
        emit EscrowDeposited(orderId, from, amount, order.escrow, via);
    }

    // State transitions
    function acceptOrder(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.state != OrderState.Initialized) revert ErrInvalidState();
        if (msg.sender != order.contractor) revert ErrUnauthorized();
        order.state = OrderState.Executing;
        order.startTime = uint48(block.timestamp);
        emit Accepted(orderId, order.escrow);
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        OrderState st = order.state;
        if (st == OrderState.Initialized) {
            if (msg.sender != order.client && msg.sender != order.contractor) revert ErrUnauthorized();
        } else if (st == OrderState.Executing) {
            if (msg.sender == order.client) {
                if (order.startTime == 0 || block.timestamp < order.startTime + order.dueSec) revert ErrInvalidState();
            } else if (msg.sender == order.contractor) {
                // contractor can cancel during Executing
            } else {
                revert ErrUnauthorized();
            }
        } else if (st == OrderState.Reviewing) {
            if (msg.sender != order.contractor) revert ErrUnauthorized();
        } else {
            revert ErrInvalidState();
        }

        order.state = OrderState.Cancelled;
        uint256 amount = order.escrow;
        if (amount > 0) {
            order.escrow = 0; // terminal clear
            _credit(orderId, order.client, order.tokenAddr, amount, BalanceKind.Refund);
        }
        emit Cancelled(orderId, msg.sender);
    }

    function markReady(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.state != OrderState.Executing) revert ErrInvalidState();
        // WP §3.3 G.E3: now < startTime + D_due (non-timeout path)
        if (block.timestamp >= order.startTime + order.dueSec) revert ErrExpired();
        if (msg.sender != order.contractor) revert ErrUnauthorized();
        order.state = OrderState.Reviewing;
        order.readyAt = uint48(block.timestamp);
        emit ReadyMarked(orderId, order.readyAt);
    }

    function approveReceipt(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.state != OrderState.Executing && order.state != OrderState.Reviewing) revert ErrInvalidState();
        if (order.state == OrderState.Reviewing && order.readyAt > 0) {
            if (block.timestamp >= order.readyAt + order.revSec) revert ErrExpired();
        }
        if (msg.sender != order.client) revert ErrUnauthorized();
        _settle(orderId, order.escrow, SettleActor.Client);
    }

    function raiseDispute(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.state != OrderState.Executing && order.state != OrderState.Reviewing) revert ErrInvalidState();

        // WP §3.3 G.E5: Executing state requires now < startTime + D_due (non-timeout path)
        if (order.state == OrderState.Executing && block.timestamp >= order.startTime + order.dueSec) {
            revert ErrExpired();
        }

        // WP §3.3 G.E10: Reviewing state requires now < readyAt + D_rev (non-timeout path)
        if (order.state == OrderState.Reviewing && block.timestamp >= order.readyAt + order.revSec) revert ErrExpired();

        if (msg.sender != order.client && msg.sender != order.contractor) revert ErrUnauthorized();
        order.state = OrderState.Disputing;
        order.disputeStart = uint48(block.timestamp);
        emit DisputeRaised(orderId, msg.sender);
    }

    function timeoutSettle(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.state != OrderState.Reviewing) revert ErrInvalidState();
        if (block.timestamp < order.readyAt + order.revSec) revert ErrInvalidState();
        _settle(orderId, order.escrow, SettleActor.Timeout);
    }

    function settleWithSigs(
        uint256 orderId,
        uint256 amountToSeller,
        address proposer,
        address acceptor,
        uint256 nonce,
        uint256 deadline,
        bytes calldata proposerSig,
        bytes calldata acceptorSig
    ) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.state != OrderState.Disputing) revert ErrInvalidState();
        // WP §3.3: Non-timeout path requires now < deadline (complement: check now >= deadline)
        if (block.timestamp >= deadline) revert ErrExpired();
        if (amountToSeller > order.escrow) revert ErrOverEscrow();

        // Verify proposer/acceptor are client/contractor (in any order)
        if (!((proposer == order.client && acceptor == order.contractor) ||
              (proposer == order.contractor && acceptor == order.client))) {
            revert ErrUnauthorized();
        }

        // Verify and consume nonce
        if (nonces[orderId][proposer] != nonce) revert ErrReplay();
        nonces[orderId][proposer]++;

        // Verify signatures
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                SETTLEMENT_TYPEHASH,
                orderId,
                order.tokenAddr,
                amountToSeller,
                proposer,
                acceptor,
                nonce,
                deadline
            ))
        ));

        if (!_verifySignature(digest, proposerSig, proposer)) revert ErrBadSig();
        if (!_verifySignature(digest, acceptorSig, acceptor)) revert ErrBadSig();

        // Emit before settlement to avoid stack issues
        emit AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce);

        _settle(orderId, amountToSeller, SettleActor.Negotiated);
    }

    function timeoutForfeit(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.state != OrderState.Disputing) revert ErrInvalidState();
        if (block.timestamp < order.disputeStart + order.disSec) revert ErrInvalidState();
        order.state = OrderState.Forfeited;
        uint256 amount = order.escrow;
        if (amount > 0) {
            order.escrow = 0; // terminal clear
            forfeitBalance[order.tokenAddr] += amount;
        }
        emit Forfeited(orderId, order.tokenAddr, amount);
    }

    // Window extensions
    function extendDue(uint256 orderId, uint48 newDueSec) external {
        Order storage order = _orders[orderId];
        if (msg.sender != order.client) revert ErrUnauthorized();
        if (order.state != OrderState.Executing) revert ErrInvalidState();
        if (newDueSec <= order.dueSec) revert ErrInvalidState();
        uint48 old = order.dueSec;
        order.dueSec = newDueSec;
        emit DueExtended(orderId, old, newDueSec, msg.sender);
    }

    function extendReview(uint256 orderId, uint48 newRevSec) external {
        Order storage order = _orders[orderId];
        if (msg.sender != order.contractor) revert ErrUnauthorized();
        if (order.state != OrderState.Executing && order.state != OrderState.Reviewing) revert ErrInvalidState();
        if (newRevSec <= order.revSec) revert ErrInvalidState();
        uint48 old = order.revSec;
        order.revSec = newRevSec;
        emit ReviewExtended(orderId, old, newRevSec, msg.sender);
    }

    // Withdrawals
    function withdraw(address tokenAddr) external nonReentrant {
        uint256 amount = _balances[tokenAddr][msg.sender];
        if (amount == 0) revert ErrZeroAmount();
        _balances[tokenAddr][msg.sender] = 0;
        if (tokenAddr == ETH_ADDRESS) {
            (bool ok, ) = msg.sender.call{value: amount}("");
            require(ok, "ETH transfer failed");
        } else {
            IERC20(tokenAddr).safeTransfer(msg.sender, amount);
        }
        emit BalanceWithdrawn(msg.sender, tokenAddr, amount);
    }

    // Governance
    function setGovernance(address newGovernance) external {
        if (msg.sender != governance) revert ErrUnauthorized();
        if (newGovernance == address(0)) revert ErrZeroAddress();
        governance = newGovernance;
    }

    function setFeeValidator(address validator) external {
        if (msg.sender != governance) revert ErrUnauthorized();
        if (validator == address(0)) revert ErrZeroAddress();

        address prev = feeValidator;
        feeValidator = validator;
        emit FeeValidatorUpdated(prev, validator);
    }

    function withdrawForfeit(address tokenAddr, address to, uint256 amount) external nonReentrant {
        if (msg.sender != governance) revert ErrUnauthorized();
        if (amount == 0) revert ErrZeroAmount();
        if (amount > forfeitBalance[tokenAddr]) revert ErrInsufficientForfeit();
        forfeitBalance[tokenAddr] -= amount;
        if (tokenAddr == ETH_ADDRESS) {
            (bool ok, ) = to.call{value: amount}("");
            require(ok, "ETH transfer failed");
        } else {
            IERC20(tokenAddr).safeTransfer(to, amount);
        }
        emit ProtocolFeeWithdrawn(tokenAddr, to, amount, msg.sender);
    }

    // Internal helpers
    function _settle(uint256 orderId, uint256 amountToSeller, SettleActor actor) internal {
        Order storage order = _orders[orderId];
        order.state = OrderState.Settled;

        uint256 fee = 0;
        if (order.feeRecipient != address(0) && order.feeBps > 0 && amountToSeller > 0) {
            fee = (amountToSeller * uint256(order.feeBps)) / 10_000;
        }
        uint256 payout = amountToSeller - fee;
        uint256 refund = order.escrow > amountToSeller ? (order.escrow - amountToSeller) : 0;

        if (payout > 0) _credit(orderId, order.contractor, order.tokenAddr, payout, BalanceKind.Payout);
        if (fee > 0) _credit(orderId, order.feeRecipient, order.tokenAddr, fee, BalanceKind.Fee);
        if (refund > 0) _credit(orderId, order.client, order.tokenAddr, refund, BalanceKind.Refund);

        uint256 escrowAtSettle = order.escrow;
        order.escrow = 0; // terminal clear
        emit Settled(orderId, amountToSeller, escrowAtSettle, actor);
    }

    function _credit(
        uint256 orderId,
        address to,
        address tokenAddr,
        uint256 amount,
        BalanceKind kind
    ) internal {
        _balances[tokenAddr][to] += amount;
        emit BalanceCredited(orderId, to, tokenAddr, amount, kind);
    }

    function _verifySignature(bytes32 digest, bytes calldata signature, address expectedSigner)
        internal
        pure
        returns (bool)
    {
        if (signature.length != 65) return false;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        address recovered = ecrecover(digest, v, r, s);
        return recovered == expectedSigner;
    }

    receive() external payable {}
}
