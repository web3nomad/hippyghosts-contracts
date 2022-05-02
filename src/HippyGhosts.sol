// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 *   _    _ _____ _____  _______     __   _____ _    _  ____   _____ _______ _____
 *  | |  | |_   _|  __ \|  __ \ \   / /  / ____| |  | |/ __ \ / ____|__   __/ ____|
 *  | |__| | | | | |__) | |__) \ \_/ /  | |  __| |__| | |  | | (___    | | | (___
 *  |  __  | | | |  ___/|  ___/ \   /   | | |_ |  __  | |  | |\___ \   | |  \___ \
 *  | |  | |_| |_| |    | |      | |    | |__| | |  | | |__| |____) |  | |  ____) |
 *  |_|  |_|_____|_|    |_|      |_|     \_____|_|  |_|\____/|_____/   |_| |_____/
 *
 */

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/interfaces/IERC2981.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "./HippyGhostsMinter.sol";
import "./HippyGhostsRenderer.sol";


contract HippyGhosts is ERC721, IERC2981, Ownable {

    /****************************************
     * Variables
     ****************************************/

    /**
     *  @dev the contract implements the minting logic
     */
    address payable public mintController;

    /**
     *  @dev renderer for {IERC721Metadata-tokenURI}
     */
    address public renderer;


    /****************************************
     * Functions
     ****************************************/

    constructor(
        string memory baseURI_,
        address verificationAddress_
    ) ERC721("Hippy Ghosts", "GHOST") {
        HippyGhostsRenderer _renderer = new HippyGhostsRenderer(address(this), baseURI_);
        HippyGhostsMinter _mintController = new HippyGhostsMinter(address(this), verificationAddress_);
        _renderer.transferOwnership(_msgSender());
        _mintController.transferOwnership(_msgSender());
        renderer = address(_renderer);
        mintController = payable(address(_mintController));
    }

    receive() external payable {}

    /* config functions */

    function setRenderer(address renderer_) external onlyOwner {
        renderer = renderer_;
    }

    function setMintController(address payable mintController_) external onlyOwner {
        mintController = mintController_;
    }

    /* mint logic */

    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf[tokenId] != address(0);
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == mintController, "caller is not the mint controller");
        require(tokenId >= 1 && tokenId <= 9999, "Incorrect tokenId to mint");
        _safeMint(to, tokenId, "");
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
        public
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
