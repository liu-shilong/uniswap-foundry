// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFactory {
    function getExchange(address _tokenAddress) external returns (address);
}
