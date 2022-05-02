// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";
import "../src/HippyGhostsMinter.sol";


contract PrivateMintTest is Test {
    using ECDSA for bytes32;

    HippyGhostsRenderer renderer;
    HippyGhostsMinter mintController;
    HippyGhosts hippyGhosts;
    uint256 constant VERIFICATION_PRIVATE_KEY = uint256(keccak256('verification'));
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));

    function setUp() public {
        hippyGhosts = new HippyGhosts();
        renderer = new HippyGhostsRenderer("");
        address verificationAddress = vm.addr(VERIFICATION_PRIVATE_KEY);
        mintController = new HippyGhostsMinter(address(hippyGhosts), verificationAddress);
        // hippyGhosts.setVerificationAddress(verificationAddress);
        hippyGhosts.setParams(address(renderer), address(mintController));
    }

    function _sign(bytes memory data) private returns (bytes memory signature) {
        bytes32 hash = keccak256(data).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VERIFICATION_PRIVATE_KEY, hash);
        signature = abi.encodePacked(r, s, v);
    }

    function testOwnerMint_Report() public {
        uint256[] memory tokenIds = new uint256[](1);
        address[] memory addresses = new address[](1);
        tokenIds[0] = 3;
        addresses[0] = EOA1;
        mintController.ownerMint(addresses, tokenIds);
        assertEq(hippyGhosts.ownerOf(3), EOA1);
    }

    function testOwnerMintMultiple_Report() public {
        uint256[] memory tokenIds = new uint256[](10);
        address[] memory addresses = new address[](10);
        tokenIds[0] = 3; tokenIds[1] = 5;
        tokenIds[2] = 6; tokenIds[3] = 7;
        tokenIds[4] = 8; tokenIds[5] = 9;
        tokenIds[6] = 10; tokenIds[7] = 11;
        tokenIds[8] = 12; tokenIds[9] = 13;
        addresses[0] = EOA1; addresses[1] = EOA1;
        addresses[2] = EOA1; addresses[3] = EOA1;
        addresses[4] = EOA1; addresses[5] = EOA1;
        addresses[6] = EOA1; addresses[7] = EOA1;
        addresses[8] = EOA1; addresses[9] = EOA1;
        mintController.ownerMint(addresses, tokenIds);
        assertEq(hippyGhosts.ownerOf(3), EOA1);
    }

    function testTokenIdSequence() public {
        // specific token mint 1
        {
            uint256[] memory tokenIds = new uint256[](3);
            tokenIds[0] = 202;
            tokenIds[1] = 204;
            tokenIds[2] = 205;
            uint256 valueInWei = 0.04 ether;
            address mintKey = 0x0000000000000000000000000000000000000001;
            bytes memory data = abi.encodePacked(
                EOA1, tokenIds, valueInWei, mintKey, address(mintController));
            bytes memory signature = _sign(data);
            hoax(EOA1, 10 ether);
            mintController.mintMultipleTokensWithSignature{ value: valueInWei }(
                tokenIds, valueInWei, mintKey, signature);
            assertEq(hippyGhosts.ownerOf(202), EOA1);
            assertEq(hippyGhosts.ownerOf(204), EOA1);
            assertEq(hippyGhosts.ownerOf(205), EOA1);
        }
        // sequence mint 5
        {
            uint256 numberOfTokens = 5;
            uint256 valueInWei = 0.04 ether * 5;
            address mintKey = 0x0000000000000000000000000000000000000002;
            bytes memory data = abi.encodePacked(
                EOA2, numberOfTokens, valueInWei, mintKey, address(mintController));
            bytes memory signature = _sign(data);
            hoax(EOA2, 10 ether);
            mintController.mintWithSignature{ value: valueInWei }(
                numberOfTokens, valueInWei, mintKey, signature);
            assertEq(hippyGhosts.ownerOf(201), EOA2);
            assertEq(hippyGhosts.ownerOf(203), EOA2);
            assertEq(hippyGhosts.ownerOf(206), EOA2);
            assertEq(hippyGhosts.ownerOf(207), EOA2);
            assertEq(hippyGhosts.ownerOf(208), EOA2);
        }
    }

    function testMintWithSignature_Report() public {
        uint256 numberOfTokens = 1;
        uint256 valueInWei = 0.04 ether;
        address mintKey = 0x0000000000000000000000000000000000000001;
        bytes memory data = abi.encodePacked(
            EOA1, numberOfTokens, valueInWei, mintKey, address(mintController));
        bytes memory signature = _sign(data);
        hoax(EOA1, 10 ether);
        mintController.mintWithSignature{ value: valueInWei }(
            numberOfTokens, valueInWei, mintKey, signature);
        // again with 10 tokens
        numberOfTokens = 10;
        valueInWei = 0.04 ether * 10;
        mintKey = 0x0000000000000000000000000000000000000002;
        data = abi.encodePacked(
            EOA1, numberOfTokens, valueInWei, mintKey, address(mintController));
        signature = _sign(data);
        hoax(EOA1, 10 ether);
        mintController.mintWithSignature{ value: valueInWei }(
            numberOfTokens, valueInWei, mintKey, signature);
    }

    function testMintMultipleTokensWithSignature_Report() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        uint256 valueInWei = 0.04 ether;
        address mintKey = 0x0000000000000000000000000000000000000001;
        bytes memory data = abi.encodePacked(
            EOA1, tokenIds, valueInWei, mintKey, address(mintController));
        bytes memory signature = _sign(data);
        hoax(EOA1, 10 ether);
        mintController.mintMultipleTokensWithSignature{ value: valueInWei }(
            tokenIds, valueInWei, mintKey, signature);
    }

}
