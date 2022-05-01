// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";


contract HippyGhostsTest is Test {
    using ECDSA for bytes32;

    HippyGhosts hippyGhosts;
    uint256 constant VERIFICATION_PRIVATE_KEY = uint256(keccak256('verification'));
    address constant EOA1 = address(uint160(uint256(keccak256('user account 1'))));
    address constant EOA2 = address(uint160(uint256(keccak256('user account 2'))));

    function setUp() public {
        HippyGhostsRenderer renderer = new HippyGhostsRenderer("");
        address verificationAddress = vm.addr(VERIFICATION_PRIVATE_KEY);
        hippyGhosts = new HippyGhosts(address(renderer), verificationAddress);
        // hippyGhosts.setVerificationAddress(verificationAddress);
    }

    function _sign(bytes memory data) private returns (bytes memory signature) {
        bytes32 hash = keccak256(data).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VERIFICATION_PRIVATE_KEY, hash);
        signature = abi.encodePacked(r, s, v);
    }

    function testMintGasReport1() public {
        hoax(EOA1, 10 ether);
        uint256 numberOfTokens = 1;
        uint256 valueInWei = 0.04 ether;
        address mintKey = 0x0000000000000000000000000000000000000001;
        bytes memory data = abi.encodePacked(
            EOA1, numberOfTokens, valueInWei, mintKey, address(hippyGhosts));
        bytes memory signature = _sign(data);
        hippyGhosts.mintWithSignature{ value: valueInWei }(
            numberOfTokens, valueInWei, mintKey, signature);
    }

    function testMintGasReport2() public {
        hoax(EOA1, 10 ether);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        uint256 valueInWei = 0.04 ether;
        address mintKey = 0x0000000000000000000000000000000000000001;
        bytes memory data = abi.encodePacked(
            EOA1, tokenIds, valueInWei, mintKey, address(hippyGhosts));
        bytes memory signature = _sign(data);
        hippyGhosts.mintMultipleTokensWithSignature{ value: valueInWei }(
            tokenIds, valueInWei, mintKey, signature);
    }

}
