// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@uniswap/v4-core/contracts/PoolManager.sol";
import "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract HookFlagTest is Test {
    PoolManager public poolManager;
    TestERC20 public token0;
    TestERC20 public token1;
    
    function setUp() public {
        // Deploy core contracts
        poolManager = new PoolManager(address(this)); // Using test contract as protocol fee recipient
        
        // Deploy test tokens
        token0 = new TestERC20("Token0", "TK0");
        token1 = new TestERC20("Token1", "TK1");
        
        // Ensure token0 address is less than token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
    }

    function testHookFlagManipulation() public {
        // Try to create a hook address with all permissions
        address hookAddr = address(uint160(0x1234) | (uint160(0xFF) << 152));
        
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddr)
        });

        // This should fail if hook address validation is working
        vm.expectRevert();
        poolManager.initialize(key, uint160(1 << 96));
    }

    function testFlagBitFlipping() public {
        // Test each flag bit individually
        for (uint8 i = 0; i < 8; i++) {
            // Create hook address with single flag bit set
            address hookAddr = address(uint160(0x1234) | (uint160(1) << (152 + i)));
            
            console.log("Testing hook address with flag:", i);
            console.logAddress(hookAddr);
            
            PoolKey memory key = PoolKey({
                currency0: Currency.wrap(address(token0)),
                currency1: Currency.wrap(address(token1)),
                fee: 3000,
                tickSpacing: 60,
                hooks: IHooks(hookAddr)
            });

            try poolManager.initialize(key, uint160(1 << 96)) {
                console.log("Flag accepted:", i);
            } catch {
                console.log("Flag rejected:", i);
            }
        }
    }

    function testCrossContractFlagInheritance() public {
        // Try to create a hook proxy that inherits permissions
        HookProxy proxy = new HookProxy();
        
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(proxy))
        });

        // This should fail if hook address validation is working
        vm.expectRevert();
        poolManager.initialize(key, uint160(1 << 96));
    }
}

// Helper contract for testing proxy attacks
contract HookProxy {
    function getTargetHook() internal pure returns (address) {
        return address(uint160(0x1234) | (uint160(0xFF) << 152));
    }
    
    fallback() external {
        address target = getTargetHook();
        assembly {
            // Load the entire calldata
            calldatacopy(0, 0, calldatasize())
            // Forward the call
            let result := call(gas(), target, 0, 0, calldatasize(), 0, 0)
            // Return the result
            returndatacopy(0, 0, returndatasize())
            return(0, returndatasize())
        }
    }
} 