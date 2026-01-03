# BatchNftSend

<div align="center">

![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.24-363636?style=for-the-badge&logo=solidity&logoColor=white)
![Foundry](https://img.shields.io/badge/Foundry-2.0-1C1C1C?style=for-the-badge&logo=ethereum&logoColor=white)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-Contracts-4E5EE4?style=for-the-badge&logo=openzeppelin&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Sei Network](https://img.shields.io/badge/Sei-Network-red?style=for-the-badge)

**A secure, gas-optimized smart contract for batch ERC721 NFT transfers with Multicall functionality.**

[Features](#-features) •
[Installation](#-installation) •
[Usage](#-usage) •
[Deployment](#-deployment) •
[Documentation](#-documentation)

</div>

---

## 🎯 Overview

**BatchNftSend** is a production-ready smart contract designed for efficient bulk NFT transfers on EVM-compatible networks. It enables users to transfer multiple ERC721 tokens to a single recipient in one transaction, significantly reducing gas costs compared to individual transfers.

### Key Highlights

- ✅ **Batch Transfer** - Send up to 50 NFTs in a single transaction
- ✅ **Gas Optimized** - Custom errors, calldata arrays, and unchecked arithmetic
- ✅ **Secure by Design** - ReentrancyGuard, Pausable, and Two-Step Ownership
- ✅ **ERC165 Validation** - Automatic verification of ERC721 compliance
- ✅ **Multicall Support** - Owner-restricted aggregate functions for advanced operations
- ✅ **Sei Network Ready** - Pre-configured for Sei Mainnet and Testnet deployment

---

## ✨ Features

### Core Functionality

| Feature | Description |
|---------|-------------|
| **Multi-NFT Transfer** | Transfer multiple NFTs from different contracts to a single recipient |
| **Fee System** | Configurable per-transaction fee with 1 ETH maximum cap |
| **Deadline Protection** | Transaction expiration to prevent stale executions |
| **Excess Refund** | Automatic refund of overpaid fees |

### Security Features

| Feature | Implementation |
|---------|----------------|
| **Reentrancy Protection** | OpenZeppelin's `ReentrancyGuard` |
| **Emergency Pause** | `Pausable` pattern for emergency stops |
| **Safe Ownership** | Two-step ownership transfer (`Ownable2Step`) |
| **Batch Limits** | Maximum 50 NFTs per batch, 100 calls per multicall |

---

## 📦 Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (Forge, Cast, Anvil)
- PowerShell (Windows)

### Clone the Repository

```powershell
git clone https://github.com/jim788e/BatchNftSend.git
cd BatchNftSend
```

### Install Dependencies

```powershell
forge install
```

### Environment Setup

Create a `.env` file in the project root:

```env
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
```

---

## 🔧 Usage

### Build the Project

```powershell
forge build
```

### Run Tests

```powershell
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path tests/BatchNftSend.t.sol

# Generate gas report
forge test --gas-report
```

### Format Code

```powershell
forge fmt
```

---

## 🚀 Deployment

### Deploy to Sei Testnet

```powershell
# Load environment variables and deploy
$env:PRIVATE_KEY = (Get-Content .env | Select-String "PRIVATE_KEY" | ForEach-Object { $_.Line.Split("=")[1] })
forge script script/DeployBatchNftSend.s.sol:DeployBatchNftSend --rpc-url "https://evm-rpc-testnet.sei-apis.com" --broadcast --gas-limit 6000000 -vvvv
```

### Deploy to Sei Mainnet

```powershell
$env:PRIVATE_KEY = (Get-Content .env | Select-String "PRIVATE_KEY" | ForEach-Object { $_.Line.Split("=")[1] })
forge script script/DeployBatchNftSend.s.sol:DeployBatchNftSend --rpc-url "https://evm-rpc.sei-apis.com" --broadcast --gas-limit 6000000 -vvvv
```

### Verify Contract

**Sei Mainnet:**
```powershell
forge verify-contract <CONTRACT_ADDRESS> contracts/BatchNftSend.sol:BatchNftSend `
  --verifier etherscan `
  --verifier-url "https://api.etherscan.io/v2/api?chainid=1329" `
  --etherscan-api-key $env:ETHERSCAN_API_KEY `
  --watch
```

**Sei Testnet:**
```powershell
forge verify-contract <CONTRACT_ADDRESS> contracts/BatchNftSend.sol:BatchNftSend `
  --rpc-url "https://evm-rpc-testnet.sei-apis.com" `
  --verifier blockscout `
  --verifier-url "https://seitrace.com/atlantic-2/api" `
  --watch
```

---

## 📖 Contract Interface

### User Functions

#### `multiSendNfts`

Sends multiple ERC721 tokens to a single recipient.

```solidity
function multiSendNfts(
    address[] calldata nftContracts,
    uint256[] calldata tokenIds,
    address recipient,
    uint256 deadline
) external payable
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `nftContracts` | `address[]` | Array of NFT contract addresses |
| `tokenIds` | `uint256[]` | Token IDs corresponding to each contract |
| `recipient` | `address` | Destination address for the NFTs |
| `deadline` | `uint256` | Unix timestamp by which transaction must execute |

**Example (Cast):**
```powershell
cast send <CONTRACT_ADDRESS> "multiSendNfts(address[],uint256[],address,uint256)" `
  "[0xNFT1,0xNFT2]" "[1,55]" <RECIPIENT> <DEADLINE_TIMESTAMP> `
  --value 0.1ether `
  --rpc-url "https://evm-rpc.sei-apis.com" `
  --private-key $env:PRIVATE_KEY
```

### Admin Functions (Owner Only)

| Function | Description |
|----------|-------------|
| `setFee(uint256 _fee)` | Update the per-transaction fee |
| `pause()` | Pause all contract operations |
| `unpause()` | Resume contract operations |
| `withdrawEther(uint256 amount)` | Withdraw accumulated fees |
| `aggregate(Call[])` | Execute multiple calls atomically |
| `aggregate3(Call3[])` | Execute calls with optional failure tolerance |
| `aggregate3Value(Call3Value[])` | Execute calls with ETH value transfers |

---

## 📁 Project Structure

```
BatchNftSend/
├── contracts/
│   └── BatchNftSend.sol      # Main contract
├── script/
│   └── DeployBatchNftSend.s.sol  # Deployment script
├── tests/
│   ├── BatchNftSend.t.sol    # Test suite
│   ├── README.md             # Test documentation
│   └── TEST_VERIFICATION.md  # Test verification report
├── Docs/
│   ├── BATCHNFTSEND_GUIDE.md     # User guide
│   ├── TECHNICAL_ANALYSIS.md     # Technical documentation
│   ├── PROFESSIONAL_AUDIT.md     # Security audit report
│   └── SEI_DEPLOYMENT_GUIDE.md   # Sei-specific deployment
├── lib/
│   ├── forge-std/            # Foundry standard library
│   └── openzeppelin-contracts/  # OpenZeppelin contracts
├── foundry.toml              # Foundry configuration
└── README.md                 # This file
```

---

## 📚 Documentation

Comprehensive documentation is available in the `Docs/` directory:

| Document | Description |
|----------|-------------|
| [BATCHNFTSEND_GUIDE.md](./Docs/BATCHNFTSEND_GUIDE.md) | User interaction guide |
| [TECHNICAL_ANALYSIS.md](./Docs/TECHNICAL_ANALYSIS.md) | In-depth technical analysis |
| [PROFESSIONAL_AUDIT.md](./Docs/PROFESSIONAL_AUDIT.md) | Security audit findings |
| [SEI_DEPLOYMENT_GUIDE.md](./Docs/SEI_DEPLOYMENT_GUIDE.md) | Sei Network deployment guide |

---

## ⛽ Gas Estimates

| Operation | Estimated Gas |
|-----------|---------------|
| Single NFT transfer | ~80,000 - 100,000 |
| Batch of 10 NFTs | ~600,000 - 800,000 |
| Batch of 50 NFTs | ~3,000,000 - 4,000,000 |

*Actual costs vary by NFT contract implementation and network conditions.*

---

## 🔐 Security

This contract implements multiple security measures:

- **ReentrancyGuard** - Protection against reentrancy attacks
- **Pausable** - Emergency stop mechanism
- **Ownable2Step** - Two-step ownership transfer
- **ERC165 Validation** - DoS protection via try-catch wrapped interface checks
- **Batch & Multicall Limits** - Gas limit DoS prevention
- **Deadline Validation** - Stale transaction protection
- **Checked Arithmetic** - Overflow protection in value accumulation

### Audit Status

🔒 See [PROFESSIONAL_AUDIT.md](./Docs/PROFESSIONAL_AUDIT.md) for the complete security audit report.

---

## 🛠️ Development

### Running Local Node

```powershell
anvil
```

### Testing with Local Node

```powershell
forge test --rpc-url http://localhost:8545
```

### Generate Coverage Report

```powershell
forge coverage
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📞 Support

For support, please open an issue in the GitHub repository.

---

<div align="center">

**Built with ❤️ using Foundry**

</div>
