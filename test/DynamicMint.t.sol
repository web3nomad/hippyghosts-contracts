// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsDynamicMinter.sol";


contract DynamicMintTest is Test {

    uint256 constant START_TOKEN_ID = 1501;

    // Deliberately small, round numbers so expected prices are easy to compute
    // by hand in each test. Real deploy parameters live in the deploy script.
    uint256 constant FLOOR_PRICE = 0;
    uint256 constant MAX_PRICE = 0.08 ether;
    uint256 constant PRICE_BUMP = 0.0001 ether;
    uint256 constant DECAY_PER_BLOCK = 0.00005 ether;

    HippyGhosts hippyGhosts;
    HippyGhostsDynamicMinter minter;

    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));

    function setUp() public {
        hippyGhosts = new HippyGhosts();
        minter = newMinter(START_TOKEN_ID);
        hippyGhosts.setAddresses(address(0), address(minter));
        vm.deal(EOA1, 10 ether);
        vm.deal(EOA2, 10 ether);
    }

    function newMinter(uint256 startTokenId) internal returns (HippyGhostsDynamicMinter) {
        return new HippyGhostsDynamicMinter(
            address(hippyGhosts), startTokenId,
            FLOOR_PRICE, MAX_PRICE, PRICE_BUMP, DECAY_PER_BLOCK
        );
    }

    /****************************************
     * Constructor validation
     ****************************************/

    function testConstructorRejectsZeroStartTokenId() public {
        vm.expectRevert("Invalid start token id");
        newMinterWithStart(0);
    }

    function testConstructorRejectsStartTokenIdPastMax() public {
        uint256 tooHigh = minter.MAX_TOKEN_ID() + 1;
        vm.expectRevert("Invalid start token id");
        newMinterWithStart(tooHigh);
    }

    function testConstructorAcceptsMaxTokenIdAsStart() public {
        HippyGhostsDynamicMinter edgeMinter = newMinter(minter.MAX_TOKEN_ID());
        assertEq(edgeMinter.nextTokenId(), minter.MAX_TOKEN_ID());
    }

    function testConstructorRejectsMaxPriceBelowFloor() public {
        vm.expectRevert("Invalid price bounds");
        new HippyGhostsDynamicMinter(
            address(hippyGhosts), START_TOKEN_ID,
            1 ether, 0.5 ether, PRICE_BUMP, DECAY_PER_BLOCK
        );
    }

    // Helper kept separate so vm.expectRevert binds to the constructor call
    // and not to an argument-expression external call.
    function newMinterWithStart(uint256 startTokenId) internal {
        newMinter(startTokenId);
    }

    /****************************************
     * Gate and access control
     ****************************************/

    function testMintRevertsWhileClosed() public {
        vm.prank(EOA1);
        vm.expectRevert("Mint is not open");
        minter.mint(1);
    }

    function testNonOwnerCannotSetMintOpen() public {
        vm.prank(EOA1);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.setMintOpen(true);
    }

    function testNonOwnerCannotSetMaxPerWallet() public {
        vm.prank(EOA1);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.setMaxPerWallet(10);
    }

    /**
     * Mirrors the real mainnet deploy flow: the deployer is not the admin.
     * transferOwnership hands control to a separate address (the Gnosis Safe
     * on mainnet) rather than leaving it on the deploying key.
     */
    function testOwnershipCanBeTransferredToAnAdminAddress() public {
        address safeStandIn = address(uint160(uint256(keccak256('gnosis safe'))));
        minter.transferOwnership(safeStandIn);
        assertEq(minter.owner(), safeStandIn);

        vm.expectRevert("Ownable: caller is not the owner");
        minter.setMintOpen(true);

        vm.prank(safeStandIn);
        minter.setMintOpen(true);
        assertTrue(minter.mintOpen());
    }

    /****************************************
     * Free mint at the floor
     ****************************************/

    function testMintOneIsFreeAtFloor() public {
        minter.setMintOpen(true);
        assertEq(minter.currentPrice(), 0);
        vm.prank(EOA1);
        minter.mint(1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID), EOA1);
        assertEq(minter.nextTokenId(), START_TOKEN_ID + 1);
        assertEq(minter.mintedCount(EOA1), 1);
    }

    function testBatchMintChargesRampWithinBatch() public {
        minter.setMintOpen(true);
        // First token is free, second costs one bump, third costs two.
        uint256 expected = 0 + PRICE_BUMP + 2 * PRICE_BUMP;
        assertEq(minter.priceForNext(3), expected);
        vm.prank(EOA1);
        minter.mint{value: expected}(3);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID), EOA1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID + 1), EOA1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID + 2), EOA1);
        assertEq(minter.nextTokenId(), START_TOKEN_ID + 3);
    }

    /****************************************
     * Price dynamics: bump and decay
     ****************************************/

    function testEachMintPushesPriceUp() public {
        minter.setMintOpen(true);
        uint256 quote3 = minter.priceForNext(3);
        vm.prank(EOA1);
        minter.mint{value: quote3}(3);
        assertEq(minter.currentPrice(), 3 * PRICE_BUMP);

        // The next wallet in the same block pays the raised price.
        uint256 quote = minter.priceForNext(1);
        assertEq(quote, 3 * PRICE_BUMP);
        vm.prank(EOA2);
        minter.mint{value: quote}(1);
        assertEq(minter.currentPrice(), 4 * PRICE_BUMP);
    }

    function testPriceDecaysBackToFloorOverBlocks() public {
        minter.setMintOpen(true);
        uint256 quote3 = minter.priceForNext(3);
        vm.prank(EOA1);
        minter.mint{value: quote3}(3);
        uint256 raised = 3 * PRICE_BUMP; // 0.0003 ether

        // Partial decay after a few blocks.
        vm.roll(block.number + 2);
        assertEq(minter.currentPrice(), raised - 2 * DECAY_PER_BLOCK);

        // Exactly at the floor.
        vm.roll(block.number + 4); // 6 blocks total * 0.00005 = 0.0003
        assertEq(minter.currentPrice(), FLOOR_PRICE);

        // Long after: still the floor, never below, no underflow/overflow.
        vm.roll(block.number + 10_000_000);
        assertEq(minter.currentPrice(), FLOOR_PRICE);

        // And minting is free again.
        vm.prank(EOA2);
        minter.mint(1);
        assertEq(minter.mintedCount(EOA2), 1);
    }

    function testPriceIsCappedAtMaxPrice() public {
        minter.setMintOpen(true);
        // 0.08 / 0.0001 = 800 tokens to reach the cap; drive it there with
        // fresh wallets, 3 per wallet, in a single block (no decay in between).
        uint256 walletCount = 270; // 810 tokens > 800
        for (uint256 w = 0; w < walletCount; w++) {
            address wallet = address(uint160(uint256(keccak256(abi.encode('cap wallet', w)))));
            uint256 quote3 = minter.priceForNext(3);
            hoax(wallet, 1 ether);
            minter.mint{value: quote3}(3);
            assertLe(minter.currentPrice(), MAX_PRICE);
        }
        assertEq(minter.currentPrice(), MAX_PRICE);

        // A quote at the cap charges maxPrice per token, no more.
        assertEq(minter.priceForNext(2), 2 * MAX_PRICE);
    }

    /****************************************
     * Payment handling
     ****************************************/

    function testInsufficientPaymentReverts() public {
        minter.setMintOpen(true);
        uint256 quote3 = minter.priceForNext(3);
        vm.prank(EOA1);
        minter.mint{value: quote3}(3); // price now 3 bumps

        uint256 quote = minter.priceForNext(1);
        vm.prank(EOA2);
        vm.expectRevert("Insufficient payment");
        minter.mint{value: quote - 1}(1);
    }

    function testExcessPaymentIsRefunded() public {
        minter.setMintOpen(true);
        uint256 quote3 = minter.priceForNext(3);
        vm.prank(EOA1);
        minter.mint{value: quote3}(3); // price now 3 bumps

        uint256 quote = minter.priceForNext(1);
        uint256 balanceBefore = EOA2.balance;
        vm.prank(EOA2);
        minter.mint{value: quote + 0.5 ether}(1);
        // Only the quoted price was kept; the padding came back.
        assertEq(EOA2.balance, balanceBefore - quote);
        // Contract holds exactly what both wallets were quoted, nothing more.
        assertEq(address(minter).balance, (PRICE_BUMP + 2 * PRICE_BUMP) + quote);
    }

    function testWithdrawSendsBalanceToOwner() public {
        minter.setMintOpen(true);
        uint256 quote3 = minter.priceForNext(3);
        vm.prank(EOA1);
        minter.mint{value: quote3}(3);
        uint256 quote1 = minter.priceForNext(1);
        vm.prank(EOA2);
        minter.mint{value: quote1}(1);

        uint256 collected = address(minter).balance;
        assertGt(collected, 0);

        address payable treasury = payable(address(uint160(uint256(keccak256('treasury')))));
        minter.transferOwnership(treasury);
        vm.prank(treasury);
        minter.withdraw();
        assertEq(address(minter).balance, 0);
        assertEq(treasury.balance, collected);
    }

    function testNonOwnerCannotWithdraw() public {
        vm.prank(EOA1);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.withdraw();
    }

    /****************************************
     * Per-wallet limit
     ****************************************/

    function testPerWalletLimitEnforcedAcrossCalls() public {
        minter.setMintOpen(true);
        vm.startPrank(EOA1);
        minter.mint{value: minter.priceForNext(2)}(2);
        minter.mint{value: minter.priceForNext(1)}(1);
        uint256 quote = minter.priceForNext(1);
        vm.expectRevert("Exceeds per-wallet limit");
        minter.mint{value: quote}(1);
        vm.stopPrank();
        assertEq(minter.mintedCount(EOA1), 3);
    }

    function testPerWalletLimitRejectsOversizedSingleCall() public {
        minter.setMintOpen(true);
        uint256 quote = minter.priceForNext(4);
        vm.prank(EOA1);
        vm.expectRevert("Exceeds per-wallet limit");
        minter.mint{value: quote}(4);
    }

    function testOwnerCanRaisePerWalletLimit() public {
        minter.setMintOpen(true);
        minter.setMaxPerWallet(5);
        uint256 quote5 = minter.priceForNext(5);
        vm.prank(EOA1);
        minter.mint{value: quote5}(5);
        assertEq(minter.mintedCount(EOA1), 5);
    }

    /****************************************
     * Supply edge
     ****************************************/

    function testRevertsWhenExceedingMaxTokenId() public {
        // Start right at the edge of the collection so a 2-token mint would overflow.
        HippyGhostsDynamicMinter edgeMinter = newMinter(minter.MAX_TOKEN_ID());
        hippyGhosts.setAddresses(address(0), address(edgeMinter));
        edgeMinter.setMintOpen(true);

        uint256 quote = edgeMinter.priceForNext(2);
        vm.prank(EOA1);
        vm.expectRevert("Not enough ghosts remaining");
        edgeMinter.mint{value: quote}(2);

        // The last token id mints fine on its own.
        uint256 lastQuote = edgeMinter.priceForNext(1);
        vm.prank(EOA1);
        edgeMinter.mint{value: lastQuote}(1);
        assertEq(hippyGhosts.ownerOf(minter.MAX_TOKEN_ID()), EOA1);
        assertEq(edgeMinter.remainingSupply(), 0);
    }

    /****************************************
     * Handoff to a future mint controller
     ****************************************/

    /**
     * Mirrors the exact handoff a future pricing change would rely on: a
     * second controller picks up exactly where the first left off, with no
     * collision and no gap.
     */
    function testHandoffToNextMinterContinuesSequence() public {
        minter.setMintOpen(true);
        uint256 quote3 = minter.priceForNext(3);
        vm.prank(EOA1);
        minter.mint{value: quote3}(3);

        uint256 handoffTokenId = minter.nextTokenId();
        HippyGhostsDynamicMinter nextMinter = newMinter(handoffTokenId);
        hippyGhosts.setAddresses(address(0), address(nextMinter));
        nextMinter.setMintOpen(true);

        vm.prank(EOA2);
        nextMinter.mint(1); // fresh minter starts back at the floor: free
        assertEq(hippyGhosts.ownerOf(handoffTokenId), EOA2);

        // The old minter is no longer the active controller and can no longer
        // mint — even for a wallet that hasn't touched its own per-wallet limit.
        uint256 quote = minter.priceForNext(1);
        vm.prank(EOA2);
        vm.expectRevert("caller is not mint controller");
        minter.mint{value: quote}(1);
    }
}
