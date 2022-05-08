// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";
import "../src/HippyGhostsMinter.sol";


contract PublicMintClosedTest is Test {
    HippyGhostsRenderer renderer;
    HippyGhostsMinter mintController;
    HippyGhosts hippyGhosts;
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));

    function setUp() public {
        hippyGhosts = new HippyGhosts();
        renderer = new HippyGhostsRenderer(address(hippyGhosts), "");
        mintController = new HippyGhostsMinter(address(hippyGhosts), address(0));
        hippyGhosts.setAddresses(address(renderer), address(mintController));
        vm.roll(100);
        vm.deal(EOA1, 10 ether);
    }

    function testStartBlockNotSet() public {
        // emit log_uint(block.number);
        vm.prank(EOA1, EOA1);
        vm.expectRevert("Public sale is not open");
        mintController.mint(1);
    }

    function testStartBlockNotReach() public {
        mintController.setPublicMintStartBlock(200);  // set block number to 100 blocks later
        vm.prank(EOA1, EOA1);
        vm.expectRevert("Public sale is not open");
        mintController.mint(1);
    }

    function testMintSuccess_Report() public {
        mintController.setPublicMintStartBlock(200);
        vm.roll(201);
        vm.prank(EOA1, EOA1);
        mintController.mint{value: 0.24 ether * 10}(10);
        assertEq(hippyGhosts.balanceOf(EOA1), 10);
        assertEq(address(mintController).balance, 0.24 ether * 10);
    }

    function testMint1_Report() public {
        mintController.setPublicMintStartBlock(100);
        vm.prank(EOA1, EOA1);
        mintController.mint{value: 0.24 ether}(1);
        assertEq(hippyGhosts.balanceOf(EOA1), 1);
        assertEq(address(mintController).balance, 0.24 ether);
    }

}
