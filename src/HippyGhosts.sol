// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/interfaces/IERC2981.sol";
import "openzeppelin-contracts/access/Ownable.sol";

/**
 *   _    _ _____ _____  _______     __   _____ _    _  ____   _____ _______ _____
 *  | |  | |_   _|  __ \|  __ \ \   / /  / ____| |  | |/ __ \ / ____|__   __/ ____|
 *  | |__| | | | | |__) | |__) \ \_/ /  | |  __| |__| | |  | | (___    | | | (___
 *  |  __  | | | |  ___/|  ___/ \   /   | | |_ |  __  | |  | |\___ \   | |  \___ \
 *  | |  | |_| |_| |    | |      | |    | |__| | |  | | |__| |____) |  | |  ____) |
 *  |_|  |_|_____|_|    |_|      |_|     \_____|_|  |_|\____/|_____/   |_| |_____/
 *
 */

contract HippyGhosts is ERC721, IERC2981, Ownable {

    /****************************************
     * Variables
     ****************************************/

    /**
     *  @dev the contract implements the minting logic
     */
    address public mintController;

    /**
     *  @dev renderer for {IERC721Metadata-tokenURI}
     */
    address public renderer;

    /**
     * @dev See {IERC721Enumerable-totalSupply}
     * IERC721Enumerable is not implemented in this contract except totalSupply
     */
    uint256 public totalSupply;

    /****************************************
     * Functions
     ****************************************/

    constructor() ERC721("Hippy Ghosts", "GHOST") {}

    receive() external payable {}

    /* config functions */

    function setParams(address renderer_, address mintController_) external onlyOwner {
        renderer = renderer_;
        mintController = mintController_;
    }

    /* mint logic */

    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf[tokenId] != address(0);
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == mintController, "caller is not the mint controller");
        _safeMint(to, tokenId, "");
        totalSupply = totalSupply + 1;
    }

    /* overrides */

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
        return IRenderer(renderer).tokenURI(tokenId);
    }

    /**
     * @dev See {IERC2981-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_ownerOf[tokenId] != address(0), "royaltyInfo for nonexistent token");
        return (address(this), salePrice * 5 / 100);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /* withdraw from contract */

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawTokens(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

}

interface IRenderer {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
