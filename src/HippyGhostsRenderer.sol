// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "openzeppelin-contracts/utils/Strings.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract HippyGhostsRenderer is Ownable {
    using Strings for uint256;

    string public baseURI;

    constructor(string memory baseURI_) {
        baseURI = baseURI_;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function selfDestruct() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }

}
