// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PoolManager.sol";
import "../src/interfaces/IHooks.sol";
import "../src/libraries/Hooks.sol";
import "./mocks/TestERC20.sol";

contract HookFlagTest is Test {
    PoolManager public poolManager;
    TestERC20 public token0;
    TestERC20 public token1;
    
    // Constants for hook flags
    uint8 constant BEFORE_INITIALIZE_FLAG = 0x01;
    uint8 constant AFTER_INITIALIZE_FLAG  = 0x02;
    uint8 constant BEFORE_SWAP_FLAG       = 0x04;
    uint8 constant AFTER_SWAP_FLAG        = 0x08;
    uint8 constant BEFORE_MODIFY_FLAG     = 0x10;
    uint8 constant AFTER_MODIFY_FLAG      = 0x20;
    uint8 constant BEFORE_DONATE_FLAG     = 0x40;
    uint8 constant AFTER_DONATE_FLAG      = 0x80;

    function setUp() public {
        // Deploy core contracts
        poolManager = new PoolManager(500000);
        
        // Deploy test tokens
        token0 = new TestERC20("Test0", "TST0");
        token1 = new TestERC20("Test1", "TST1");
        
        // Ensure token0 address is less than token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
    }

    function testHookFlagManipulation() public {
        // Try to create a hook address with all permissions
        address hookAddr = address(uint160(0x1234) | (uint160(0xFF) << 152));
        
        PoolKey memory key = PoolKey({
            token0: address(token0),
            token1: address(token1),
            fee: 3000,
            hookAddress: hookAddr,
            poolManager: address(poolManager)
        });

        // This should fail if hook address validation is working
        vm.expectRevert();
        poolManager.initialize(key, uint160(1 << 96));
    }

    function testFlagBitFlipping() public {
        // Create hook address with single permission
        address baseAddr = address(uint160(0x1234));
        
        // Try flipping bits one by one
        for (uint8 i = 0; i < 8; i++) {
            address hookAddr = address(uint160(baseAddr) | (uint160(1 << i) << 152));
            
            PoolKey memory key = PoolKey({
                token0: address(token0),
                token1: address(token1),
                fee: 3000,
                hookAddress: hookAddr,
                poolManager: address(poolManager)
            });

            // Log the attempt
            console.log("Testing hook address with flag:", i);
            console.logAddress(hookAddr);
            
            // Try to initialize pool with this hook
            try poolManager.initialize(key, uint160(1 << 96)) {
                console.log("Flag accepted:", i);
            } catch {
                console.log("Flag rejected:", i);
            }
        }
    }

    function testCrossContractFlagInheritance() public {
        // Deploy a proxy contract that tries to inherit hook permissions
        HookProxy proxy = new HookProxy();
        
        PoolKey memory key = PoolKey({
            token0: address(token0),
            token1: address(token1),
            fee: 3000,
            hookAddress: address(proxy),
            poolManager: address(poolManager)
        });

        // Try to initialize with proxy
        vm.expectRevert();
        poolManager.initialize(key, uint160(1 << 96));
    }
}

// Helper contract for testing proxy attacks
contract HookProxy {
    address private immutable TARGET_HOOK = address(0x1234 | (uint160(0xFF) << 152));
    
    fallback() external {
        // Try to proxy to a hook address with all permissions
        assembly {
            // Load the entire calldata
            calldatacopy(0, 0, calldatasize())
            // Forward the call
            let result := call(gas(), TARGET_HOOK, 0, 0, calldatasize(), 0, 0)
            // Return the result
            returndatacopy(0, 0, returndatasize())
            return(0, returndatasize())
        }
    }
} 