// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../HippyGhosts.sol";


contract HippyGhostsTest is Test {
    using stdStorage for StdStorage;

    HippyGhosts hippyGhosts;
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));
    uint256 constant BASE_BLOCK = 10000000;

    function setUp() public {
        hippyGhosts = new HippyGhosts("", 0x0000000000000000000000000000000000000000);
        vm.roll(BASE_BLOCK - 10000);
        hippyGhosts.setPublicMintStartBlock(BASE_BLOCK + 1);
        vm.deal(EOA1, 10000 ether);
        vm.deal(EOA2, 10000 ether);
    }

    function testMintFirstWeek() public {
        vm.roll(BASE_BLOCK + 10);
        vm.prank(EOA1, EOA1);
        /**/
        hippyGhosts.mint{value: 0.08 ether * 10}(10);
        assertEq(hippyGhosts.balanceOf(EOA1), 10);
        assertEq(address(hippyGhosts).balance, 0.08 ether * 10);
    }

    /**
     * first week (block[1,40000]) release 300 tokens, all minted
     * second week (block[40001,80000]) release 300 tokens, all minted
     */
    function testMintSecondWeek() public {
        /**
         * first week
         */
        vm.roll(BASE_BLOCK + 1);
        for (uint256 i=0; i<30; i++) {
            vm.prank(EOA1, EOA1);
            hippyGhosts.mint{value: 0.08 ether * 10}(10);
        }
        // uint256 slot = stdstore.target(address(hippyGhosts)).sig(hippyGhosts.publicMintIndex.selector).find();
        // assertEq(uint(vm.load(address(hippyGhosts), bytes32(slot))), 1500 + 300);
        assertEq(hippyGhosts.publicMintIndex(), 1500 + 300);
        assertEq(hippyGhosts.balanceOf(EOA1), 300);
        assertEq(address(hippyGhosts).balance, 0.08 ether * 300);
        /**
         * cannot mint any more
         */
        vm.roll(BASE_BLOCK + 40000);
        vm.prank(EOA2, EOA2);
        vm.expectRevert("Target epoch is not open");
        hippyGhosts.mint{value: 0.08 ether}(1);
        /**
         * second week
         */
        vm.roll(BASE_BLOCK + 40001);
        for (uint256 i=0; i<15; i++) {
            vm.prank(EOA2, EOA2);
            hippyGhosts.mint{value: 0.08 ether * 10}(10);
        }
        assertEq(hippyGhosts.publicMintIndex(), 1500 + 300 + 150);
        assertEq(hippyGhosts.balanceOf(EOA2), 150);
        assertEq(address(hippyGhosts).balance, 0.08 ether * (300 + 150));
    }

    /**
     * release 300 in first week but only 150 minted
     * release 300 more in second week and 200 more are minted
     */
    function testMintFirstWeekDecay() public {
        /**
         * first week
         */
        vm.roll(BASE_BLOCK + 1);
        for (uint256 i=0; i<15; i++) {
            vm.prank(EOA1, EOA1);
            hippyGhosts.mint{value: 0.08 ether * 10}(10);
        }
        /**
         * second week
         */
        vm.roll(BASE_BLOCK + 40001);
        for (uint256 i=0; i<20; i++) {
            vm.prank(EOA2, EOA2);
            hippyGhosts.mint{value: 0.08 ether * 10}(10);
        }
        assertEq(hippyGhosts.publicMintIndex(), 1500 + 150 + 200);
        assertEq(hippyGhosts.balanceOf(EOA1), 150);
        assertEq(hippyGhosts.balanceOf(EOA2), 200);
        assertEq(address(hippyGhosts).balance, 0.08 ether * 150 + 0.07 ether * 150 + 0.08 ether * 50);
    }

    /**
     * release 300 in first week but only 150 minted
     * release 300 more in second week and 200 more are minted
     */
    function testMintFirstWeekDecay2() public {
        vm.startPrank(EOA1, EOA1);
        /**
         * first week
         */
        vm.roll(BASE_BLOCK + 1);
        for (uint256 i=0; i<29; i++) {
            hippyGhosts.mint{value: 0.08 ether * 10}(10);
        }
        hippyGhosts.mint{value: 0.08 ether * 9}(9);
        /**
         * 4 weeks later, price decayed to 0.04
         */
        vm.roll(BASE_BLOCK + 1 + 40000 * 4);
        for (uint256 i=0; i<2; i++) {
            hippyGhosts.mint{value: 0.08 ether}(1);
        }
        assertEq(hippyGhosts.publicMintIndex(), 1500 + 299 + 2);
        assertEq(address(hippyGhosts).balance, 0.08 ether * 299 + 0.04 ether + 0.05 ether);
    }

}
