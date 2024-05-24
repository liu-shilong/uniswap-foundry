// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 代币合约
contract Token is ERC20 {
    /**
     * 构造函数
     * @param name 代币名称
     * @param symbol 代币符号
     * @param initialSupply 初始供应量
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        // 铸造代币
        _mint(msg.sender, initialSupply);
    }
}
