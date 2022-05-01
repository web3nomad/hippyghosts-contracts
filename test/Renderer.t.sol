// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";


contract HippyGhostsTest is Test {
    HippyGhostsRenderer renderer;
    HippyGhosts hippyGhosts;
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));

    function setUp() public {
        renderer = new HippyGhostsRenderer("prefix1/");
        hippyGhosts = new HippyGhosts(renderer, address(0));
        // open public mint
        hippyGhosts.setPublicMintStartBlock(100);
        vm.roll(100);
        vm.deal(EOA1, 10 ether);
        vm.deal(EOA2, 10 ether);
    }

    uint256 _tokenId = 1500;
    function _mint() private returns (uint256) {
        _tokenId += 1;
        vm.prank(EOA1, EOA1);
        hippyGhosts.mint{value: 0.08 ether}(1);
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
        HippyGhostsRenderer _renderer = new HippyGhostsRenderer("prefix2/");
        hippyGhosts.setRenderer(_renderer);
        assertEq(hippyGhosts.tokenURI(tokenId), "prefix2/1501");
        // new token
        tokenId = _mint();
        assertEq(hippyGhosts.tokenURI(tokenId), "prefix2/1502");
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
        // hippyGhosts.setRenderer(HippyGhostsRenderer(address(0)));
        // vm.expectRevert();
        // string memory uri = hippyGhosts.tokenURI(tokenId);
        // emit log(uri);
    }

}
