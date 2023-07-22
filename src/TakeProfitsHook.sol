// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseHook} from "periphery-next/BaseHook.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/libraries/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/libraries/CurrencyLibrary.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract TakeProfitsHook is BaseHook, ERC1155 {

    using CurrencyLibrary for Currency;

        // Use the PoolIdLibrary for IPoolManager.PoolKey to add the `.toId()` function on a PoolKey
    // which hashes the PoolKey struct into a bytes32 value
    using PoolIdLibrary for IPoolManager.PoolKey;

    // Create a mapping to store the last known tickLower value for a given Pool
    mapping(PoolId poolId => int24 tickLower) public tickLowerLasts;

    // Create a nested mapping to store the take-profit orders placed by users
    // The mapping is PoolId => tickLower => zeroForOne => amount
    // PoolId => (...) specifies the ID of the pool the order is for
    // tickLower => (...) specifies the tickLower value of the order i.e. sell when price is greater than or equal to this tick
    // zeroForOne => (...) specifies whether the order is swapping Token 0 for Token 1 (true), or vice versa (false)
    // amount specifies the amount of the token being sold
    mapping(PoolId poolId => mapping(int24 tick => mapping(bool zeroForOne => int256 amount))) public takeProfitPositions;

    // tokenIdExists is a mapping to store whether a given tokenId (i.e. a take-profit order) exists given a token id
mapping(uint256 tokenId => bool exists) public tokenIdExists;
// tokenIdClaimable is a mapping that stores how many swapped tokens are claimable for a given tokenId
mapping(uint256 tokenId => uint256 claimable) public tokenIdClaimable;
// tokenIdTotalSupply is a mapping that stores how many tokens need to be sold to execute the take-profit order
mapping(uint256 tokenId => uint256 supply) public tokenIdTotalSupply;
// tokenIdData is a mapping that stores the PoolKey, tickLower, and zeroForOne values for a given tokenId
mapping(uint256 tokenId => TokenData) public tokenIdData;

struct TokenData {
    IPoolManager.PoolKey poolKey;
    int24 tick;
    bool zeroForOne;
}



    // Initialize BaseHook and ERC1155 parent contracts in the constructor
    constructor(IPoolManager _poolManager, string memory _uri) BaseHook(_poolManager) ERC1155(_uri) {}

    // Required override function for BaseHook to let the PoolManager know which hooks are implemented
    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
                beforeInitialize: false,
                afterInitialize: true,
                beforeModifyPosition: false,
                afterModifyPosition: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false
        });
    }

    // Utility Helpers
function _setTickLowerLast(PoolId poolId, int24 tickLower) private {
    tickLowerLasts[poolId] = tickLower;
}

function _getTickLower(int24 actualTick, int24 tickSpacing) private pure returns (int24) {
    int24 intervals = actualTick / tickSpacing;
    if (actualTick < 0 && actualTick % tickSpacing != 0) intervals--; // round towards negative infinity
    return intervals * tickSpacing;
}

// Hooks
function afterInitialize(
    address,
    IPoolManager.PoolKey calldata key,
    uint160,
    int24 tick
) external override poolManagerOnly returns (bytes4) {
    _setTickLowerLast(key.toId(), _getTickLower(tick, key.tickSpacing));
    return TakeProfitsHook.afterInitialize.selector;
}

// ERC-1155 Helpers
function getTokenId(IPoolManager.PoolKey calldata key, int24 tickLower, bool zeroForOne) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(key.toId(), tickLower, zeroForOne)));
}




}