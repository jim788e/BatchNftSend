// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title BatchNftSend
 * @dev Secure batch sending for ERC721 NFTs. Inherits Multicall-like functionality but restricts arbitrary calls.
 */
contract BatchNftSend is ReentrancyGuard, Ownable2Step, Pausable {
    // --- Custom Errors ---
    error FeeExceedsMaximum();
    error EmptyBatch();
    error BatchTooLarge(uint256 size, uint256 max);
    error LengthMismatch();
    error InvalidRecipient();
    error InsufficientFee(uint256 required, uint256 sent);
    error InvalidNFTContract();
    error NotERC721Contract();
    error InterfaceCheckFailed();
    error RefundFailed();
    error TransactionExpired();
    error ZeroAmount();
    error InsufficientBalance();
    error WithdrawFailed();
    error MulticallFailed();
    error ValueMismatch();
    error TooManyCalls(uint256 size, uint256 max);

    struct Call {
        address target;
        bytes callData;
    }

    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result3 {
        bool success;
        bytes returnData;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    // Result3Value removed as it is identical to Result3

    uint256 public fee;
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant MAX_MULTICALL_SIZE = 100;
    uint256 public constant MAX_FEE = 1 ether;
    
    event NftsSent(address indexed nftContract, address indexed recipient, uint256 tokenId);
    event FeeUpdated(uint256 newFee);
    event MulticallExecuted(uint256 callCount, address indexed caller);
    event EtherWithdrawn(address indexed recipient, uint256 amount);

    constructor(uint256 _initialFee) Ownable(msg.sender) {
        if (_initialFee > MAX_FEE) revert FeeExceedsMaximum();
        fee = _initialFee;
    }

    /**
     * @dev Sets the fee for batch transfers.
     * @param _fee The new fee in wei.
     */
    function setFee(uint256 _fee) external onlyOwner {
        if (_fee > MAX_FEE) revert FeeExceedsMaximum();
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Sends multiple NFTs to a single recipient.
     * @param nftContracts Array of NFT contract addresses.
     * @param tokenIds Array of token IDs corresponding to each contract.
     * @param recipient The address to receive the NFTs.
     * @param deadline Timestamp by which the transaction must be mined.
     */
    function multiSendNfts(
        address[] calldata nftContracts,
        uint256[] calldata tokenIds,
        address recipient,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused {
        if (block.timestamp > deadline) revert TransactionExpired();
        if (nftContracts.length == 0) revert EmptyBatch();
        if (nftContracts.length > MAX_BATCH_SIZE) revert BatchTooLarge(nftContracts.length, MAX_BATCH_SIZE);
        if (nftContracts.length != tokenIds.length) revert LengthMismatch();
        if (recipient == address(0)) revert InvalidRecipient();
        
        uint256 totalFee = fee; // Fee is per transaction
        if (msg.value < totalFee) revert InsufficientFee(totalFee, msg.value);

        uint256 length = nftContracts.length;
        for (uint256 i = 0; i < length;) {
            address nftContract = nftContracts[i];
            if (nftContract == address(0)) revert InvalidNFTContract();

            // Verify contract supports ERC721 interface with try-catch to prevent DoS (M-03)
            try IERC165(nftContract).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
                if (!supported) revert NotERC721Contract();
            } catch {
                revert InterfaceCheckFailed();
            }

            // Using safeTransferFrom ensures the recipient can handle ERC721 tokens
            IERC721(nftContract).safeTransferFrom(msg.sender, recipient, tokenIds[i]);
            emit NftsSent(nftContract, recipient, tokenIds[i]);
            unchecked { ++i; }
        }

        // Refund excess
        uint256 excess = msg.value - totalFee;
        if (excess > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: excess}("");
            if (!refundSuccess) revert RefundFailed();
        }
    }

    /**
     * @dev Withdraws accumulated ether from the contract.
     * @param amount The amount of ether to withdraw in wei.
     */
    function withdrawEther(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientBalance();
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert WithdrawFailed();
        emit EtherWithdrawn(msg.sender, amount);
    }

    // --- Secured Multicall Logic ---

    modifier limitedCalls(uint256 length) {
        if (length > MAX_MULTICALL_SIZE) revert TooManyCalls(length, MAX_MULTICALL_SIZE);
        _;
    }

    /**
     * @notice Aggregate calls, ensuring each returns success.
     * @dev RESTRICTED TO OWNER to prevent arbitrary code execution on behalf of users.
     */
    function aggregate(Call[] calldata calls) public payable onlyOwner nonReentrant limitedCalls(calls.length) returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new bytes[](length);
        Call calldata call;
        for (uint256 i = 0; i < length;) {
            call = calls[i];
            (bool success, bytes memory data) = call.target.call(call.callData);
            if (!success) revert MulticallFailed();
            returnData[i] = data;
            unchecked { ++i; }
        }
        emit MulticallExecuted(length, msg.sender);
    }

    /**
     * @notice Aggregate calls with a msg value.
     * @dev RESTRICTED TO OWNER.
     */
    function aggregate3Value(Call3Value[] calldata calls) public payable onlyOwner nonReentrant limitedCalls(calls.length) returns (Result3[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result3[](length);
        Call3Value calldata calli;
        for (uint256 i = 0; i < length;) {
            calli = calls[i];
            uint256 val = calli.value;
            // Removed unchecked block for value accumulation to prevent overflow (H-01)
            valAccumulator += val;
            if (msg.value < valAccumulator) revert ValueMismatch();
            (bool success, bytes memory data) = calli.target.call{value: val}(calli.callData);
            if (!success && !calli.allowFailure) revert MulticallFailed();
            returnData[i] = Result3({success: success, returnData: data});
            unchecked { ++i; }
        }
        // Ensure exact value match to prevent excess value from being locked
        if (msg.value != valAccumulator) revert ValueMismatch();
        emit MulticallExecuted(length, msg.sender);
    }

    /**
     * @notice Aggregate calls.
     * @dev RESTRICTED TO OWNER.
     */
    function aggregate3(Call3[] calldata calls) public payable onlyOwner nonReentrant limitedCalls(calls.length) returns (Result3[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result3[](length);
        Call3 calldata calli;
        for (uint256 i = 0; i < length;) {
            calli = calls[i];
            (bool success, bytes memory data) = calli.target.call(calli.callData);
            if (!success && !calli.allowFailure) revert MulticallFailed();
            returnData[i] = Result3({success: success, returnData: data});
            unchecked { ++i; }
        }
        emit MulticallExecuted(length, msg.sender);
    }

    /**
     * @notice Returns the hash of the given block number.
     * @param blockNumber The block number to query.
     * @return blockHash The hash of the specified block.
     */
    function getBlockHash(uint256 blockNumber) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }

    /**
     * @notice Returns the current block number.
     * @return blockNumber The current block number.
     */
    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = block.number;
    }

    /**
     * @notice Returns the coinbase of the current block.
     * @return coinbase The address of the current block's miner.
     */
    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }

    /**
     * @notice Returns the prevrandao of the current block.
     * @return prevrandao The random value of the current block.
     */
    function getCurrentBlockPrevrandao() public view returns (uint256 prevrandao) {
        prevrandao = block.prevrandao;
    }

    /**
     * @notice Returns the gas limit of the current block.
     * @return gaslimit The gas limit of the current block.
     */
    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }

    /**
     * @notice Returns the timestamp of the current block.
     * @return timestamp The timestamp of the current block.
     */
    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }

    /**
     * @notice Returns the ether balance of the given address.
     * @param addr The address to query.
     * @return balance The ether balance of the address.
     */
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    /**
     * @notice Returns the hash of the previous block.
     * @return blockHash The hash of the previous block.
     */
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        blockHash = blockhash(block.number - 1);
    }

    receive() external payable {}
}
