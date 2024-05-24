// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IFactory.sol";

contract Exchange is ERC20 {
    // 代币地址
    address public tokenAddress;
    // 工厂地址
    address public factoryAddress;

    /**
     * 构造函数
     * @param _token  代币地址
     */
    constructor(address _token) ERC20("Zuniswap-V1", "ZUNI-V1") {
        // 不能是零地址
        require(_token != address(0), "invalid token address");

        tokenAddress = _token;
        factoryAddress = msg.sender;
    }

    /**
     * 添加流动性
     * @param _tokenAmount 代币数量
     */
    function addLiquidity(uint256 _tokenAmount) public payable returns (uint256) {
        // 如果这是一个新的交易所（没有流动性），则在池为空时允许任意流动性比例。
        if (getReserve() == 0) {
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), _tokenAmount);

            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity);

            return liquidity;
        } else {
            // 当有一些流动性时，强制执行既定的准备金比例
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;
            require(_tokenAmount >= tokenAmount, "insufficient token amount");

            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);

            uint256 liquidity = (msg.value * totalSupply()) / ethReserve;
            _mint(msg.sender, liquidity);

            return liquidity;
        }
    }

    /**
     * 移除流动性
     * @param _amount _amount
     * @return
     * @return
     */
    function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
        require(_amount > 0, "invalid amount");

        uint256 ethAmount = (address(this).balance * _amount) / totalSupply();
        uint256 tokenAmount = (getReserve() * _amount) / totalSupply();

        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(ethAmount);
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        return (ethAmount, tokenAmount);
    }

    /**
     * 查询交易所代币余额
     */
    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * 获取代币数量
     * @param _ethSold 要卖出的以太币数量
     */
    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0, "ethSold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }

    /**
     * 获取以太币数量
     * @param _tokenSold  要卖出的代币数量
     */
    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, "tokenSold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function ethToToken(uint256 _minTokens, address recipient) private {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(msg.value, address(this).balance - msg.value, tokenReserve);

        require(tokensBought >= _minTokens, "insufficient output amount");

        IERC20(tokenAddress).transfer(recipient, tokensBought);
    }

    function ethToTokenTransfer(uint256 _minTokens, address _recipient) public payable {
        ethToToken(_minTokens, _recipient);
    }

    /**
     * 以太币换成代币
     * @param _minTokens 最小代币数量
     */
    function ethToTokenSwap(uint256 _minTokens) public payable {
        ethToToken(_minTokens, msg.sender);
    }

    /**
     * 代币换成以太币
     * @param _tokensSold 要交换的代币数量
     * @param _minEth  最小以太币数量
     */
    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);

        require(ethBought >= _minEth, "insufficient output amount");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        payable(msg.sender).transfer(ethBought);
    }

    /**
     * 代币互换
     * @param _tokensSold 要出售的代币数量
     * @param _minTokensBought 要交换的最小代币数量
     * @param _tokenAddress  要交换已售出代币的代币的地址
     */
    function tokenToTokenSwap(uint256 _tokensSold, uint256 _minTokensBought, address _tokenAddress) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        // 检查用户提供的令牌地址是否有交换。如果没有，它将引发错误
        require(exchangeAddress != address(this) && exchangeAddress != address(0), "invalid exchange address");

        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);

        // 用当前的交易所将代币换成以太币，并将用户的代币转移到交易所
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        // 使用其他交易所将以太币交换为代币
        IExchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(_minTokensBought, msg.sender);
    }

    /**
     * 获取以太币或代币数量
     * @param inputAmount  输入数量
     * @param inputReserve 输入储备量
     * @param outputReserve 输出储备量
     */
    function getAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve)
        private
        pure
        returns (uint256)
    {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;

        return numerator / denominator;
    }
}
