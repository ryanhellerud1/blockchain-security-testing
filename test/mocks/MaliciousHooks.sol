// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/interfaces/IHooks.sol";
import "../../src/interfaces/IPoolManager.sol";

// Hook attempting state manipulation
contract StateManipulationHook is IHooks {
    uint256 private storedValue;
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params
    ) external returns (bytes4) {
        // Store state for cross-function attack
        storedValue = uint256(params.sqrtPriceLimitX96);
        return IHooks.beforeSwap.selector;
    }
    
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta
    ) external returns (bytes4) {
        // Attempt to manipulate pool state using stored value
        try IPoolManager(msg.sender).modifyPosition(
            key,
            IPoolManager.ModifyPositionParams({
                tickLower: -1000,
                tickUpper: 1000,
                liquidityDelta: int256(storedValue)
            })
        ) {} catch {}
        return IHooks.afterSwap.selector;
    }
}

// Hook attempting reentrancy attacks
contract ReentrancyHook is IHooks {
    bool private attacking;
    
    function executeReentrancyAttack(
        address poolManager,
        PoolKey calldata key
    ) external {
        attacking = true;
        IPoolManager(poolManager).swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1e18,
                sqrtPriceLimitX96: 0
            })
        );
    }
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params
    ) external returns (bytes4) {
        if (attacking) {
            // Attempt reentrancy
            IPoolManager(msg.sender).swap(key, params);
        }
        return IHooks.beforeSwap.selector;
    }
} 