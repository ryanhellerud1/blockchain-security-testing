// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@uniswap/v4-core/interfaces/IHooks.sol";
import "@uniswap/v4-core/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/types/PoolKey.sol";
import "@uniswap/v4-core/types/BalanceDelta.sol";

// Base hook implementation with all required functions
abstract contract BaseHook is IHooks {
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96) external virtual returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }
    
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick) external virtual returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }
    
    function beforeAddLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params) external virtual returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }
    
    function afterAddLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params, BalanceDelta delta) external virtual returns (bytes4) {
        return IHooks.afterAddLiquidity.selector;
    }
    
    function beforeRemoveLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params) external virtual returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }
    
    function afterRemoveLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params, BalanceDelta delta) external virtual returns (bytes4) {
        return IHooks.afterRemoveLiquidity.selector;
    }
    
    function beforeSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params) external virtual returns (bytes4) {
        return IHooks.beforeSwap.selector;
    }
    
    function afterSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params, BalanceDelta delta) external virtual returns (bytes4) {
        return IHooks.afterSwap.selector;
    }
    
    function beforeDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1) external virtual returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }
    
    function afterDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1) external virtual returns (bytes4) {
        return IHooks.afterDonate.selector;
    }
}

// Hook attempting state manipulation
contract StateManipulationHook is BaseHook {
    uint256 private storedValue;
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params
    ) external override returns (bytes4) {
        // Store state for cross-function attack
        storedValue = uint256(params.sqrtPriceLimitX96);
        return IHooks.beforeSwap.selector;
    }
    
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta
    ) external override returns (bytes4) {
        // Attempt to manipulate pool state using stored value
        try IPoolManager(msg.sender).modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -1000,
                tickUpper: 1000,
                liquidityDelta: int256(storedValue),
                salt: bytes32(0)
            }),
            ""
        ) {} catch {}
        return IHooks.afterSwap.selector;
    }
}

// Hook attempting reentrancy attacks
contract ReentrancyHook is BaseHook {
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
            }),
            ""
        );
    }
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params
    ) external override returns (bytes4) {
        if (attacking) {
            // Attempt reentrancy
            IPoolManager(msg.sender).swap(key, params, "");
        }
        return IHooks.beforeSwap.selector;
    }
} 