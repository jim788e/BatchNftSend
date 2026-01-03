# Test Suite Guide

This directory contains comprehensive test suites for the BatchNftSend smart contract.

## Test Files

- **`BatchNftSend.t.sol`** - Complete test suite for the BatchNftSend contract (ERC721 batch transfers)

## Running Tests

### Prerequisites

Make sure you have Foundry installed. If not, install it:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Run All Tests

```bash
forge test
```

### Run Specific Test File

```bash
# Test BatchNftSend contract
forge test --match-path tests/BatchNftSend.t.sol
```

### Run Specific Test Function

```bash
# Run a single test
forge test --match-test test_MultiSendNfts_SingleNFT

# Run tests matching a pattern
forge test --match-test "test_MultiSend*"
```

### Run with Verbose Output

```bash
forge test -vvv
```

### Run with Gas Reporting

```bash
forge test --gas-report
```

### Run Fuzz Tests

Fuzz tests are included and will run automatically with `forge test`. They test with random inputs:

```bash
# Run fuzz tests with more iterations
forge test --fuzz-runs 10000
```

## Test Coverage

### BatchNftSend.t.sol Coverage

✅ **Unit Tests:**
- ✅ multiSendNfts with valid inputs (single and multiple NFTs)
- ✅ multiSendNfts with empty arrays (reverts)
- ✅ multiSendNfts with mismatched array lengths (reverts)
- ✅ multiSendNfts exceeding MAX_BATCH_SIZE (reverts)
- ✅ multiSendNfts to zero address (reverts)
- ✅ multiSendNfts with insufficient fee (reverts)
- ✅ multiSendNfts with non-ERC721 contract (reverts)
- ✅ multiSendNfts with faulty contract (DoS protection)
- ✅ multiSendNfts refund of excess ETH
- ✅ multiSendNfts with deadline validation
- ✅ setFee by owner (succeeds)
- ✅ setFee by non-owner (reverts)
- ✅ setFee exceeding MAX_FEE (reverts)
- ✅ pause/unpause functionality
- ✅ transferOwnership two-step process
- ✅ transferOwnership by non-owner (reverts)
- ✅ withdrawEther by owner (with event emission)
- ✅ withdrawEther exceeding balance (reverts)
- ✅ withdrawEther with zero amount (reverts)
- ✅ aggregate multicall function
- ✅ aggregate3 multicall function
- ✅ aggregate3Value multicall function with exact value matching
- ✅ Multicall array size limits (MAX_MULTICALL_SIZE = 100)

✅ **Integration Tests:**
- ✅ Transfer from multiple different NFT contracts
- ✅ Transfer NFTs requiring approval
- ✅ Gas consumption benchmarks for various batch sizes
- ✅ Multiple multicall operations

✅ **Fuzz Tests:**
- ✅ Random array sizes (1-50)
- ✅ Random fee amounts

**Total: 43+ tests covering all contract functionality**

## Test Structure

Each test file follows this structure:

1. **Setup (`setUp` function)** - Deploys contracts and prepares test environment
2. **Mock Contracts** - Helper contracts for testing (MockERC721, FaultyERC721, etc.)
3. **Unit Tests** - Test individual functions and edge cases
4. **Integration Tests** - Test interactions between components
5. **Fuzz Tests** - Test with random inputs to find edge cases
6. **Gas Benchmarks** - Measure gas consumption

## Test Configuration

### Foundry Configuration
- Test directory: `tests/` (configured in `foundry.toml`)
- Source directory: `contracts/`
- Libraries: `lib/`
- Solidity version: `^0.8.24`

### Test Setup
The `setUp()` function:
- Funds test accounts with ETH using `vm.deal()`
- Deploys the BatchNftSend contract with initial fee
- Deploys mock NFT contracts (MockERC721, FaultyERC721)
- Mints test NFTs to user accounts
- Sets up approvals for batch transfers

## Understanding Test Output

### Passing Tests
```
[PASS] test_MultiSendNfts_SingleNFT() (gas: 123456)
```

### Failing Tests
```
[FAIL. Reason: Empty batch] test_MultiSendNfts_EmptyBatch() (gas: 12345)
```

### Fuzz Test Failures
When a fuzz test fails, Foundry will show the specific inputs that caused the failure:
```
[FAIL. Reason: assertion failed] testFuzz_MultiSendNfts_ValidInputs(uint8,uint256) (runs: 1000, μ: 123456, ~: 123456)
  Counterexample: calldata=0x..., args=[51, 1000000000000000000]
```

## Best Practices

1. **Always run tests before deploying** - Ensure all tests pass
2. **Check gas reports** - Optimize functions with high gas costs
3. **Review fuzz test results** - They may reveal unexpected edge cases
4. **Run with different verbosity levels** - Use `-vvv` for detailed debugging

## Expected Test Results

All tests should:
- ✅ Compile successfully (no warnings)
- ✅ Run without errors
- ✅ Pass all assertions (43+ tests)
- ✅ Handle edge cases properly
- ✅ Verify all audit fixes
- ✅ Test access controls
- ✅ Test revert conditions

## Known Issues and Fixes

### Issues Fixed During Development

1. **Solidity Version Compatibility**
   - **Issue**: Test file initially used `0.8.22` but OpenZeppelin ERC721 requires `^0.8.24`
   - **Fix**: Updated `tests/BatchNftSend.t.sol` to use `^0.8.24`

2. **FaultyERC721 Contract Signature**
   - **Issue**: `supportsInterface` function state mutability warning
   - **Fix**: Changed to `pure` since it doesn't read state (only reverts)

3. **Missing ETH Funding**
   - **Issue**: Test accounts didn't have ETH for transactions
   - **Fix**: Added `vm.deal()` calls in `setUp()` function:
     - `vm.deal(owner, 100 ether)`
     - `vm.deal(user, 100 ether)`
     - `vm.deal(recipient, 100 ether)`

4. **Multicall Value Tests**
   - **Issue**: ERC721 functions don't accept ETH, causing test failures
   - **Fix**: Updated tests to use empty `callData` for direct ETH transfers

## Troubleshooting

### Tests Fail to Compile
- Check Solidity version compatibility (must be `^0.8.24`)
- Ensure all imports are correct
- Verify remappings in `foundry.toml`

### Tests Pass Locally but Fail in CI
- Check for environment-specific issues
- Verify test isolation (no shared state)
- Check for timing-dependent tests
- Ensure test accounts are properly funded

### Gas Estimates Too High
- Review gas benchmarks in test output
- Consider optimizing loops and storage operations
- Use `--gas-report` for detailed analysis

### Compiler Warnings
- Function state mutability warnings: Ensure functions use the most restrictive mutability (`pure` > `view` > `nonpayable` > `payable`)
- Override warnings: Ensure function signatures match parent contracts exactly

## Continuous Integration

Add to your CI/CD pipeline:

```yaml
- name: Run Foundry tests
  run: forge test
```

## Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry Testing Guide](https://book.getfoundry.sh/forge/tests)
- [OpenZeppelin Test Helpers](https://docs.openzeppelin.com/test-helpers)

