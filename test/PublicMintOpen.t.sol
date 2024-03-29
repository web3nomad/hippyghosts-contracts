// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";
import "../src/HippyGhostsMinter.sol";


contract PublicMintOpenTest is Test {
    using stdStorage for StdStorage;

    HippyGhostsRenderer renderer;
    HippyGhostsMinter mintController;
    HippyGhosts hippyGhosts;
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));
    uint256 constant BASE_BLOCK = 10000000;

    function setUp() public {
        hippyGhosts = new HippyGhosts();
        renderer = new HippyGhostsRenderer(address(hippyGhosts), "");
        mintController = new HippyGhostsMinter(address(hippyGhosts), address(0));
        hippyGhosts.setAddresses(address(renderer), address(mintController));
        vm.roll(BASE_BLOCK - 10000);
        mintController.setPublicMintStartBlock(BASE_BLOCK + 1);
        vm.deal(EOA1, 10000 ether);
        vm.deal(EOA2, 10000 ether);
    }

    function testMintFirstWeek() public {
        vm.roll(BASE_BLOCK + 10);
        vm.prank(EOA1, EOA1);
        /**/
        mintController.mint{value: 0.24 ether * 10}(10);
        assertEq(hippyGhosts.balanceOf(EOA1), 10);
        assertEq(address(mintController).balance, 0.24 ether * 10);
    }

    /**
     * first week (block[1,40000]) release 300 tokens, all minted
     * second week (block[40001,80000]) release 300 tokens, all minted
     */
    function testMintSecondWeek() public {
        /**
         * first week, mint 300 ghosts
         */
        vm.roll(BASE_BLOCK + 1);
        for (uint256 i=0; i<30; i++) {
            vm.prank(EOA1, EOA1);
            mintController.mint{value: 0.24 ether * 10}(10);
        }
        // uint256 slot = stdstore.target(address(mintController)).sig(mintController.publicMintIndex.selector).find();
        // assertEq(uint(vm.load(address(mintController), bytes32(slot))), 1500 + 300);
        assertEq(mintController.publicMintIndex(), 1500 + 300);
        assertEq(hippyGhosts.balanceOf(EOA1), 300);
        assertEq(address(mintController).balance, 0.24 ether * 300);
        /**
         * cannot mint any more
         */
        vm.roll(BASE_BLOCK + 40000);
        vm.prank(EOA2, EOA2);
        vm.expectRevert("Target epoch is not open");
        mintController.mint{value: 0.24 ether}(1);
        /**
         * second week, new ghosts available, mint 150 ghosts
         */
        vm.roll(BASE_BLOCK + 40001);
        for (uint256 i=0; i<15; i++) {
            vm.prank(EOA2, EOA2);
            mintController.mint{value: 0.24 ether * 10}(10);
        }
        assertEq(mintController.publicMintIndex(), 1500 + 300 + 150);
        assertEq(hippyGhosts.balanceOf(EOA2), 150);
        assertEq(address(mintController).balance, 0.24 ether * (300 + 150));
    }

    /**
     * release 300 in first week but only 150 minted
     * release 300 more in second week and 200 more are minted
     */
    function testMintFirstWeekDecay() public {
        /**
         * first week, mint 150 ghosts
         */
        vm.roll(BASE_BLOCK + 1);
        for (uint256 i=0; i<15; i++) {
            vm.prank(EOA1, EOA1);
            mintController.mint{value: 0.24 ether * 10}(10);
        }
        /**
         * second week, mint 150 ghosts of first week, and 50 tokens of this week
         */
        vm.roll(BASE_BLOCK + 40001);
        for (uint256 i=0; i<20; i++) {
            vm.prank(EOA2, EOA2);
            mintController.mint{value: 0.24 ether * 10}(10);
        }
        assertEq(mintController.publicMintIndex(), 1500 + 150 + 200);
        assertEq(hippyGhosts.balanceOf(EOA1), 150);
        assertEq(hippyGhosts.balanceOf(EOA2), 200);
        assertEq(address(mintController).balance,
            0.24 ether * 150 + 0.20 ether * 150 + 0.24 ether * 50);
    }

    /**
     * release 300 in first week but only 150 minted
     * release 300 more in second week and 200 more are minted
     */
    function testMintFirstWeekDecay2() public {
        vm.startPrank(EOA1, EOA1);
        /**
         * first week, mint 290 + 9 = 299 ghosts
         */
        vm.roll(BASE_BLOCK + 1);
        for (uint256 i=0; i<29; i++) {
            mintController.mint{value: 0.24 ether * 10}(10);
        }
        mintController.mint{value: 0.24 ether * 9}(9);
        /**
         * 4 weeks later, mint 2 ghosts
         * last 1 ghosts in first week: price decayed to 0.08
         * next 1 ghosts in second week: price decayed to 0.12
         */
        vm.roll(BASE_BLOCK + 1 + 40000 * 4);
        for (uint256 i=0; i<2; i++) {
            mintController.mint{value: 0.24 ether}(1);
        }
        assertEq(mintController.publicMintIndex(), 1500 + 299 + 2);
        assertEq(address(mintController).balance,
            0.24 ether * 299 + 0.08 ether + 0.12 ether);
    }

    function testMintLastWeek() public {
        vm.startPrank(EOA1, EOA1);
        /**
         * 29 weeks later, all ghosts minted
         */
        for (uint256 i=1; i<=28; i++) {
            vm.roll(BASE_BLOCK + 1 + 40000 * i);
            for (uint256 j=0; j<30; j++) {
                mintController.mint{value: 0.24 ether * 10}(10);
            }
        }
        assertEq(hippyGhosts.balanceOf(EOA1), 8400);
        for (uint256 j=0; j<9; j++) {
            mintController.mint{value: 0.24 ether * 10}(10);
        }
        assertEq(hippyGhosts.balanceOf(EOA1), 8490);
        vm.expectRevert("Not enough ghosts remaining to mint");
        mintController.mint{value: 0.24 ether * 10}(10);
        mintController.mint{value: 0.24 ether * 10}(9);
        assertEq(hippyGhosts.balanceOf(EOA1), 8499);
        vm.expectRevert("Not enough ghosts remaining to mint");
        mintController.mint{value: 0.24 ether}(1);
    }

}
