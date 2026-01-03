// SPDX-License-Identifier: MIT
// Forced update to sync with WSL
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BatchNftSend} from "../contracts/BatchNftSend.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title MockERC721
 * @dev Simple ERC721 implementation for testing
 */
contract MockERC721 is ERC721 {
    uint256 private _tokenIdCounter;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _mint(to, tokenId);
        return tokenId;
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

/**
 * @title FaultyERC721
 * @dev ERC721 that reverts on supportsInterface call (for DoS testing)
 */
contract FaultyERC721 is ERC721 {
    constructor() ERC721("Faulty", "FAULTY") {}

    function supportsInterface(bytes4) public pure override returns (bool) {
        revert("Faulty contract");
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

/**
 * @title BatchNftSendTest
 * @dev Comprehensive test suite for BatchNftSend contract
 */
contract BatchNftSendTest is Test {
    BatchNftSend public batchNftSend;
    MockERC721 public nft1;
    MockERC721 public nft2;
    FaultyERC721 public faultyNft;

    address public owner = address(1);
    address public user = address(2);
    address public recipient = address(3);
    address public attacker = address(4);

    uint256 public constant DEFAULT_FEE = 0.1 ether;
    uint256 public constant MAX_FEE = 1 ether;
    uint256 public constant MAX_BATCH_SIZE = 50;

    event NftsSent(address indexed nftContract, address indexed recipient, uint256 tokenId);
    event FeeUpdated(uint256 newFee);
    event MulticallExecuted(uint256 callCount, address indexed caller);
    event EtherWithdrawn(address indexed recipient, uint256 amount);

    function setUp() public {
        // Fund test accounts
        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(recipient, 100 ether);

        // Deploy contracts
        vm.prank(owner);
        batchNftSend = new BatchNftSend(DEFAULT_FEE);

        nft1 = new MockERC721("NFT1", "NFT1");
        nft2 = new MockERC721("NFT2", "NFT2");
        faultyNft = new FaultyERC721();

        // Mint NFTs to user using auto-incrementing counter
        nft1.mint(user); // tokenId 0
        nft1.mint(user); // tokenId 1
        nft2.mint(user); // tokenId 0
        nft2.mint(user); // tokenId 1

        // Approve BatchNftSend contract
        vm.prank(user);
        nft1.setApprovalForAll(address(batchNftSend), true);
        vm.prank(user);
        nft2.setApprovalForAll(address(batchNftSend), true);
    }

    // ============ multiSendNfts Tests ============

    function test_MultiSendNfts_SingleNFT() public {
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit NftsSent(address(nft1), recipient, 0);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);

        assertEq(nft1.ownerOf(0), recipient);
    }

    function test_MultiSendNfts_MultipleNFTs() public {
        address[] memory nftContracts = new address[](2);
        nftContracts[0] = address(nft1);
        nftContracts[1] = address(nft2);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 0;

        vm.prank(user);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);

        assertEq(nft1.ownerOf(0), recipient);
        assertEq(nft2.ownerOf(0), recipient);
    }

    function test_MultiSendNfts_RefundsExcess() public {
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        uint256 excess = 0.5 ether;
        uint256 initialBalance = user.balance;

        vm.prank(user);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE + excess}(nftContracts, tokenIds, recipient, block.timestamp + 100);

        // User should have spent only the fee, excess should be refunded
        assertEq(user.balance, initialBalance - DEFAULT_FEE);
    }

    function test_MultiSendNfts_RevertsWhenEmptyBatch() public {
        address[] memory nftContracts = new address[](0);
        uint256[] memory tokenIds = new uint256[](0);

        vm.prank(user);
        vm.expectRevert(BatchNftSend.EmptyBatch.selector);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenBatchTooLarge() public {
        address[] memory nftContracts = new address[](MAX_BATCH_SIZE + 1);
        uint256[] memory tokenIds = new uint256[](MAX_BATCH_SIZE + 1);

        for (uint256 i = 0; i < MAX_BATCH_SIZE + 1; i++) {
            nftContracts[i] = address(nft1);
            tokenIds[i] = i;
        }

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(BatchNftSend.BatchTooLarge.selector, MAX_BATCH_SIZE + 1, MAX_BATCH_SIZE));
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenLengthMismatch() public {
        address[] memory nftContracts = new address[](2);
        nftContracts[0] = address(nft1);
        nftContracts[1] = address(nft2);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(user);
        vm.expectRevert(BatchNftSend.LengthMismatch.selector);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenRecipientIsZero() public {
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectRevert(BatchNftSend.InvalidRecipient.selector);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, address(0), block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenInsufficientFee() public {
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(BatchNftSend.InsufficientFee.selector, DEFAULT_FEE, DEFAULT_FEE - 1));
        batchNftSend.multiSendNfts{value: DEFAULT_FEE - 1}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenNFTContractIsZero() public {
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(0);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectRevert(BatchNftSend.InvalidNFTContract.selector);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenNotERC721() public {
        // Use a regular address that doesn't implement ERC721
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(this);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectRevert(BatchNftSend.InterfaceCheckFailed.selector);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenFaultyContract() public {
        faultyNft.mint(user, 0);
        vm.prank(user);
        faultyNft.setApprovalForAll(address(batchNftSend), true);

        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(faultyNft);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectRevert(BatchNftSend.InterfaceCheckFailed.selector);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenPaused() public {
        vm.prank(owner);
        batchNftSend.pause();

        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectRevert(); // EnforcedPause() from Pausable
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
    }

    function test_MultiSendNfts_RevertsWhenExpired() public {
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        vm.expectRevert(BatchNftSend.TransactionExpired.selector);
        // Set deadline to past
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp - 1);
    }

    function test_MultiSendNfts_WorksAfterUnpause() public {
        vm.prank(owner);
        batchNftSend.pause();
        vm.prank(owner);
        batchNftSend.unpause();

        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(user);
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
        assertEq(nft1.ownerOf(0), recipient);
    }

    // ============ Fee Management Tests ============

    function test_SetFee_ByOwner() public {
        uint256 newFee = 0.2 ether;
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit FeeUpdated(newFee);
        batchNftSend.setFee(newFee);

        assertEq(batchNftSend.fee(), newFee);
    }

    function test_SetFee_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        batchNftSend.setFee(0.2 ether);
    }

    function test_SetFee_RevertsWhenExceedsMax() public {
        vm.prank(owner);
        vm.expectRevert(BatchNftSend.FeeExceedsMaximum.selector);
        batchNftSend.setFee(MAX_FEE + 1);
    }

    function test_SetFee_AllowsMaxFee() public {
        vm.prank(owner);
        batchNftSend.setFee(MAX_FEE);
        assertEq(batchNftSend.fee(), MAX_FEE);
    }

    // ============ Ownership Tests ============

    function test_TransferOwnership_TwoStep() public {
        address newOwner = address(5);
        vm.prank(owner);
        batchNftSend.transferOwnership(newOwner);

        assertEq(batchNftSend.pendingOwner(), newOwner);
        assertEq(batchNftSend.owner(), owner); // Still old owner until accepted

        vm.prank(newOwner);
        batchNftSend.acceptOwnership();

        assertEq(batchNftSend.owner(), newOwner);
    }

    function test_TransferOwnership_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        batchNftSend.transferOwnership(address(5));
    }

    // ============ Pause Tests ============

    function test_Pause_ByOwner() public {
        vm.prank(owner);
        batchNftSend.pause();
        assertTrue(batchNftSend.paused());
    }

    function test_Unpause_ByOwner() public {
        vm.prank(owner);
        batchNftSend.pause();
        vm.prank(owner);
        batchNftSend.unpause();
        assertFalse(batchNftSend.paused());
    }

    function test_Pause_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        batchNftSend.pause();
    }

    // ============ Withdraw Tests ============

    function test_WithdrawEther_ByOwner() public {
        // Send some ETH to contract
        vm.deal(address(batchNftSend), 1 ether);

        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        
        vm.expectEmit(true, false, false, true);
        emit EtherWithdrawn(owner, 0.5 ether);
        batchNftSend.withdrawEther(0.5 ether);

        assertEq(owner.balance, ownerBalanceBefore + 0.5 ether);
    }

    function test_WithdrawEther_RevertsWhenInsufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert(BatchNftSend.InsufficientBalance.selector);
        batchNftSend.withdrawEther(1 ether);
    }

    function test_WithdrawEther_RevertsWhenZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(BatchNftSend.ZeroAmount.selector);
        batchNftSend.withdrawEther(0);
    }

    function test_WithdrawEther_RevertsWhenNotOwner() public {
        vm.deal(address(batchNftSend), 1 ether);
        vm.prank(user);
        vm.expectRevert();
        batchNftSend.withdrawEther(0.5 ether);
    }

    // ============ Multicall Tests ============

    function test_Aggregate_ByOwner() public {
        BatchNftSend.Call[] memory calls = new BatchNftSend.Call[](1);
        calls[0] = BatchNftSend.Call({
            target: address(nft1),
            callData: abi.encodeWithSelector(nft1.name.selector)
        });

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit MulticallExecuted(1, owner);
        (uint256 blockNumber, bytes[] memory returnData) = batchNftSend.aggregate(calls);

        assertEq(blockNumber, block.number);
        assertEq(returnData.length, 1);
    }

    function test_Aggregate_RevertsWhenNotOwner() public {
        BatchNftSend.Call[] memory calls = new BatchNftSend.Call[](0);
        vm.prank(user);
        vm.expectRevert();
        batchNftSend.aggregate(calls);
    }

    function test_Aggregate_RevertsWhenTooManyCalls() public {
        uint256 MAX_MULTICALL_SIZE = 100;
        BatchNftSend.Call[] memory calls = new BatchNftSend.Call[](MAX_MULTICALL_SIZE + 1);
        for(uint256 i=0; i<MAX_MULTICALL_SIZE+1; i++) {
             calls[i] = BatchNftSend.Call({
                target: address(nft1),
                callData: abi.encodeWithSelector(nft1.name.selector)
            });
        }
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BatchNftSend.TooManyCalls.selector, MAX_MULTICALL_SIZE + 1, MAX_MULTICALL_SIZE));
        batchNftSend.aggregate(calls);
    }

    function test_Aggregate3_ByOwner() public {
        BatchNftSend.Call3[] memory calls = new BatchNftSend.Call3[](1);
        calls[0] = BatchNftSend.Call3({
            target: address(nft1),
            allowFailure: false,
            callData: abi.encodeWithSelector(nft1.name.selector)
        });

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit MulticallExecuted(1, owner);
        BatchNftSend.Result3[] memory returnData = batchNftSend.aggregate3(calls);

        assertEq(returnData.length, 1);
        assertTrue(returnData[0].success);
    }

    function test_Aggregate3_WithAllowFailure() public {
        BatchNftSend.Call3[] memory calls = new BatchNftSend.Call3[](2);
        calls[0] = BatchNftSend.Call3({
            target: address(nft1),
            allowFailure: true,
            callData: abi.encodeWithSelector(nft1.name.selector)
        });
        calls[1] = BatchNftSend.Call3({
            target: address(nft1),
            allowFailure: true,
            callData: abi.encodeWithSelector(bytes4(0x12345678)) // Invalid selector, will fail
        });

        vm.prank(owner);
        BatchNftSend.Result3[] memory returnData = batchNftSend.aggregate3(calls);

        assertEq(returnData.length, 2);
        assertTrue(returnData[0].success);
        assertFalse(returnData[1].success); // Second call fails but allowFailure is true
    }

    function test_Aggregate3_RevertsWhenTooManyCalls() public {
        uint256 MAX_MULTICALL_SIZE = 100;
        BatchNftSend.Call3[] memory calls = new BatchNftSend.Call3[](MAX_MULTICALL_SIZE + 1);
        for(uint256 i=0; i<MAX_MULTICALL_SIZE+1; i++) {
            calls[i] = BatchNftSend.Call3({
                target: address(nft1),
                allowFailure: false,
                callData: abi.encodeWithSelector(nft1.name.selector)
            });
        }
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BatchNftSend.TooManyCalls.selector, MAX_MULTICALL_SIZE + 1, MAX_MULTICALL_SIZE));
        batchNftSend.aggregate3(calls);
    }

    function test_Aggregate3Value_ExactValueMatch() public {
        uint256 callValue = 0.1 ether;
        BatchNftSend.Call3Value[] memory calls = new BatchNftSend.Call3Value[](1);
        // Use empty callData to just send ETH (receive() function)
        calls[0] = BatchNftSend.Call3Value({
            target: recipient,
            allowFailure: false,
            value: callValue,
            callData: ""
        });

        uint256 recipientBalanceBefore = recipient.balance;
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit MulticallExecuted(1, owner);
        BatchNftSend.Result3[] memory returnData = batchNftSend.aggregate3Value{value: callValue}(calls);

        assertEq(returnData.length, 1);
        assertTrue(returnData[0].success);
        assertEq(recipient.balance, recipientBalanceBefore + callValue);
    }

    function test_Aggregate3Value_RevertsWhenValueMismatch() public {
        uint256 callValue = 0.1 ether;
        BatchNftSend.Call3Value[] memory calls = new BatchNftSend.Call3Value[](1);
        // Use empty callData to just send ETH (receive() function)
        calls[0] = BatchNftSend.Call3Value({
            target: recipient,
            allowFailure: false,
            value: callValue,
            callData: ""
        });

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        // Send less than required value - will revert during loop at line 199
        vm.expectRevert(BatchNftSend.ValueMismatch.selector);
        batchNftSend.aggregate3Value{value: callValue - 1}(calls);
    }

    function test_Aggregate3Value_RevertsWhenExcessValue() public {
        uint256 callValue = 0.1 ether;
        BatchNftSend.Call3Value[] memory calls = new BatchNftSend.Call3Value[](1);
        // Use empty callData to just send ETH (receive() function)
        calls[0] = BatchNftSend.Call3Value({
            target: recipient,
            allowFailure: false,
            value: callValue,
            callData: ""
        });

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        // Send more than required value (should revert due to exact match requirement)
        // The exact value check happens at the end, so this should revert with ValueMismatch
        vm.expectRevert(BatchNftSend.ValueMismatch.selector);
        batchNftSend.aggregate3Value{value: callValue + 1}(calls);
    }

    function test_Aggregate3Value_MultipleCalls() public {
        uint256 call1Value = 0.1 ether;
        uint256 call2Value = 0.2 ether;
        uint256 totalValue = call1Value + call2Value;

        uint256 recipientBalanceBefore = recipient.balance;
        BatchNftSend.Call3Value[] memory calls = new BatchNftSend.Call3Value[](2);
        // Use empty callData to just send ETH (receive() function)
        calls[0] = BatchNftSend.Call3Value({
            target: recipient,
            allowFailure: false,
            value: call1Value,
            callData: ""
        });
        calls[1] = BatchNftSend.Call3Value({
            target: recipient,
            allowFailure: false,
            value: call2Value,
            callData: ""
        });

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit MulticallExecuted(2, owner);
        BatchNftSend.Result3[] memory returnData = batchNftSend.aggregate3Value{value: totalValue}(calls);

        assertEq(returnData.length, 2);
        assertTrue(returnData[0].success);
        assertTrue(returnData[1].success);
        assertEq(recipient.balance, recipientBalanceBefore + totalValue);
    }

    function test_Aggregate3Value_RevertsWhenTooManyCalls() public {
        uint256 MAX_MULTICALL_SIZE = 100;
        BatchNftSend.Call3Value[] memory calls = new BatchNftSend.Call3Value[](MAX_MULTICALL_SIZE + 1);
        for(uint256 i=0; i<MAX_MULTICALL_SIZE+1; i++) {
            calls[i] = BatchNftSend.Call3Value({
                target: address(nft1),
                allowFailure: false,
                value: 0.01 ether,
                callData: abi.encodeWithSelector(nft1.name.selector)
            });
        }
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BatchNftSend.TooManyCalls.selector, MAX_MULTICALL_SIZE + 1, MAX_MULTICALL_SIZE));
        batchNftSend.aggregate3Value{value: (MAX_MULTICALL_SIZE + 1) * 0.01 ether}(calls);
    }

    // ============ Helper Function Tests ============

    function test_GetBlockNumber() public view {
        uint256 blockNumber = batchNftSend.getBlockNumber();
        assertEq(blockNumber, block.number);
    }

    function test_GetEthBalance() public {
        vm.deal(recipient, 5 ether);
        uint256 balance = batchNftSend.getEthBalance(recipient);
        assertEq(balance, 5 ether);
    }

    // ============ Fuzz Tests ============

    function testFuzz_MultiSendNfts_ValidInputs(
        uint8 batchSize,
        uint256 feeAmount
    ) public {
        // Bound inputs to valid ranges
        batchSize = uint8(bound(batchSize, 1, MAX_BATCH_SIZE));
        feeAmount = bound(feeAmount, DEFAULT_FEE, MAX_FEE);

        // Set fee
        vm.prank(owner);
        batchNftSend.setFee(feeAmount);

        // Create arrays
        address[] memory nftContracts = new address[](batchSize);
        uint256[] memory tokenIds = new uint256[](batchSize);

        // Mint and approve NFTs
        for (uint256 i = 0; i < batchSize; i++) {
            uint256 tokenId = nft1.mint(user);
            nftContracts[i] = address(nft1);
            tokenIds[i] = tokenId;
        }

        vm.prank(user);
        nft1.setApprovalForAll(address(batchNftSend), true);

        // Execute transfer
        vm.prank(user);
        batchNftSend.multiSendNfts{value: feeAmount}(nftContracts, tokenIds, recipient, block.timestamp + 100);

        // Verify all NFTs transferred
        for (uint256 i = 0; i < batchSize; i++) {
            assertEq(nft1.ownerOf(tokenIds[i]), recipient);
        }
    }

    // ============ Gas Benchmark Tests ============

    function test_Gas_MultiSendNfts_SingleNFT() public {
        address[] memory nftContracts = new address[](1);
        nftContracts[0] = address(nft1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(user);
        uint256 gasBefore = gasleft();
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for single NFT transfer:", gasUsed);
    }

    function test_Gas_MultiSendNfts_MaxBatch() public {
        // Create max batch
        address[] memory nftContracts = new address[](MAX_BATCH_SIZE);
        uint256[] memory tokenIds = new uint256[](MAX_BATCH_SIZE);

        for (uint256 i = 0; i < MAX_BATCH_SIZE; i++) {
            uint256 tokenId = nft1.mint(user);
            nftContracts[i] = address(nft1);
            tokenIds[i] = tokenId;
        }

        vm.prank(user);
        nft1.setApprovalForAll(address(batchNftSend), true);

        vm.prank(user);
        uint256 gasBefore = gasleft();
        batchNftSend.multiSendNfts{value: DEFAULT_FEE}(nftContracts, tokenIds, recipient, block.timestamp + 100);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for max batch (50 NFTs):", gasUsed);
    }
}
