// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Governance.sol";
import "./AssetGovernance.sol";
import "./Proxy.sol";
import "./UpgradeGatekeeper.sol";
import "./BNB-ZKRollup.sol";
import "./BNB-ZKRollupVerifier.sol";
import "./Config.sol";
import "./ZNSController.sol";

contract DeployFactory {

    Proxy governance;
    Proxy verifier;
    Proxy znsController;
    Proxy znsResolver;
    Proxy BNB-ZKRollup;

    // This struct is used for avoiding StackTooDeep
    struct AdditionalParams {
        bytes32 genesisAccountRoot;
        address validator;
        address governor;
        address listingToken;
        uint256 listingFee;
        uint16 listingCap;
        address zns;
        address priceOracle;
        bytes32 baseNode;
    }

    /// @dev Doing development in constructor method costs lower gas fee,
    ///      giving us simplicity and atomicity of our deployment.
    constructor(
        Governance _governanceTarget,
        BNB-ZKRollupVerifier _verifierTarget,
        BNB-ZKRollup _BNB-ZKRollupTarget,
        ZNSController _znsControllerTarget,
        PublicResolver _znsResolverTarget,
        bytes32 _genesisAccountRoot,
        address _validator,
        address _governor,
        address _listingToken,
        uint256 _listingFee,
        uint16 _listingCap,
        address _zns,
        address _priceOracle,
        bytes32 _baseNode
    ) {
        require(_validator != address(0), "validator check");
        require(_governor != address(0), "governor check");

        AdditionalParams memory params = AdditionalParams({
        genesisAccountRoot : _genesisAccountRoot,
        validator : _validator,
        governor : _governor,
        listingToken : _listingToken,
        listingFee : _listingFee,
        listingCap : _listingCap,
        zns : _zns,
        priceOracle : _priceOracle,
        baseNode : _baseNode
        });

        deployProxyContracts(
            _governanceTarget,
            _verifierTarget,
            _BNB-ZKRollupTarget,
            _znsControllerTarget,
            _znsResolverTarget,
            params
        );

        selfdestruct(msg.sender);
    }

    event Addresses(address governance, address assetGovernance, address verifier, address znsController, address znsResolver, address BNB-ZKRollup, address gatekeeper);

    function deployProxyContracts(
        Governance _governanceTarget,
        BNB-ZKRollupVerifier _verifierTarget,
        BNB-ZKRollup _BNB-ZKRollupTarget,
        ZNSController _znsControllerTarget,
        PublicResolver _znsResolverTarget,
        AdditionalParams memory _additionalParams
    ) internal {
        governance = new Proxy(address(_governanceTarget), abi.encode(this));
        // Here temporarily give this contract the governor right.
        // TODO treasury rate
        AssetGovernance assetGovernance = new AssetGovernance(
            address(governance),
            _additionalParams.listingToken,
            _additionalParams.listingFee,
            _additionalParams.listingCap,
            _additionalParams.governor,
            30,
            0,
            5
        );
        verifier = new Proxy(address(_verifierTarget), abi.encode());
        znsController = new Proxy(address(_znsControllerTarget), abi.encode(_additionalParams.zns, _additionalParams.priceOracle, _additionalParams.baseNode));
        znsResolver = new Proxy(address(_znsResolverTarget), abi.encode(_additionalParams.zns));
        AdditionalBNB-ZKRollup additionalBNB-ZKRollup = new AdditionalBNB-ZKRollup();
        BNB-ZKRollup = new Proxy(
            address(_BNB-ZKRollupTarget),
            abi.encode(address(governance), address(verifier), address(additionalBNB-ZKRollup), address(znsController), address(znsResolver), _additionalParams.genesisAccountRoot));

        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(BNB-ZKRollup);

        governance.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(governance));

        verifier.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(verifier));

        znsController.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(znsController));

        znsResolver.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(znsResolver));

        BNB-ZKRollup.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(BNB-ZKRollup));

        upgradeGatekeeper.transferMastership(_additionalParams.governor);

        emit Addresses(address(governance), address(assetGovernance), address(verifier), address(znsController),
            address(znsResolver), address(BNB-ZKRollup), address(upgradeGatekeeper));

        // finally set governance
        finalizeGovernance(Governance(address(governance)), assetGovernance, _additionalParams.validator, _additionalParams.governor);
        finalizeZNSController(ZNSController(address(znsController)), address(BNB-ZKRollup));
    }

    function finalizeGovernance(
        Governance _governance,
        AssetGovernance _assetGovernance,
        address _validator,
        address _governor
    ) internal {
        _governance.changeAssetGovernance(_assetGovernance);
        _governance.setValidator(_validator, true);
        _governance.changeGovernor(_governor);
    }

    function finalizeZNSController(
        ZNSController _znsController,
        address _BNB-ZKRollup
    ) internal {
        _znsController.addController(_BNB-ZKRollup);
        _znsController.transferOwnership(_BNB-ZKRollup);
    }
}
