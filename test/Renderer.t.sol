// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";
import "../src/HippyGhostsMinter.sol";


contract RendererTest is Test {
    HippyGhostsRenderer renderer;
    HippyGhostsMinter mintController;
    HippyGhosts hippyGhosts;
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));

    function setUp() public {
        hippyGhosts = new HippyGhosts();
        renderer = new HippyGhostsRenderer(address(hippyGhosts), "prefix1/");
        mintController = new HippyGhostsMinter(address(hippyGhosts), address(0));
        hippyGhosts.setAddresses(address(renderer), address(mintController));
        // open public mint
        mintController.setPublicMintStartBlock(100);
        vm.roll(100);
        vm.deal(EOA1, 10 ether);
        vm.deal(EOA2, 10 ether);
    }

    uint256 _tokenId = 1500;
    function _mint() private returns (uint256) {
        _tokenId += 1;
        vm.prank(EOA1, EOA1);
        mintController.mint{value: 0.24 ether}(1);
        assertEq(hippyGhosts.ownerOf(_tokenId), EOA1);
        return _tokenId;
    }

    function testTokenURI() public {
        vm.expectRevert("ERC721Metadata: URI query for nonexistent token");
        hippyGhosts.tokenURI(1501);
        // mint
        uint256 tokenId = _mint();
        assertEq(hippyGhosts.tokenURI(tokenId), "prefix1/1501");
    }

    function testChangeBaseURI() public {
        uint256 tokenId = _mint();
        // change renderer
        HippyGhostsRenderer _renderer = new HippyGhostsRenderer(address(hippyGhosts), "prefix2/");
        hippyGhosts.setAddresses(address(_renderer), address(0));
        assertEq(hippyGhosts.tokenURI(tokenId), "prefix2/1501");
        // new token
        tokenId = _mint();
        assertEq(hippyGhosts.tokenURI(tokenId), "prefix2/1502");
        // change again
        _renderer.setBaseURI("prefix3/");
        assertEq(hippyGhosts.tokenURI(tokenId), "prefix3/1502");
    }

    function testRendererDestruct() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(EOA1, EOA1);
        renderer.selfDestruct();
        // mint
        uint256 tokenId = _mint();
        assertEq(hippyGhosts.tokenURI(tokenId), "prefix1/1501");
        // again with owner
        renderer.selfDestruct();
        /**
         * IMPORTANT: selfdestruct will destruct contract after transaction is complete,
         * so there won't be error next line
         */
        // hippyGhosts.setRenderer(address(0));
        // vm.expectRevert();
        // string memory uri = hippyGhosts.tokenURI(tokenId);
        // emit log(uri);
    }

}
