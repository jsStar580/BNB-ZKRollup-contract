const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const fs = require('fs')
const {getKeccak256, saveDeployedAddresses, getBNB-ZKRollupProxy} = require("./utils");

async function main() {
    const [owner] = await ethers.getSigners();
    const governor = owner.address;

    const contractFactories = await getContractFactories()
    //  Step 1: deploy zns registry
    console.log('Deploy ZNS registry...')
    const znsRegistry = await contractFactories.ZNSRegistry.deploy();
    await znsRegistry.deployed();

    // Step 2: deploy proxy contract
    // governance
    console.log('Deploy Governance...')
    const governance = await contractFactories.Governance.deploy();
    await governance.deployed();
    // verifier
    console.log('Deploy Verifier...')
    const verifier = await contractFactories.Verifier.deploy()
    await verifier.deployed()
    // BNB-ZKRollup
    console.log('Deploy BNB-ZKRollup...')
    const BNB-ZKRollup = await contractFactories.BNB-ZKRollup.deploy()
    await BNB-ZKRollup.deployed()
    // ZNS controller
    console.log('Deploy ZNSController...')
    const znsController = await contractFactories.ZNSController.deploy();
    await znsController.deployed();
    // ZNS resolver
    console.log('Deploy ZNSResolver...')
    const znsResolver = await contractFactories.ZNSResolver.deploy();
    await znsResolver.deployed();

    // Step 3: initialize deploy factory and finish deployment
    // deploy price oracle
    console.log('Deploy PriceOracle...')
    const priceOracle = await contractFactories.ZNSPriceOracle.deploy([
        ethers.utils.parseEther('0.05'),
        ethers.utils.parseEther('0.03'),
        ethers.utils.parseEther('0.01'),
    ]);
    await priceOracle.deployed();

    // prepare deploy params
    // get ERC20s
    console.log('Deploy Tokens...')
    const totalSupply = ethers.utils.parseEther('100000000')
    const LEGToken = await contractFactories.TokenFactory.deploy(totalSupply, 'LEG', 'LEG')
    await LEGToken.deployed()
    const REYToken = await contractFactories.TokenFactory.deploy(totalSupply, 'REY', 'REY')
    await REYToken.deployed()

    // get ERC721
    const ERC721 = await contractFactories.ERC721Factory.deploy('BNB-ZKRollup', 'ZEC', '0');
    await ERC721.deployed();
    _genesisAccountRoot = '0x14e4e8ad4848558d7200530337052e1ad30f5385b3c7187c80ad85f48547b74f';
    const _listingFee = ethers.utils.parseEther('100');
    const _listingCap = 2 ** 16 - 1;
    const _listingToken = LEGToken.address
    const baseNode = namehash.hash('legend')
    // deploy DeployFactory
    console.log('Deploy DeployFactory...')
    const deployFactory = await contractFactories.DeployFactory.deploy(
        governance.address, verifier.address, BNB-ZKRollup.address, znsController.address, znsResolver.address,
        _genesisAccountRoot, governor, governor, _listingToken, _listingFee, _listingCap,
        znsRegistry.address, priceOracle.address, baseNode, {gasLimit: 13000000}
    );
    await deployFactory.deployed();

    // Get deployed proxy contracts and the gatekeeper contract,
    // they are used for invoking methods.
    const deployFactoryTx = await deployFactory.deployTransaction;
    const deployFactoryTxReceipt = await deployFactoryTx.wait();
    const AddressesInterface = new ethers.utils.Interface(["event Addresses(address governance, address assetGovernance, address verifier, address znsController, address znsResolver, address BNB-ZKRollup, address gatekeeper)"]);
    // The specified index is the required event.
    // console.log(deployFactoryTxReceipt.logs)
    let event = AddressesInterface.decodeEventLog("Addresses", deployFactoryTxReceipt.logs[8].data, deployFactoryTxReceipt.logs[8].topics);
    // Get inner contract proxy address
    // console.log(event)
    const znsControllerProxy = contractFactories.ZNSController.attach(event[3])
    const assetGovernance = contractFactories.AssetGovernance.attach(event[1])

    // deploy default nft factory
    console.log('Deploy DefaultNftFactory...')
    const DefaultNftFactory = await contractFactories.DefaultNftFactory.deploy(
        'BNB-ZKRollup',
        'ZEC',
        'ipfs://',
        event[5],
    )
    await DefaultNftFactory.deployed()

    console.log('Set default nft factory...')
    const proxyBNB-ZKRollup = contractFactories.BNB-ZKRollup.attach(event[5])
    const setDefaultNftFactoryTx = await proxyBNB-ZKRollup.setDefaultNFTFactory(DefaultNftFactory.address)
    await setDefaultNftFactoryTx.wait()

    // Add tokens into assetGovernance
    // add asset
    console.log('Add tokens into assetGovernance asset list...')
    let addAssetTx0 = await assetGovernance.addAsset(LEGToken.address);
    await addAssetTx0.wait()
    let addAssetTx1 = await assetGovernance.addAsset(REYToken.address)
    await addAssetTx1.wait()

    // Step 4: register zns base node
    console.log('Register ZNS base node...')
    const rootNode = '0x0000000000000000000000000000000000000000000000000000000000000000'
    const baseNodeLabel = getKeccak256('legend')       // keccak256('legend');
    const setBaseNodeTx = await znsRegistry.connect(owner).setSubnodeOwner(rootNode, baseNodeLabel, znsControllerProxy.address, ethers.constants.HashZero, ethers.constants.HashZero);
    await setBaseNodeTx.wait();

    // Save addresses into JSON
    console.log('Save deployed contract addresses...')
    saveDeployedAddresses('info/addresses.json', {
        governance: event[0],
        assetGovernance: event[1],
        verifierProxy: event[2],
        znsControllerProxy: event[3],
        znsResolverProxy: event[4],
        BNB-ZKRollupProxy: event[5],
        upgradeGateKeeper: event[6],
        LEGToken: LEGToken.address,
        REYToken: REYToken.address,
        ERC721: ERC721.address,
        znsPriceOracle: priceOracle.address,
    })
}

async function getContractFactories() {
    const Utils = await ethers.getContractFactory("Utils")
    const utils = await Utils.deploy()
    await utils.deployed()

    return {
        TokenFactory: await ethers.getContractFactory('BNB-ZKRollupRelatedERC20'),
        ERC721Factory: await ethers.getContractFactory('BNB-ZKRollupRelatedERC721'),
        ZNSRegistry: await ethers.getContractFactory('OldZNSRegistry'),
        ZNSResolver: await ethers.getContractFactory('PublicResolver'),
        ZNSPriceOracle: await ethers.getContractFactory('StablePriceOracle'),
        ZNSController: await ethers.getContractFactory('OldZNSController'),
        Governance: await ethers.getContractFactory('Governance'),
        AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
        Verifier: await ethers.getContractFactory('BNB-ZKRollupVerifier'),
        BNB-ZKRollup: await ethers.getContractFactory('OldBNB-ZKRollup', {
            libraries: {
                Utils: utils.address
            }
        }),
        DeployFactory: await ethers.getContractFactory('DeployFactory'),
        DefaultNftFactory: await ethers.getContractFactory('BNB-ZKRollupNFTFactory'),
    }
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });