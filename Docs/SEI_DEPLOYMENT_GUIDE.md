# Sei Mainnet Deployment & Verification Guide (Foundry/WSL)

This guide outlines the steps to deploy and verify smart contracts on the Sei Mainnet using Foundry from a WSL (Windows Subsystem for Linux) environment.

## 1. Prerequisites

- **WSL Installed**: Ensure you have a Linux distribution running on Windows.
- **Foundry Installed**: Run `foundryup` in your WSL terminal to install or update Foundry.
- **Git Initialized**: Forge requires a git repository for managing dependencies.
  ```bash
  git init
  ```

## 2. Project Configuration

### foundry.toml
Configure your `foundry.toml` with the Sei Mainnet and Testnet RPCs.

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
remappings = [
    "hardhat/=lib/forge-std/src/"
]

[rpc_endpoints]
sei_mainnet = "https://evm-rpc.sei-apis.com"
sei_testnet = "https://evm-rpc-testnet.sei-apis.com"

[etherscan]
sei_mainnet = { key = "${ETHERSCAN_API_KEY}", url = "https://seitrace.com/pacific-1" }
sei_testnet = { key = "${ETHERSCAN_API_KEY}", url = "https://seitrace.com/atlantic-2" }
```

### Environment Variables (.env)
Create a `.env` file in the root directory. **Note: Ensure Unix line endings (`LF`) and the `0x` prefix for the private key.**

```env
# Network Choice
RPC_URL=https://evm-rpc.sei-apis.com
# Use for testnet: RPC_URL=https://evm-rpc-testnet.sei-apis.com

PRIVATE_KEY=0xyour_private_key_here
ETHERSCAN_API_KEY=your_api_key_here
```

## 3. Installation

Install the Forge Standard Library:
```bash
forge install foundry-rs/forge-std
```

## 4. Deployment

Use a Foundry script to deploy your contract. You can choose the network by passing the RPC URL or the name from `foundry.toml`.

**Deployment Command (Mainnet):**
```bash
source .env && forge script script/DeployBatchNftSend.s.sol:DeployBatchNftSend --rpc-url sei_mainnet --broadcast --gas-limit 6000000 -vvvv
```

**Deployment Command (Testnet):**
```bash
source .env && forge script script/DeployBatchNftSend.s.sol:DeployBatchNftSend --rpc-url sei_testnet --broadcast --gas-limit 6000000 -vvvv
```

## 5. Verification

### Verification on Mainnet (Seitrace)
```bash
source .env && forge verify-contract <CONTRACT_ADDRESS> contracts/BatchNftSend.sol:BatchNftSend \
  --rpc-url sei_mainnet \
  --verifier etherscan \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=1329" \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch
```

### Verification on Testnet (Atlantic-2)
```bash
source .env && forge verify-contract <CONTRACT_ADDRESS> contracts/BatchNftSend.sol:BatchNftSend \
  --rpc-url sei_testnet \
  --verifier blockscout \
  --verifier-url "https://seitrace.com/atlantic-2/api" \
  --watch
```

## Troubleshooting
- **Line Endings**: If `source .env` fails in WSL, run `sed -i "s/\r$//" .env`.
- **Private Key**: Forge requires the `0x` prefix for hex strings in `vm.envUint`.
- **EIP-3855**: Sei might not support `PUSH0`. If deployment fails, use a compiler version lower than `0.8.20` or set `evm_version = "paris"` in `foundry.toml`.

