const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Checking creating elements', async function () {
  let domainContract;
  before(async function () {
    const domainContractFactory = await hre.ethers.getContractFactory(
      'Domains'
    );
    domainContract = await domainContractFactory.deploy('damn');
    await domainContract.deployed();
  });

  it('Should register a new domain and the deployer should be the owner', async function () {
    let tokenIdBefore = await domainContract.getCounter();
    tokenIdBefore =
      parseFloat(ethers.utils.formatEther(tokenIdBefore)) * 10 ** 18;

    let registerTxn = await domainContract.register('working', {
      value: hre.ethers.utils.parseEther('0.1'),
    });
    const receipt = await registerTxn.wait();

    const { status } = await receipt.events[0].getTransactionReceipt();

    const domainOwner = await domainContract.getAddress('working');
    const [owner] = await ethers.getSigners();

    let tokenIdAfter = await domainContract.getCounter();
    tokenIdAfter =
      parseFloat(ethers.utils.formatEther(tokenIdAfter)) * 10 ** 18;

    expect(status).to.equal(1);
    expect(tokenIdAfter).to.equal(tokenIdBefore + 1);
    expect(domainOwner).to.equal(owner.address);
  });

  it('Should throw an error if we try to register a used domain', async function () {
    await expect(
      domainContract.register('working', {
        value: hre.ethers.utils.parseEther('0.1'),
      })
    ).to.be.revertedWith("reverted with custom error 'AlreadyRegistered()'");
  });

  it('Should throw an error if we try to register a domain without enough money', async function () {
    await expect(
      domainContract.register('newmoney', {
        value: hre.ethers.utils.parseEther('0.00001'),
      })
    ).to.be.revertedWith('Not enough Matic paid');
  });

  it('Should throw an error if we try to register a domain without a right name', async function () {
    const name = 'abcfibiognirtongoingoigngoingoignio';
    await expect(
      domainContract.register(name, {
        value: hre.ethers.utils.parseEther('0.00001'),
      })
    ).to.be.revertedWith(`reverted with custom error 'InvalidName("${name}")'`);
  });

  it('Should let the owner withdraw money from the contract', async function () {
    const [owner] = await ethers.getSigners();
    const prov = ethers.provider;

    let balanceBefore = await prov.getBalance(owner.address);
    balanceBefore =
      parseFloat(ethers.utils.formatEther(balanceBefore)) * 10 ** 18;
    let balanceContractBefore = await prov.getBalance(domainContract.address);
    balanceContractBefore =
      parseFloat(ethers.utils.formatEther(balanceContractBefore)) * 10 ** 18;

    let txn = await domainContract.withdraw();
    await txn.wait();

    let balanceAfter = await prov.getBalance(owner.address);
    balanceAfter =
      parseFloat(ethers.utils.formatEther(balanceAfter)) * 10 ** 18;
    let balanceContractAfter = await prov.getBalance(domainContract.address);
    balanceContractAfter =
      parseFloat(ethers.utils.formatEther(balanceContractAfter)) * 10 ** 18;

    expect(balanceContractAfter).to.equal(0);
    expect(balanceAfter).to.above(balanceBefore);
  });

  it('Should throw and error if it is not the owner withdrawing', async function () {
    const [owner, addr1] = await ethers.getSigners();
    await expect(domainContract.connect(addr1).withdraw()).to.be.revertedWith(
      'Transaction reverted without a reason string'
    );
  });

  it('Should be able to setRecord and to get the record', async function () {
    const recordOnChain = 'Record that we are putting on the chain!';
    const txn = await domainContract.setRecord('working', recordOnChain);
    await txn.wait();
    const record = await domainContract.getRecord('working');

    expect(record).to.be.equal(recordOnChain);
  });

  it('Should get All Names registered on the contract', async function () {
    const nameToRegister = ['nameA', 'nameB', 'nameC', 'nameD'];
    const arrayResult = ['working', ...nameToRegister];

    await Promise.all(
      nameToRegister.map(async (element) => {
        let registerTxn = await domainContract.register(element, {
          value: hre.ethers.utils.parseEther('0.5'),
        });
        await registerTxn.wait();
      })
    );

    const names = await domainContract.getAllNames();

    expect(arrayResult).to.be.eql(names);
  });
});
