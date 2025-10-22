// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice 用于测试的 ERC20 代币
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // 铸造 1000000 个代币给部署者
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    /**
     * @notice 铸造代币（测试用）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice 销毁代币（测试用）
     * @param from 销毁地址
     * @param amount 销毁数量
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
