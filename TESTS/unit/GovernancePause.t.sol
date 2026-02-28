// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {BaseTest} from "../BaseTest.t.sol";
import {NESPCore} from "../../CONTRACTS/core/NESPCore.sol";

/**
 * @title GovernancePauseTest
 * @notice 测试治理两步转移与受限暂停机制
 */
contract GovernancePauseTest is BaseTest {
    function test_PauseBlocks_CreateAndDeposit() public {
        // 先创建一个订单用于测试存款被暂停
        uint256 orderId = _createETHOrder();

        // 治理安排暂停
        vm.prank(governance);
        core.schedulePause(true);
        vm.warp(block.timestamp + core.PAUSE_DELAY());
        core.executePause();

        // 新建订单应被阻止
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrPaused.selector);
        core.createOrder(address(0), contractor, 0, 0, 0, address(0), 0);

        // 新增托管应被阻止
        vm.prank(client);
        vm.expectRevert(NESPCore.ErrPaused.selector);
        core.depositEscrow{value: ESCROW_AMOUNT}(orderId, ESCROW_AMOUNT);
    }

    function test_PauseTimelock() public {
        vm.prank(governance);
        core.schedulePause(true);
        vm.expectRevert(NESPCore.ErrTimelockNotReady.selector);
        core.executePause();
    }

    function test_PauseCancel() public {
        vm.prank(governance);
        core.schedulePause(true);
        vm.prank(governance);
        core.cancelPause();

        vm.expectRevert(NESPCore.ErrInvalidState.selector);
        core.executePause();
    }

    function test_GovernanceTwoStep() public {
        address newGov = makeAddr("newGov");

        // 只有治理可设置
        vm.prank(governance);
        core.setGovernance(newGov);

        // 非 pending 账户不可接管
        vm.prank(thirdParty);
        vm.expectRevert(NESPCore.ErrUnauthorized.selector);
        core.acceptGovernance();

        // 新治理接受
        vm.prank(newGov);
        core.acceptGovernance();

        assertEq(core.governance(), newGov);
        assertEq(core.pendingGovernance(), address(0));
    }
}
