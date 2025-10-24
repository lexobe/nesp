// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";
import {Order, OrderState} from "../../CONTRACTS/core/Types.sol";
import {MockERC20} from "../../CONTRACTS/mocks/MockERC20.sol";

/**
 * @title Handler
 * @notice Handler contract for Foundry invariant testing
 * @dev Defines constrained random actions that maintain protocol invariants
 *
 * Purpose:
 * - Generate realistic test scenarios through guided fuzzing
 * - Track ghost variables for invariant checking
 * - Ensure actions respect protocol constraints
 *
 * Usage:
 * - Foundry calls handler functions with random parameters
 * - Handler selects random actors/orders and performs valid actions
 * - InvariantTest contract checks invariants after each action
 */
contract Handler is Test {
    /*//////////////////////////////////////////////////////////////
                                CORE CONTRACTS
    //////////////////////////////////////////////////////////////*/

    NESPCore public immutable core;
    MockERC20 public immutable token;

    /*//////////////////////////////////////////////////////////////
                            ACTOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    address[] public actors;
    mapping(address => bool) public isActor;

    address public governance;
    uint256 public constant NUM_ACTORS = 5;

    /*//////////////////////////////////////////////////////////////
                            GHOST VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Track total deposits and withdrawals for conservation check
    uint256 public ghost_ethDeposited;
    uint256 public ghost_ethWithdrawn;
    uint256 public ghost_tokenDeposited;
    uint256 public ghost_tokenWithdrawn;

    // Track order IDs for random selection
    uint256[] public orderIds;
    mapping(uint256 => bool) public orderExists;

    // Track action counts for statistics
    uint256 public callCount_createAndDepositETH;
    uint256 public callCount_createAndDepositERC20;
    uint256 public callCount_acceptOrder;
    uint256 public callCount_markReady;
    uint256 public callCount_approveReceipt;
    uint256 public callCount_raiseDispute;
    uint256 public callCount_cancelOrder;
    uint256 public callCount_timeoutSettle;
    uint256 public callCount_timeoutForfeit;
    uint256 public callCount_withdraw;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(NESPCore _core, MockERC20 _token) {
        core = _core;
        token = _token;
        governance = msg.sender;

        // Create actors
        for (uint256 i = 0; i < NUM_ACTORS; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", vm.toString(i))));
            actors.push(actor);
            isActor[actor] = true;

            // Fund actors
            vm.deal(actor, 1000 ether);
            token.mint(actor, 1000000e18);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Select a random actor
     */
    function _randomActor(uint256 seed) internal view returns (address) {
        return actors[seed % NUM_ACTORS];
    }

    /**
     * @notice Select a random existing order
     */
    function _randomOrder(uint256 seed) internal view returns (uint256) {
        if (orderIds.length == 0) return 0;
        return orderIds[seed % orderIds.length];
    }

    /**
     * @notice Bound amount to reasonable range
     */
    function _boundAmount(uint256 amount) internal pure returns (uint256) {
        return bound(amount, 0.01 ether, 10 ether);
    }

    /**
     * @notice Bound time windows to reasonable range
     */
    function _boundTime(uint48 time) internal pure returns (uint48) {
        return uint48(bound(time, 1 hours, 30 days));
    }

    /*//////////////////////////////////////////////////////////////
                            HANDLER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Create and deposit ETH order
     */
    function createAndDepositETH(
        uint256 actorSeed,
        uint256 contractorSeed,
        uint256 amount,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec
    ) external {
        address client = _randomActor(actorSeed);
        address contractor = _randomActor(contractorSeed);

        // Prevent self-dealing
        if (client == contractor) return;

        amount = _boundAmount(amount);
        dueSec = _boundTime(dueSec);
        revSec = _boundTime(revSec);
        disSec = _boundTime(disSec);

        vm.prank(client);
        try core.createAndDeposit{value: amount}(
            address(0), // ETH
            contractor,
            dueSec,
            revSec,
            disSec,
            address(0), // no fee
            0,
            amount
        ) returns (uint256 orderId) {
            orderIds.push(orderId);
            orderExists[orderId] = true;
            ghost_ethDeposited += amount;
            callCount_createAndDepositETH++;
        } catch {
            // Expected failures: ErrSelfDealing, etc.
        }
    }

    /**
     * @notice Create and deposit ERC-20 order
     */
    function createAndDepositERC20(
        uint256 actorSeed,
        uint256 contractorSeed,
        uint256 amount,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec
    ) external {
        address client = _randomActor(actorSeed);
        address contractor = _randomActor(contractorSeed);

        if (client == contractor) return;

        amount = bound(amount, 1e18, 1000e18); // 1-1000 tokens
        dueSec = _boundTime(dueSec);
        revSec = _boundTime(revSec);
        disSec = _boundTime(disSec);

        // Approve token
        vm.prank(client);
        token.approve(address(core), amount);

        vm.prank(client);
        try core.createAndDeposit(
            address(token),
            contractor,
            dueSec,
            revSec,
            disSec,
            address(0),
            0,
            amount
        ) returns (uint256 orderId) {
            orderIds.push(orderId);
            orderExists[orderId] = true;
            ghost_tokenDeposited += amount;
            callCount_createAndDepositERC20++;
        } catch {
            // Expected failures
        }
    }

    /**
     * @notice Accept an order
     */
    function acceptOrder(uint256 orderSeed, uint256 actorSeed) external {
        uint256 orderId = _randomOrder(orderSeed);
        if (orderId == 0) return;

        Order memory order = core.getOrder(orderId);
        if (order.state != OrderState.Initialized) return;

        address actor = _randomActor(actorSeed);

        vm.prank(actor);
        try core.acceptOrder(orderId) {
            callCount_acceptOrder++;
        } catch {
            // Expected: ErrUnauthorized if not contractor
        }
    }

    /**
     * @notice Mark order as ready
     */
    function markReady(uint256 orderSeed, uint256 actorSeed) external {
        uint256 orderId = _randomOrder(orderSeed);
        if (orderId == 0) return;

        Order memory order = core.getOrder(orderId);
        if (order.state != OrderState.Executing) return;

        address actor = _randomActor(actorSeed);

        vm.prank(actor);
        try core.markReady(orderId) {
            callCount_markReady++;
        } catch {
            // Expected: ErrUnauthorized, ErrExpired
        }
    }

    /**
     * @notice Approve receipt and settle
     */
    function approveReceipt(uint256 orderSeed, uint256 actorSeed) external {
        uint256 orderId = _randomOrder(orderSeed);
        if (orderId == 0) return;

        Order memory order = core.getOrder(orderId);
        if (order.state != OrderState.Executing && order.state != OrderState.Reviewing) return;

        address actor = _randomActor(actorSeed);

        vm.prank(actor);
        try core.approveReceipt(orderId) {
            callCount_approveReceipt++;
        } catch {
            // Expected: ErrUnauthorized, ErrExpired
        }
    }

    /**
     * @notice Raise dispute
     */
    function raiseDispute(uint256 orderSeed, uint256 actorSeed) external {
        uint256 orderId = _randomOrder(orderSeed);
        if (orderId == 0) return;

        Order memory order = core.getOrder(orderId);
        if (order.state != OrderState.Executing && order.state != OrderState.Reviewing) return;

        address actor = _randomActor(actorSeed);

        vm.prank(actor);
        try core.raiseDispute(orderId) {
            callCount_raiseDispute++;
        } catch {
            // Expected: ErrUnauthorized, ErrExpired
        }
    }

    /**
     * @notice Cancel order
     */
    function cancelOrder(uint256 orderSeed, uint256 actorSeed) external {
        uint256 orderId = _randomOrder(orderSeed);
        if (orderId == 0) return;

        Order memory order = core.getOrder(orderId);
        if (
            order.state != OrderState.Initialized && order.state != OrderState.Executing
                && order.state != OrderState.Reviewing
        ) return;

        address actor = _randomActor(actorSeed);

        vm.prank(actor);
        try core.cancelOrder(orderId) {
            callCount_cancelOrder++;
        } catch {
            // Expected: ErrUnauthorized, ErrInvalidState
        }
    }

    /**
     * @notice Timeout settle (E9)
     */
    function timeoutSettle(uint256 orderSeed) external {
        uint256 orderId = _randomOrder(orderSeed);
        if (orderId == 0) return;

        Order memory order = core.getOrder(orderId);
        if (order.state != OrderState.Reviewing) return;

        // Warp past review deadline
        if (block.timestamp < order.readyAt + order.revSec) {
            vm.warp(order.readyAt + order.revSec + 1);
        }

        try core.timeoutSettle(orderId) {
            callCount_timeoutSettle++;
        } catch {
            // Expected: ErrInvalidState, ErrExpired
        }
    }

    /**
     * @notice Timeout forfeit (E13)
     */
    function timeoutForfeit(uint256 orderSeed) external {
        uint256 orderId = _randomOrder(orderSeed);
        if (orderId == 0) return;

        Order memory order = core.getOrder(orderId);
        if (order.state != OrderState.Disputing) return;

        // Warp past dispute deadline
        if (block.timestamp < order.disputeStart + order.disSec) {
            vm.warp(order.disputeStart + order.disSec + 1);
        }

        try core.timeoutForfeit(orderId) {
            callCount_timeoutForfeit++;
        } catch {
            // Expected: ErrInvalidState, ErrExpired
        }
    }

    /**
     * @notice Withdraw funds
     */
    function withdraw(uint256 actorSeed, uint256 tokenChoice) external {
        address actor = _randomActor(actorSeed);
        address tokenAddr = (tokenChoice % 2 == 0) ? address(0) : address(token);

        uint256 balanceBefore;
        if (tokenAddr == address(0)) {
            balanceBefore = actor.balance;
        } else {
            balanceBefore = token.balanceOf(actor);
        }

        vm.prank(actor);
        try core.withdraw(tokenAddr) {
            callCount_withdraw++;

            // Track withdrawn amount
            if (tokenAddr == address(0)) {
                ghost_ethWithdrawn += (actor.balance - balanceBefore);
            } else {
                ghost_tokenWithdrawn += (token.balanceOf(actor) - balanceBefore);
            }
        } catch {
            // Expected: ErrZeroAmount
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TIME MANIPULATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Warp time forward
     * @dev Allows fuzzer to test time-dependent transitions
     */
    function warpTime(uint256 timeSkip) external {
        timeSkip = bound(timeSkip, 1 minutes, 30 days);
        vm.warp(block.timestamp + timeSkip);
    }
}
