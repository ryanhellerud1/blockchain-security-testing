# Uniswap v4 Bug Hunting Notes

## Major Changes from v3
- Hooks system (new attack surface)
- Singleton pool deployment model
- Native fee collection
- Modified pool creation process

## Initial Focus Areas
1. Hook System
   - Hook initialization
   - State management
   - Permissions
   - Callback security

2. Pool Management
   - Creation
   - State transitions
   - Liquidity handling

3. Known Issues from v3
   - Price manipulation
   - Reentrancy concerns
   - State synchronization 

## Detailed Hook System Analysis

### 1. Hook Architecture
- Hooks are implemented as external contracts
- Can be called before and after key operations:
  - beforeInitialize/afterInitialize
  - beforeModifyPosition/afterModifyPosition
  - beforeSwap/afterSwap
  - beforeDonate/afterDonate

### 2. Critical Security Points
- Hook Initialization Flow
  - How hooks are deployed
  - How hooks are attached to pools
  - Validation of hook contracts
  - Immutability concerns

### 3. State Management Risks
- Hook state storage locations
- Cross-function state consistency
- State updates during callbacks
- Potential state lock or corruption scenarios

### 4. Permission System
- Who can install hooks
- Who can call hook functions
- Permission inheritance patterns
- Permission validation points

### 5. Known Hook Attack Vectors
- Reentrancy through callbacks
- Cross-function invocation
- Gas manipulation attacks
- Front-running opportunities

### 6. Testing Focus Areas
- Hook deployment scenarios
- State transition testing
- Permission boundary testing
- Callback loop testing

### Next Steps:
1. Review IHooks.sol interface
2. Analyze hook installation process
3. Map all callback entry points
4. Test state management scenarios

## IHooks.sol Interface Analysis

### Interface Functions
1. Initialize Hooks
   - beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
   - afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
   
2. Position Modification Hooks
   - beforeModifyPosition(address sender, PoolKey calldata key, ModifyPositionParams calldata params)
   - afterModifyPosition(address sender, PoolKey calldata key, ModifyPositionParams calldata params, BalanceDelta delta)

3. Swap Hooks
   - beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params)
   - afterSwap(address sender, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta)

4. Donate Hooks
   - beforeDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1)
   - afterDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1)

### Potential Attack Surfaces
1. Input Validation
   - Parameter manipulation in callbacks
   - Malicious sender addresses
   - Invalid pool keys

2. State Management
   - Hook state changes between before/after calls
   - Cross-transaction state consistency
   - Storage collision possibilities

3. Return Value Attacks
   - Manipulation of return values
   - Impact on pool operations
   - Validation of returned data

4. Access Control
   - Hook installation permissions
   - Function access restrictions
   - Privilege escalation vectors

### Security Questions to Investigate
1. Can hooks modify critical pool state?
2. How are hook failures handled?
3. What prevents malicious hooks from:
   - Blocking transactions?
   - Manipulating prices?
   - Stealing funds?
4. Are there reentrancy guards?
5. How are hooks validated during installation?

## Hook Installation Analysis

### 1. Installation Flow Investigation
- Location: PoolManager.sol
- Key Components:
  - validateHookAddress(address hookAddress)
  - initialize() function
  - PoolKey struct validation

### 2. Critical Validation Points
1. Hook Address Validation
   - Must be a contract
   - Must implement IHooks interface
   - Salt-based deployment verification
   - Flags validation (what operations hook can access)

2. Installation Permissions
   - Who can install hooks?
   - Can hooks be changed after installation?
   - Permission inheritance model

3. Potential Attack Vectors
   - Hook Address Spoofing
   - Malicious Hook Installation
   - Permission Bypass Attempts
   - Installation Front-running

### Questions to Answer:
1. Is the hook address immutable after pool creation?
2. What prevents a malicious actor from:
   - Installing unauthorized hooks?
   - Upgrading hooks to malicious versions?
   - Front-running hook installations?
3. How are hook permissions enforced?
4. What validation occurs during pool creation?

### Next Investigation Steps:
1. Review validateHookAddress() implementation
2. Analyze pool creation process
3. Test hook installation edge cases
4. Review permission validation system

## ValidateHookAddress Analysis

### 1. Function Implementation Review
Location: PoolManager.sol

## Hook Flags Analysis

### 1. Flag Implementation
Location: Hooks.sol and IHooks.sol

### 2. Flag Structure
- Flags are stored in the most significant byte of the hook address
- Each bit represents a different permission:
  - BEFORE_INITIALIZE_FLAG = 0x01
  - AFTER_INITIALIZE_FLAG  = 0x02
  - BEFORE_SWAP_FLAG       = 0x04
  - AFTER_SWAP_FLAG        = 0x08
  - BEFORE_MODIFY_FLAG     = 0x10
  - AFTER_MODIFY_FLAG      = 0x20
  - BEFORE_DONATE_FLAG     = 0x40
  - AFTER_DONATE_FLAG      = 0x80

### 3. Potential Vulnerabilities
1. Flag Manipulation
   - Can flags be modified post-deployment?
   - Is flag validation atomic?
   - Can flags be spoofed during validation?

2. Permission Bypass Vectors
   - Hook address manipulation
   - Flag bit masking attacks
   - Cross-function permission leaks

3. Critical Questions
   - How are flags verified during each operation?
   - What prevents unauthorized flag combinations?
   - Can a hook lie about its permissions?

### 4. Test Cases to Develop
1. Flag Validation
   - Test all flag combinations
   - Attempt invalid flag settings
   - Test flag boundary conditions

2. Permission Enforcement
   - Try calling hooks without proper flags
   - Test permission inheritance
   - Attempt permission escalation

3. Edge Cases
   - Zero flags
   - All flags set
   - Invalid flag combinations

## Flag Validation Implementation Analysis

### 1. Flag Validation Flow
Location: Hooks.sol

Key Functions to Analyze:
- hasFlag(address hookAddress, uint8 flag)
- validateHookPermissions(address hookAddress, uint8 flags)
- isValidHookAddress(address hookAddress)

### 2. Validation Points
1. Address Validation
   ```solidity
   // Most significant byte must match flags
   function hasFlag(address hookAddress, uint8 flag) internal pure returns (bool) {
       uint160 addr = uint160(hookAddress);
       uint8 hookFlags = uint8(addr >> 152);
       return hookFlags & flag != 0;
   }
   ```

2. Critical Observations
   - Flags are embedded in address (top byte)
   - No runtime validation of flag changes
   - Potential for address manipulation
   - Bitwise operations could be exploited

### 3. Attack Vectors Identified
1. Address Construction Attack
   - Could malicious actors construct addresses with specific flag patterns?
   - Is there validation of address creation method?

2. Flag Bypass Methods
   ```solidity
   // Example potential attack pattern
   address maliciousHook = address(uint160(
       uint160(validHook) | (uint160(desiredFlags) << 152)
   ));
   ```

3. Permission Escalation
   - Can hooks gain unauthorized permissions through:
     - Address manipulation
     - Cross-contract calls
     - Delegate calls
     - Proxy patterns

### 4. Immediate Test Cases
1. Address Construction Tests
   ```solidity
   function testMaliciousAddressConstruction() public {
       // Test creating addresses with all possible flag combinations
       // Test edge cases in flag bits
       // Test address generation methods
   }
   ```

2. Permission Validation Tests
   ```solidity
   function testPermissionEnforcement() public {
       // Test unauthorized flag access
       // Test flag combination restrictions
       // Test permission inheritance
   }
   ```

### Next Investigation Steps:
1. Review address creation constraints
2. Analyze hook deployment process
3. Test flag validation edge cases
4. Examine cross-contract permission checks

## Address Construction Attack Testing

### 1. Test Environment Setup
```solidity
// Test contract structure
contract HookExploitTest {
    PoolManager public poolManager;
    TestERC20 public token0;
    TestERC20 public token1;
    address public hookAddress;
}
```

### 2. Attack Vectors to Test

1. Flag Manipulation Tests
```solidity
function testFlagManipulation() public {
    // Test Case 1: Create address with all permissions
    address maliciousHook = address(uint160(
        uint160(baseAddress) | (uint160(0xFF) << 152)
    ));
    
    // Test Case 2: Selective permission injection
    address partialHook = address(uint160(
        uint160(baseAddress) | (uint160(BEFORE_SWAP_FLAG | AFTER_SWAP_FLAG) << 152)
    ));
}
```

2. Address Generation Methods
```solidity
function testAddressGeneration() public {
    // Test CREATE2 with specific salt to generate desired address
    bytes32 salt = calculateSaltForDesiredFlags(targetFlags);
    address deployedHook = Create2.deploy(salt, bytecode);
}
```

### 3. Specific Test Scenarios

1. Permission Escalation
   - Deploy hook with minimal permissions
   - Attempt to escalate through address manipulation
   - Test proxy contract interactions

2. Validation Bypass
   - Test contract deployment with invalid flags
   - Attempt to bypass validateHookAddress
   - Test edge cases in flag combinations

3. Cross-contract Attacks
```solidity
function testCrossContractAttack() public {
    // Deploy legitimate hook
    address legitHook = deployHook(minimalFlags);
    
    // Deploy malicious hook that tries to inherit permissions
    address maliciousHook = deployMaliciousHook(legitHook);
    
    // Test interaction patterns
    testInteractions(legitHook, maliciousHook);
}
```

### 4. Potential Exploit Patterns

1. CREATE2 Exploitation
```solidity
// Calculate salt to generate address with desired flags
function calculateExploitSalt(uint8 desiredFlags) internal pure returns (bytes32) {
    // Brute force salt values to find matching address pattern
    for (uint256 i = 0; i < type(uint256).max; i++) {
        bytes32 salt = bytes32(i);
        address predicted = Create2.predictAddress(salt, bytecodeHash);
        if (hasDesiredFlags(predicted, desiredFlags)) {
            return salt;
        }
    }
}
```

2. Proxy Pattern Attack
```solidity
contract MaliciousProxy {
    address immutable legitHook;
    
    constructor(address _legitHook) {
        legitHook = _legitHook;
    }
    
    fallback() external {
        // Attempt to proxy calls while manipulating flags
    }
}
```

### Next Steps:
1. Implement test suite in Foundry
2. Create fuzzing scenarios for address generation
3. Test against actual Uniswap v4 contracts
4. Document any successful exploits

## Foundry Test Implementation

### 1. Test Contract Structure
```solidity:test/HookExploitTest.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PoolManager.sol";
import "../src/interfaces/IHooks.sol";
import "../src/libraries/Hooks.sol";

contract HookExploitTest is Test {
    PoolManager public poolManager;
    TestERC20 public token0;
    TestERC20 public token1;
    
    // Constants for testing
    uint8 constant ALL_FLAGS = 0xFF;
    uint8 constant MINIMAL_FLAGS = 0x01;
    
    function setUp() public {
        // Deploy test environment
        poolManager = new PoolManager(500000);
        token0 = new TestERC20("Token0", "TK0");
        token1 = new TestERC20("Token1", "TK1");
    }
}
```

### 2. Core Test Functions
```solidity:test/HookExploitTest.t.sol
contract HookExploitTest {
    function testAddressManipulation() public {
        // Test 1: Direct Address Manipulation
        address baseAddr = address(0x1234);
        address manipulatedAddr = address(uint160(
            uint160(baseAddr) | (uint160(ALL_FLAGS) << 152)
        ));
        
        vm.expectRevert(); // Should revert if protection works
        poolManager.validateHookAddress(manipulatedAddr);
    }

    function testCreate2Exploitation() public {
        bytes memory bytecode = type(MaliciousHook).creationCode;
        bytes32 salt = calculateExploitSalt(ALL_FLAGS, bytecode);
        
        address deployedHook = Create2.deploy(0, salt, bytecode);
        
        // Verify if the deployed address has the expected flags
        assertTrue(Hooks.hasFlag(deployedHook, ALL_FLAGS));
    }
}
```

### 3. Fuzzing Tests
```solidity:test/HookExploitTest.t.sol
contract HookExploitTest {
    function testFuzz_FlagCombinations(uint8 flags) public {
        vm.assume(flags != 0);
        
        // Try to create an address with these flags
        address attemptedHook = generateHookAddress(flags);
        
        // Test validation
        try poolManager.validateHookAddress(attemptedHook) {
            // If successful, verify flags are valid
            assertTrue(isValidFlagCombination(flags));
        } catch {
            // If failed, verify flags were invalid
            assertFalse(isValidFlagCombination(flags));
        }
    }
}
```

### 4. Helper Functions
```solidity:test/HookExploitTest.t.sol
contract HookExploitTest {
    function generateHookAddress(uint8 flags) internal pure returns (address) {
        // Generate base address
        uint160 baseAddr = uint160(uint256(keccak256(abi.encodePacked(flags))));
        // Insert flags into most significant byte
        return address(baseAddr | (uint160(flags) << 152));
    }
    
    function isValidFlagCombination(uint8 flags) internal pure returns (bool) {
        // Implement validation logic based on Uniswap rules
        return true; // TODO: Implement actual validation
    }
}
```

### 5. Malicious Contract Implementation
```solidity:test/MaliciousHook.sol
contract MaliciousHook is IHooks {
    // Implement required interfaces but with malicious logic
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96) 
        external override returns (bytes4) {
        // Attempt privilege escalation
        return IHooks.beforeInitialize.selector;
    }
    
    // Implement other required functions...
}
```

### Next Implementation Steps:
1. Complete the malicious hook implementation
2. Add more sophisticated fuzzing scenarios
3. Implement invariant tests
4. Add cross-contract interaction tests

## Complete Malicious Hook Implementation

### 1. Base Malicious Hook
```solidity:test/MaliciousHook.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../src/interfaces/IHooks.sol";
import "../src/interfaces/IPoolManager.sol";
import "../src/types/PoolKey.sol";

contract MaliciousHook is IHooks {
    // Storage variables for attack vectors
    mapping(address => uint256) private stolenFunds;
    address private attacker;
    bool private isReentering;
    
    constructor(address _attacker) {
        attacker = _attacker;
    }
    
    // Attack Vector 1: Reentrancy Attack
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params
    ) external returns (bytes4) {
        if (!isReentering) {
            isReentering = true;
            // Attempt reentrancy attack
            IPoolManager(msg.sender).swap(key, params);
            isReentering = false;
        }
        return IHooks.beforeSwap.selector;
    }
    
    // Attack Vector 2: State Manipulation
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta
    ) external returns (bytes4) {
        // Attempt to manipulate pool state
        try IPoolManager(msg.sender).modifyPosition(
            key,
            IPoolManager.ModifyPositionParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: int256(delta.amount0())
            })
        ) {} catch {}
        return IHooks.afterSwap.selector;
    }
    
    // Attack Vector 3: Permission Escalation
    function beforeModifyPosition(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata params
    ) external returns (bytes4) {
        // Attempt to call privileged functions
        (bool success,) = msg.sender.call(
            abi.encodeWithSignature("privilegedFunction()")
        );
        return IHooks.beforeModifyPosition.selector;
    }
    
    // Attack Vector 4: Fund Extraction
    function afterModifyPosition(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata params,
        BalanceDelta delta
    ) external returns (bytes4) {
        // Attempt to extract funds
        if (delta.amount0() > 0) {
            stolenFunds[attacker] += uint256(delta.amount0());
        }
        return IHooks.afterModifyPosition.selector;
    }
    
    // Attack Vector 5: Cross-function State Attack
    uint256 private storedDelta;
    
    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1
    ) external returns (bytes4) {
        storedDelta = amount0; // Store for cross-function attack
        return IHooks.beforeDonate.selector;
    }
    
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1
    ) external returns (bytes4) {
        if (storedDelta > 0) {
            // Use stored information for attack
            try IPoolManager(msg.sender).donate(
                key,
                storedDelta,
                0
            ) {} catch {}
        }
        return IHooks.afterDonate.selector;
    }
    
    // Attack Vector 6: Initialization Attack
    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96
    ) external returns (bytes4) {
        // Attempt to manipulate initial state
        try IPoolManager(msg.sender).initialize(
            key,
            sqrtPriceX96 + 1 // Slightly manipulated price
        ) {} catch {}
        return IHooks.beforeInitialize.selector;
    }
    
    // Fallback for proxy attacks
    fallback() external {
        // Attempt to execute privileged operations
        (bool success,) = msg.sender.call(msg.data);
    }
    
    // Helper function to withdraw stolen funds
    function withdraw() external {
        require(msg.sender == attacker);
        uint256 amount = stolenFunds[attacker];
        stolenFunds[attacker] = 0;
        payable(attacker).transfer(amount);
    }
}
```

### 2. Test Cases for Malicious Hook
```solidity:test/MaliciousHookTest.t.sol
contract MaliciousHookTest is Test {
    function testReentrancyAttack() public {
        // Setup
        address attacker = address(0xBEEF);
        MaliciousHook hook = new MaliciousHook(attacker);
        
        // Test reentrancy attack
        vm.startPrank(attacker);
        // ... implement test
        vm.stopPrank();
    }
    
    function testStateManipulation() public {
        // ... implement test
    }
    
    function testPermissionEscalation() public {
        // ... implement test
    }
    
    // Add more test cases for each attack vector
}
```

### Next Implementation Steps:
1. Complete test cases for each attack vector
2. Add invariant tests for state consistency
3. Implement fuzzing scenarios for edge cases
4. Add cross-contract interaction tests

## Complete Test Cases for Attack Vectors

### 1. Test Implementation
```solidity:test/MaliciousHookTest.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PoolManager.sol";
import "../src/interfaces/IHooks.sol";
import "./MaliciousHook.sol";

contract MaliciousHookTest is Test {
    PoolManager public poolManager;
    TestERC20 public token0;
    TestERC20 public token1;
    MaliciousHook public hook;
    address public attacker;
    
    // Test setup
    function setUp() public {
        attacker = address(0xBEEF);
        poolManager = new PoolManager(500000);
        token0 = new TestERC20("Token0", "TK0");
        token1 = new TestERC20("Token1", "TK1");
        hook = new MaliciousHook(attacker);
        
        // Setup initial liquidity
        token0.mint(address(this), 1000e18);
        token1.mint(address(this), 1000e18);
    }
    
    // Test Vector 1: Reentrancy Attack
    function testReentrancyAttack() public {
        // Setup pool with hook
        PoolKey memory key = PoolKey({
            token0: address(token0),
            token1: address(token1),
            fee: 3000,
            hookAddress: address(hook),
            poolManager: address(poolManager)
        });
        
        // Initialize pool
        poolManager.initialize(key, SQRT_RATIO_1_1);
        
        // Attempt reentrancy attack
        vm.startPrank(attacker);
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 100e18,
            sqrtPriceLimitX96: 0
        });
        
        // Should revert if reentrancy protection works
        vm.expectRevert("ReentrancyGuard: reentrant call");
        poolManager.swap(key, params);
        vm.stopPrank();
    }
    
    // Test Vector 2: State Manipulation
    function testStateManipulation() public {
        PoolKey memory key = createTestPool();
        
        // Record initial state
        (uint160 sqrtPriceX96Before,,,) = poolManager.getSlot0(key.toId());
        
        // Attempt state manipulation through hook
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 10e18,
            sqrtPriceLimitX96: 0
        });
        
        poolManager.swap(key, params);
        
        // Verify state wasn't manipulated unexpectedly
        (uint160 sqrtPriceX96After,,,) = poolManager.getSlot0(key.toId());
        assertNotEq(sqrtPriceX96Before, sqrtPriceX96After);
    }
    
    // Test Vector 3: Permission Escalation
    function testPermissionEscalation() public {
        PoolKey memory key = createTestPool();
        
        // Attempt privilege escalation
        vm.startPrank(attacker);
        ModifyPositionParams memory params = ModifyPositionParams({
            tickLower: -1000,
            tickUpper: 1000,
            liquidityDelta: 100e18
        });
        
        // Should fail due to lack of permissions
        vm.expectRevert("Unauthorized");
        poolManager.modifyPosition(key, params);
        vm.stopPrank();
    }
    
    // Test Vector 4: Fund Extraction
    function testFundExtraction() public {
        PoolKey memory key = createTestPool();
        uint256 initialBalance = token0.balanceOf(address(poolManager));
        
        // Attempt fund extraction through hook
        vm.startPrank(attacker);
        ModifyPositionParams memory params = ModifyPositionParams({
            tickLower: -1000,
            tickUpper: 1000,
            liquidityDelta: 100e18
        });
        
        poolManager.modifyPosition(key, params);
        
        // Verify no funds were extracted
        assertEq(token0.balanceOf(address(poolManager)), initialBalance);
        vm.stopPrank();
    }
    
    // Test Vector 5: Cross-function State Attack
    function testCrossFunctionStateAttack() public {
        PoolKey memory key = createTestPool();
        
        // Attempt cross-function attack
        vm.startPrank(attacker);
        poolManager.donate(key, 100e18, 100e18);
        
        // Verify state consistency
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
        assertTrue(sqrtPriceX96 > 0);
        vm.stopPrank();
    }
    
    // Test Vector 6: Initialization Attack
    function testInitializationAttack() public {
        PoolKey memory key = PoolKey({
            token0: address(token0),
            token1: address(token1),
            fee: 3000,
            hookAddress: address(hook),
            poolManager: address(poolManager)
        });
        
        uint160 initialPrice = SQRT_RATIO_1_1;
        
        // Attempt initialization attack
        poolManager.initialize(key, initialPrice);
        
        // Verify initialization wasn't manipulated
        (uint160 actualPrice,,,) = poolManager.getSlot0(key.toId());
        assertEq(actualPrice, initialPrice);
    }
    
    // Helper function to create test pool
    function createTestPool() internal returns (PoolKey memory) {
        PoolKey memory key = PoolKey({
            token0: address(token0),
            token1: address(token1),
            fee: 3000,
            hookAddress: address(hook),
            poolManager: address(poolManager)
        });
        
        poolManager.initialize(key, SQRT_RATIO_1_1);
        return key;
    }
}
```

### 2. Additional Edge Case Tests
```solidity:test/MaliciousHookTest.t.sol
contract MaliciousHookTest {
    // Test concurrent attacks
    function testConcurrentAttacks() public {
        PoolKey memory key = createTestPool();
        
        // Attempt multiple attack vectors simultaneously
        vm.startPrank(attacker);
        
        // Combine swap and modify position attacks
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 10e18,
            sqrtPriceLimitX96: 0
        });
        
        ModifyPositionParams memory posParams = ModifyPositionParams({
            tickLower: -1000,
            tickUpper: 1000,
            liquidityDelta: 100e18
        });
        
        // Execute concurrent operations
        poolManager.swap(key, swapParams);
        poolManager.modifyPosition(key, posParams);
        
        vm.stopPrank();
    }
}
```

### Next Steps:
1. Run the test suite against actual Uniswap v4 contracts
2. Add more edge cases and combinations
3. Implement invariant tests
4. Create fuzzing scenarios