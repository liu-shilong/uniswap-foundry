// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Exchange.sol";

contract Factory {
    // 工厂是一个注册表， 代币地址->交易所地址的映射
    mapping(address => address) public tokenToExchange;

    /**
     * 创建交易所
     * @param _tokenAddress 代币地址
     */
    function createExchange(address _tokenAddress) public returns (address) {
        // 确保不能是零地址
        require(_tokenAddress != address(0), "invalid token address");
        // 确保尚未添加到注册表中
        require(tokenToExchange[_tokenAddress] == address(0), "exchange already exists");

        Exchange exchange = new Exchange(_tokenAddress);
        tokenToExchange[_tokenAddress] = address(exchange);

        return address(exchange);
    }

    /**
     * 获取交易所地址
     * @param _tokenAddress  代币地址
     */
    function getExchange(address _tokenAddress) public view returns (address) {
        return tokenToExchange[_tokenAddress];
    }
}
