# Uniswap V4 Hook Security Testing Suite

A comprehensive testing suite for identifying potential vulnerabilities in Uniswap V4's hook system. This project aims to help security researchers and developers understand and test the security boundaries of Uniswap V4's hook mechanism.

## Overview

This test suite explores various attack vectors against Uniswap V4's hook system, including:

- Malicious hook installation
- State manipulation attempts
- Reentrancy attacks
- Fee manipulation
- Sandwich attacks

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity ^0.8.24
- Git

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/uniswap-v4-hook-testing
cd uniswap-v4-hook-testing
```

2. Install dependencies:
```bash
forge install
```

## Running Tests

Run all tests:
```bash
forge test -vvv
```

Run specific test contract:
```bash
forge test --match-contract HookVulnerabilityTest -vvv
```

## Test Cases

### 1. Malicious Hook Installation
Tests if hooks can be installed with unauthorized permissions.

### 2. State Manipulation
Verifies that hooks cannot manipulate pool state outside of allowed operations.

### 3. Reentrancy Protection
Tests Uniswap V4's protection against reentrancy attacks through hooks.

### 4. Fee Manipulation
Ensures hooks cannot extract excessive fees from users.

### 5. Sandwich Attack Protection
Tests protection against sandwich attacks orchestrated through hooks.

## Project Structure

```
├── src/
├── test/
│   ├── HookVulnerabilityTest.t.sol   # Main test suite
│   └── mocks/
│       └── MaliciousHooks.sol        # Mock malicious hooks
├── lib/
│   └── ...                           # Dependencies
└── README.md
```

## Security Findings

The test suite has identified several key security properties of Uniswap V4's hook system:

1. Hook Address Validation
   - Hooks must be deployed to addresses with specific flags in their least significant bits
   - These flags determine which hooks can be called
   - The flags are validated during pool initialization and hook calls

2. Reentrancy Protection
   - Built-in reentrancy protection via the `ManagerLocked` error
   - Attempts to reenter the pool manager during hook callbacks are blocked

3. State Manipulation Protection
   - Hooks can't directly manipulate pool state
   - State changes must go through proper pool manager functions

4. Fee Manipulation Protection
   - Hooks can't arbitrarily drain user funds through fee manipulation
   - Fee calculations are controlled by the pool manager

5. Sandwich Attack Protection
   - While hooks can observe trades, they can't directly manipulate prices
   - Price changes must go through proper pool manager functions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This code is provided for educational and testing purposes only. Do not use in production without proper security review.
