// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsFreeMinter.sol";


contract FreeMintTest is Test {

    uint256 constant START_TOKEN_ID = 1501;

    HippyGhosts hippyGhosts;
    HippyGhostsFreeMinter minter;

    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));

    function setUp() public {
        hippyGhosts = new HippyGhosts();
        minter = new HippyGhostsFreeMinter(address(hippyGhosts), START_TOKEN_ID);
        hippyGhosts.setAddresses(address(0), address(minter));
    }

    function testConstructorRejectsZeroStartTokenId() public {
        vm.expectRevert("Invalid start token id");
        new HippyGhostsFreeMinter(address(hippyGhosts), 0);
    }

    function testConstructorRejectsStartTokenIdPastMax() public {
        uint256 tooHigh = minter.MAX_TOKEN_ID() + 1;
        vm.expectRevert("Invalid start token id");
        new HippyGhostsFreeMinter(address(hippyGhosts), tooHigh);
    }

    function testConstructorAcceptsMaxTokenIdAsStart() public {
        HippyGhostsFreeMinter edgeMinter = new HippyGhostsFreeMinter(
            address(hippyGhosts), minter.MAX_TOKEN_ID()
        );
        assertEq(edgeMinter.nextTokenId(), minter.MAX_TOKEN_ID());
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

    function testMintRevertsWhileClosed() public {
        vm.prank(EOA1);
        vm.expectRevert("Mint is not open");
        minter.mint(1);
    }

    function testMintOne() public {
        minter.setMintOpen(true);
        vm.prank(EOA1);
        minter.mint(1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID), EOA1);
        assertEq(minter.nextTokenId(), START_TOKEN_ID + 1);
        assertEq(minter.mintedCount(EOA1), 1);
    }

    function testMintMultipleInOneCall() public {
        minter.setMintOpen(true);
        vm.prank(EOA1);
        minter.mint(3);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID), EOA1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID + 1), EOA1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID + 2), EOA1);
        assertEq(minter.nextTokenId(), START_TOKEN_ID + 3);
    }

    function testSequentialMintsFromDifferentWallets() public {
        minter.setMintOpen(true);
        vm.prank(EOA1);
        minter.mint(2);
        vm.prank(EOA2);
        minter.mint(1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID), EOA1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID + 1), EOA1);
        assertEq(hippyGhosts.ownerOf(START_TOKEN_ID + 2), EOA2);
    }

    function testPerWalletLimitEnforcedAcrossCalls() public {
        minter.setMintOpen(true);
        vm.startPrank(EOA1);
        minter.mint(2);
        minter.mint(1);
        vm.expectRevert("Exceeds per-wallet limit");
        minter.mint(1);
        vm.stopPrank();
        assertEq(minter.mintedCount(EOA1), 3);
    }

    function testPerWalletLimitRejectsOversizedSingleCall() public {
        minter.setMintOpen(true);
        vm.prank(EOA1);
        vm.expectRevert("Exceeds per-wallet limit");
        minter.mint(4);
    }

    function testOwnerCanRaisePerWalletLimit() public {
        minter.setMintOpen(true);
        minter.setMaxPerWallet(5);
        vm.prank(EOA1);
        minter.mint(5);
        assertEq(minter.mintedCount(EOA1), 5);
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

    function testRevertsWhenExceedingMaxTokenId() public {
        // Start right at the edge of the collection so a 2-token mint would overflow.
        HippyGhostsFreeMinter edgeMinter = new HippyGhostsFreeMinter(
            address(hippyGhosts), minter.MAX_TOKEN_ID()
        );
        hippyGhosts.setAddresses(address(0), address(edgeMinter));
        edgeMinter.setMintOpen(true);
        edgeMinter.setMaxPerWallet(2);

        vm.prank(EOA1);
        vm.expectRevert("Not enough ghosts remaining");
        edgeMinter.mint(2);

        // The last token id mints fine on its own.
        vm.prank(EOA1);
        edgeMinter.mint(1);
        assertEq(hippyGhosts.ownerOf(minter.MAX_TOKEN_ID()), EOA1);
        assertEq(edgeMinter.remainingSupply(), 0);
    }

    /**
     * Mirrors the exact handoff a future swap back to a priced model would
     * rely on: a second controller picks up exactly where the first left off,
     * with no collision and no gap.
     */
    function testHandoffToNextMinterContinuesSequence() public {
        minter.setMintOpen(true);
        vm.prank(EOA1);
        minter.mint(3);

        uint256 handoffTokenId = minter.nextTokenId();
        HippyGhostsFreeMinter nextMinter = new HippyGhostsFreeMinter(
            address(hippyGhosts), handoffTokenId
        );
        hippyGhosts.setAddresses(address(0), address(nextMinter));
        nextMinter.setMintOpen(true);

        vm.prank(EOA2);
        nextMinter.mint(1);
        assertEq(hippyGhosts.ownerOf(handoffTokenId), EOA2);

        // The old minter is no longer the active controller and can no longer
        // mint — even for a wallet that hasn't touched its own per-wallet limit.
        vm.prank(EOA2);
        vm.expectRevert("caller is not mint controller");
        minter.mint(1);
    }
}
