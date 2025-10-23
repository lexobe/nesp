// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {NESPCore} from "../CONTRACTS/core/NESPCore.sol";
import {MockERC20} from "../CONTRACTS/mocks/MockERC20.sol";
import {AlwaysYesValidator} from "../CONTRACTS/mocks/AlwaysYesValidator.sol";

/**
 * @title DeployBaseSepolia
 * @notice Base Sepolia 测试网部署脚本
 * @dev 使用方法:
 *
 * 1. 准备环境变量 (.env):
 *    PRIVATE_KEY=0x... (你的私钥，从 Metamask 导出)
 *    BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
 *    BASESCAN_API_KEY=... (可选，用于验证合约)
 *
 * 2. 获取测试币:
 *    - Base Sepolia Faucet: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
 *    - 或者告诉我你的地址，我会发送测试币
 *
 * 3. 部署:
 *    forge script script/DeployBaseSepolia.s.sol \
 *      --rpc-url $BASE_SEPOLIA_RPC_URL \
 *      --private-key $PRIVATE_KEY \
 *      --broadcast \
 *      --verify \
 *      --etherscan-api-key $BASESCAN_API_KEY
 *
 * 4. 模拟部署（不上链）:
 *    forge script script/DeployBaseSepolia.s.sol \
 *      --rpc-url $BASE_SEPOLIA_RPC_URL
 */
contract DeployBaseSepolia is Script {
    // 部署后的合约地址（会打印到控制台）
    NESPCore public core;
    MockERC20 public testToken;
    AlwaysYesValidator public feeValidator;

    function run() external {
        // 读取部署者地址（从私钥派生）
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        console2.log("Deployer address:", deployer);
        console2.log("Deployer balance:", deployer.balance);

        // 检查余额
        require(deployer.balance > 0.01 ether, "Insufficient balance for deployment");

        // 开始广播交易
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // 1. 部署 NESPCore（deployer 作为初始 governance）
        console2.log("\n=== Deploying NESPCore ===");
        core = new NESPCore(deployer);
        console2.log("NESPCore deployed at:", address(core));

        // 2. 部署测试用 ERC20 代币（可选）
        console2.log("\n=== Deploying Test Token ===");
        testToken = new MockERC20("NESP Test Token", "NESP");
        console2.log("TestToken deployed at:", address(testToken));

        // 给 deployer mint 一些测试代币
        testToken.mint(deployer, 1000000 ether);
        console2.log("Minted 1,000,000 NESP to deployer");

        // 3. 部署 FeeValidator（可选，用于测试手续费）
        console2.log("\n=== Deploying FeeValidator ===");
        feeValidator = new AlwaysYesValidator();
        console2.log("FeeValidator deployed at:", address(feeValidator));

        // 4. 设置 FeeValidator
        core.setFeeValidator(address(feeValidator));
        console2.log("FeeValidator set in NESPCore");

        vm.stopBroadcast();

        // 5. 打印部署总结
        console2.log("\n=== Deployment Summary ===");
        console2.log("Network: Base Sepolia");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("");
        console2.log("NESPCore:", address(core));
        console2.log("TestToken:", address(testToken));
        console2.log("FeeValidator:", address(feeValidator));
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Verify contracts on BaseScan");
        console2.log("2. Create test orders using deployed NESPCore");
        console2.log("3. Share contract address for community testing");

        // 6. 保存部署信息到文件
        _saveDeployment(deployer);
    }

    /**
     * @notice 保存部署信息到 JSON 文件
     */
    function _saveDeployment(address deployer) internal {
        string memory json = string.concat(
            '{\n',
            '  "network": "base-sepolia",\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "contracts": {\n',
            '    "NESPCore": "', vm.toString(address(core)), '",\n',
            '    "TestToken": "', vm.toString(address(testToken)), '",\n',
            '    "FeeValidator": "', vm.toString(address(feeValidator)), '"\n',
            '  }\n',
            '}'
        );

        string memory filename = string.concat(
            "deployments/base-sepolia-",
            vm.toString(block.timestamp),
            ".json"
        );

        vm.writeFile(filename, json);
        console2.log("\nDeployment info saved to:", filename);
    }
}
