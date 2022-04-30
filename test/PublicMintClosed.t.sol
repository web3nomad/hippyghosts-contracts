// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";


contract HippyGhostsTest is Test {
    HippyGhosts hippyGhosts;
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));

    function setUp() public {
        hippyGhosts = new HippyGhosts("", 0x0000000000000000000000000000000000000000);
        vm.roll(100);
        vm.deal(EOA1, 10 ether);
    }

    function testStartBlockNotSet() public {
        // emit log_uint(block.number);
        vm.prank(EOA1, EOA1);
        vm.expectRevert("Public sale is not open");
        hippyGhosts.mint(1);
    }

    function testStartBlockNotReach() public {
        hippyGhosts.setPublicMintStartBlock(200);  // set block number to 100 blocks later
        vm.prank(EOA1, EOA1);
        vm.expectRevert("Public sale is not open");
        hippyGhosts.mint(1);
    }

    function testMintSuccess() public {
        hippyGhosts.setPublicMintStartBlock(200);
        vm.roll(201);
        vm.prank(EOA1, EOA1);
        hippyGhosts.mint{value: 0.08 ether * 10}(10);
        assertEq(hippyGhosts.balanceOf(EOA1), 10);
        assertEq(address(hippyGhosts).balance, 0.08 ether * 10);
    }

    function testMintGasReport() public {
        hippyGhosts.setPublicMintStartBlock(100);
        vm.prank(EOA1, EOA1);
        hippyGhosts.mint{value: 0.08 ether}(1);
        assertEq(hippyGhosts.balanceOf(EOA1), 1);
        assertEq(address(hippyGhosts).balance, 0.08 ether);
    }

}
