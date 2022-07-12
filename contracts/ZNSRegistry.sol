// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./ZNS.sol";

contract ZNSRegistry is ZNS {

    // @dev Require the msg.sender is the owner of this node
    modifier authorized(bytes32 node) {
        require(records[node].owner == msg.sender, "unauthorized");
        _;
    }

    // @dev A Record is a record of node
    struct Record {
        // The owner of a record may:
        // 1. Transfer ownership of the name to another address
        // 2. Change the ownership of sub account name
        // 3. Set the resolver and related information of this node
        address owner;
        address resolver;
        uint32 accountIndex;
        bytes32 pubKeyX;
        bytes32 pubKeyY;
        // These fields may be remained for future use.
        // string slot1;
        // string slot2;
    }

    mapping(bytes32 => Record) records; // nameHash of node => Record
    uint32 count = 0;

    /**
     * @dev Constructs a new registry.
     */
    constructor() {
        records[0x0].owner = msg.sender;
    }

    /**
     * @dev Set the record for a node.
     * @param _node The node to update.
     * @param _owner The address of the new owner.
     * @param _resolver The address of the resolver.
     * @param _pubKeyX The pub key of the node
     * @param _pubKeyY The pub key of the node
     */
    function setRecord(
        bytes32 _node,
        address _owner,
        bytes32 _pubKeyX,
        bytes32 _pubKeyY,
        address _resolver
    ) external override {
        _setOwner(_node, _owner);
        _setPubKey(_node, _pubKeyX, _pubKeyY);
        _setResolver(_node, _resolver);
    }

    /**
     * @dev Set the record for a subnode.
     * @param _node The parent node.
     * @param _label The hash of the subnode
     * @param _owner The address of the new owner.
     * @param _resolver The address of the resolver.
     * @param _pubKeyX The layer-2 public key
     * @param _pubKeyY The layer-2 public key
     */
    function setSubnodeRecord(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _pubKeyX,
        bytes32 _pubKeyY,
        address _resolver
    ) external override returns (bytes32){
        bytes32 subnode = setSubnodeOwner(_node, _label, _owner, _pubKeyX, _pubKeyY);
        _setResolver(subnode, _resolver);
        return subnode;
    }

    function setSubnodeAccountIndex(
        bytes32 _node
    ) external override returns (uint32){
        records[_node].accountIndex = count;
        count++;
        return records[_node].accountIndex;
    }

    /**
     * @dev Set the ownership of a subnode hash(node, label) to a new address. May only be called by the owner of the parent node.
     * @param _node The parent node.
     * @param _label The hash of the label specifying the subnode.
     * @param _owner The address of the new owner.
     * @param _pubKeyX The L2 owner of the subnode
     * @param _pubKeyY The L2 owner of the subnode
     */
    function setSubnodeOwner(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _pubKeyX,
        bytes32 _pubKeyY
    ) public override authorized(_node) returns (bytes32) {
        bytes32 subnode = mimcHash(abi.encodePacked(_node, _label));
        _setOwner(subnode, _owner);
        _setPubKey(subnode, _pubKeyX, _pubKeyY);
        return subnode;
    }

    /**
     * @dev Set the resolver address for the specified node.
     * @param _node The node to update.
     * @param _resolver The address of the resolver.
     */
    function setResolver(bytes32 _node, address _resolver) public override authorized(_node) {
        _setResolver(_node, _resolver);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node The specified node.
     * @return address of the owner.
     */
    function owner(bytes32 node) public view override returns (address) {
        address addr = records[node].owner;
        if (addr == address(this)) {
            return address(0x0);
        }

        return addr;
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node The specified node.
     * @return address of the resolver.
     */
    function resolver(bytes32 node) public view override returns (address) {
        return records[node].resolver;
    }

    /**
     * @dev Returns the L2 owner of the specified node, which is a bytes32 L2 public key.
     * @param node The specified node.
     * @return L2 owner of the node.
     */
    function pubKey(bytes32 node) public view override returns (bytes32, bytes32) {
        return (records[node].pubKeyX, records[node].pubKeyY);
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param node The specified node
     * @return bool If record exists
     */
    function recordExists(bytes32 node) public view override returns (bool) {
        return _exists(node);
    }

    /**
     * @dev Returns whether a subnode record has been imported to the registry.
     * @param node The specified node
     * @param label The nodehash of the subnode
     * @return bool If record exists
     */
    function subNodeRecordExists(bytes32 node, bytes32 label) public view override returns (bool) {
        bytes32 subnode = mimcHash(abi.encodePacked(node, label));
        return _exists(subnode);
    }

    function _setResolver(bytes32 _node, address _resolver) internal {
        if (_resolver != records[_node].resolver) {
            records[_node].resolver = _resolver;
            emit NewResolver(_node, _resolver);
        }
    }

    function _setOwner(bytes32 _node, address _owner) internal {
        if (_owner != records[_node].owner) {
            records[_node].owner = _owner;
            emit NewOwner(_node, _owner);
        }
    }

    function _setPubKey(bytes32 _node, bytes32 _pubKeyX, bytes32 _pubKeyY) internal {
        if (_pubKeyX != records[_node].pubKeyX && _pubKeyY != records[_node].pubKeyY) {
            records[_node].pubKeyX = _pubKeyX;
            records[_node].pubKeyY = _pubKeyY;
            emit NewPubKey(_node, _pubKeyX, _pubKeyY);
        }
    }

    function _exists(bytes32 node) internal view returns (bool) {
        return records[node].owner != address(0x0);
    }

    function mimcHash(bytes memory input) public view returns (bytes32 result) {
        address mimcContract = 0x0000000000000000000000000000000000000013;

        (bool success, bytes memory data) = mimcContract.staticcall(input);
        require(success, "Q");
        assembly {
            result := mload(add(data, 32))
        }
    }

}
