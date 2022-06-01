// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";
import "../src/HippyGhostsMinter.sol";
import "../src/HippyGhostsSwapPool.sol";

contract RendererTest is Test {
    HippyGhostsRenderer renderer;
    HippyGhostsMinter mintController;
    HippyGhosts hippyGhosts;
    HippyGhostsSwapPool swapPool;
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));
    address constant GHOSIS_SAFE = address(uint160(uint256(keccak256('gnosis safe account'))));

    function setUp() public {
        // init erc721
        hippyGhosts = new HippyGhosts();
        renderer = new HippyGhostsRenderer(address(hippyGhosts), "prefix1/");
        mintController = new HippyGhostsMinter(address(hippyGhosts), address(0));
        hippyGhosts.setAddresses(address(renderer), address(mintController));
        // init swap pool
        swapPool = new HippyGhostsSwapPool(address(hippyGhosts), GHOSIS_SAFE);
        // init EOA
        vm.deal(EOA1, 10 ether);
        vm.deal(EOA2, 10 ether);
    }

    function _fillTokens() public {
        // fill address with tokens
        uint256[] memory tokenIds = new uint256[](10);
        address[] memory addresses = new address[](10);
        // EOA1
        tokenIds[0] = 1; tokenIds[1] = 2;
        tokenIds[2] = 3; tokenIds[3] = 4;
        addresses[0] = EOA1; addresses[1] = EOA1;
        addresses[2] = EOA1; addresses[3] = EOA1;
        // SwapPool
        tokenIds[4] = 101; tokenIds[5] = 102;
        tokenIds[6] = 103; tokenIds[7] = 104;
        addresses[4] = address(swapPool); addresses[5] = address(swapPool);
        addresses[6] = address(swapPool); addresses[7] = address(swapPool);
        // EOA2
        tokenIds[8] = 201; tokenIds[9] = 202;
        addresses[8] = EOA2; addresses[9] = EOA2;
        // mint
        mintController.ownerMint(addresses, tokenIds);
    }

    function _packSwapData(uint256 tokenId) public pure returns (bytes memory) {
        return abi.encode(bytes4(keccak256("swap(uint256)")), tokenId);
    }

    function testSimpleTransfer() public {
        _fillTokens();
        vm.prank(EOA1, EOA1);
        hippyGhosts.safeTransferFrom(EOA1, address(swapPool), 1);
        assertEq(hippyGhosts.ownerOf(1), address(swapPool));
    }

    function testWithdraw() public {
        _fillTokens();
        vm.prank(GHOSIS_SAFE, GHOSIS_SAFE);
        hippyGhosts.safeTransferFrom(address(swapPool), GHOSIS_SAFE, 101);
        vm.prank(EOA1, EOA1);
        vm.expectRevert("WRONG_FROM");
        hippyGhosts.safeTransferFrom(address(swapPool), GHOSIS_SAFE, 101);
    }

    function testSwap() public {
        _fillTokens();
        assertEq(hippyGhosts.ownerOf(1), EOA1);
        assertEq(hippyGhosts.ownerOf(101), address(swapPool));
        vm.prank(EOA1, EOA1);
        hippyGhosts.safeTransferFrom(EOA1, address(swapPool), 1, _packSwapData(101));
        assertEq(hippyGhosts.ownerOf(1), address(swapPool));
        assertEq(hippyGhosts.ownerOf(101), EOA1);
    }

    function testSwapFail() public {
        _fillTokens();
        vm.prank(EOA1, EOA1);
        vm.expectRevert("The wanted Ghost doesn't belongs to SwapPool.");
        hippyGhosts.safeTransferFrom(EOA1, address(swapPool), 1, _packSwapData(201));
        vm.expectRevert("WRONG_FROM");
        hippyGhosts.safeTransferFrom(EOA1, address(swapPool), 201, _packSwapData(101));
    }
}
