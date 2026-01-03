# BatchNftSend Contract Interaction Guide

This guide explains how to interact with the `BatchNftSend` contract, which provides secure bulk NFT transfers and restricted multicall functionality.

## Security Features
- **Restricted Multicall**: The `aggregate` functions (Multicall3 logic) are restricted to `onlyOwner`. This prevents attackers from using the contract to make arbitrary calls (like stealing user tokens via `transferFrom`) using the contract's context.
- **Safe NFT Transfers**: The public `multiSendNfts` function forces `msg.sender` as the `from` address. You can only send NFTs that *you* own or have approved.

## User Functions

### `multiSendNfts`
Sends multiple ERC721 tokens to a single recipient.

**Parameters:**
- `address[] nftContracts`: Array of NFT contract addresses.
- `uint256[] tokenIds`: Array of Token IDs to send.
- `address recipient`: The destination address.
- `uint256 deadline`: Transaction expiration timestamp.

**Requirements:**
- `nftContracts` and `tokenIds` must have the same length.
- `msg.value` must cover the total fee (`fee`).
- You must call `approve()` or `setApprovalForAll()` on the NFT contract for the `BatchNftSend` contract address.

**Example (Forge Cast):**
```bash
# Sending 2 NFTs (Fee: 0.2 ETH)
# Use --rpc-url sei_mainnet or sei_testnet
cast send <CONTRACT_ADDRESS> "multiSendNfts(address[],uint256[],address)" "[0xNFT1,0xNFT2]" "[1,55]" <RECIPIENT> --value 200000000000000000 --rpc-url sei_mainnet --private-key <PRIVATE_KEY>
```

---

## Admin Functions (Owner Only)

### `aggregate`, `aggregate3`, `aggregate3Value`
Executes a batch of arbitrary calls. These are **only accessible by the owner** to ensure security.

### `setFee`
Updates the fee per NFT sent.

### `withdrawEther`
Withdraws collected fees.

---

## Deployment & Verification

You can deploy to either Sei Mainnet or Testnet by specifying the network in the `--rpc-url` flag.

**Deploy to Mainnet:**
```bash
source .env && forge script script/DeployBatchNftSend.s.sol:DeployBatchNftSend --rpc-url sei_mainnet --broadcast --gas-limit 6000000 -vvvv
```

**Deploy to Testnet:**
```bash
source .env && forge script script/DeployBatchNftSend.s.sol:DeployBatchNftSend --rpc-url sei_testnet --broadcast --gas-limit 6000000 -vvvv
```

**Verify (Mainnet):**
```bash
source .env && forge verify-contract <CONTRACT_ADDRESS> contracts/BatchNftSend.sol:BatchNftSend \
  --verifier etherscan \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=1329" \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch
```

**Verify (Testnet):**
```bash
source .env && forge verify-contract <CONTRACT_ADDRESS> contracts/BatchNftSend.sol:BatchNftSend \
  --rpc-url sei_testnet \
  --verifier blockscout \
  --verifier-url "https://seitrace.com/atlantic-2/api" \
  --watch
```

