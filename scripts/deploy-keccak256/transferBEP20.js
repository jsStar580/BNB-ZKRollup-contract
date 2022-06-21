const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils")
const {ethers} = require("hardhat");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const [owner] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('ZecreyRelatedERC20')
    const LegToken = await Token.attach('0x65cd5b953939258B4918C2cd5D34425601414875')
    const ReyToken = await Token.attach('0xf8fB5EBcC2300E6dE33752788AD14155A37259F5')

    console.log('Transfer LEG')
    const recipient = '0x805e286d05388911ccdb10e3c7b9713415607c72'
    let transferTx = await LegToken.transfer(recipient, ethers.utils.parseEther('1000'))
    await transferTx.wait()
    console.log('Transfer REY')
    transferTx = await ReyToken.transfer(recipient, ethers.utils.parseEther('1000'))
    await transferTx.wait()

    console.log('Transfer BNB')
    transferTx = await owner.sendTransaction({
        to: recipient,
        value: ethers.utils.parseEther('10'),
    })
    await transferTx.wait()


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });