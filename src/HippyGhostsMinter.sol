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
 * Total 9999 Hippy Ghosts
 * ----------------------------------------------------------------------------
 * 1 |  200 | [1,200]     | 1/1 ghosts, kept for team
 * 2 | 1300 | [201,1500]  | private mint, 300 for team, 1000 for community
 * 3 | 8499 | [1501,9999] | public mint, release 300 ghosts every 40000 blocks
 * ----------------------------------------------------------------------------
 */

import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "./libraries/SignatureVerification.sol";

contract HippyGhostsMinter is Ownable {

    /****************************************
     * Variables
     ****************************************/

    IHippyGhosts public immutable hippyGhosts;

    /**
     * @dev Ether value for each token in public mint
     */
    uint256 public publicMintPriceUpper = 0.08 ether;
    uint256 public publicMintPriceLower = 0.04 ether;
    uint256 public publicMintPriceDecay = 0.01 ether;

    /**
     * @dev Starting block and inverval for public mint
     */
    uint256 public publicMintStartBlock = 0;
    uint256 public EPOCH_BLOCKS = 40000;
    uint256 public GHOSTS_PER_EPOCH = 300;

    /**
     * @dev Index and upper bound for mint
     */
    // general
    uint256 public constant MAX_GHOSTS_PER_MINT = 10;
    // team
    uint256 public ownerMintCount = 0;
    uint256 public constant MAX_OWNER_MINT_COUNT = 200;
    // private
    uint256 public privateMintIndex = 200;
    uint256 public constant MAX_PRIVATE_MINT_INDEX = 1500;
    // public
    uint256 public publicMintIndex = 1500;
    uint256 public constant MAX_PUBLIC_MINT_INDEX = 9999;

    /**
     * @dev Public address used to sign function calls parameters
     */
    address public verificationAddress;

    /**
     * @dev Key(address) mapping to a claimed key.
     * Used to prevent address from rebroadcasting mint transactions
     */
    mapping(address => bool) private _claimedMintKeys;

    /****************************************
     * Events
     ****************************************/

    /**
     * @dev provide feedback on mint key used for signed mints
     */
    event MintKeyClaimed(
        address indexed claimer,
        address indexed mintKey,
        uint256 numberOfTokens
    );


    /****************************************
     * Functions
     ****************************************/

    constructor(
        address hippyGhosts_,
        address verificationAddress_
    ) {
        hippyGhosts = IHippyGhosts(hippyGhosts_);
        verificationAddress = verificationAddress_;
    }

    receive() external payable {}

    /* config functions */

    function setPublicMintStartBlock(uint256 publicMintStartBlock_) external onlyOwner {
        require(publicMintStartBlock == 0, "publicMintStartBlock has already been set");
        publicMintStartBlock = publicMintStartBlock_;
    }

    function setVerificationAddress(address verificationAddress_) external onlyOwner {
        verificationAddress = verificationAddress_;
    }

    function isMintKeyClaimed(address mintKey) external view returns (bool) {
        return _claimedMintKeys[mintKey];
    }

    /* internal mint logic */

    // function _exists(uint256 tokenId) internal returns (bool) {
    //     (bool success, bytes memory result) =
    //         address(hippyGhosts).call(abi.encodeWithSignature("ownerOf(uint256)", tokenId));
    //     return success && (abi.decode(result, (address)) != address(0));
    // }

    function _privateSafeMint(address to, uint256 tokenId) internal {
        require(tokenId <= MAX_PRIVATE_MINT_INDEX, "Incorrect tokenId to mint");
        hippyGhosts.mint(to, tokenId);
    }

    /* private mint functions */

    function ownerMint(
        address[] calldata addresses,
        uint256[] calldata tokenIds
    ) external onlyOwner {
        ownerMintCount = ownerMintCount + tokenIds.length;
        require(ownerMintCount <= MAX_OWNER_MINT_COUNT, "Not enough ghosts remaining to mint");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] <= MAX_PRIVATE_MINT_INDEX, "Incorrect tokenId to mint");
            hippyGhosts.mint(addresses[i], tokenIds[i]);
        }
    }

    function mintWithSignature(
        uint256 numberOfTokens,
        uint256 valueInWei,
        address mintKey,
        bytes memory signature
    ) external payable {
        require(valueInWei == msg.value, "Incorrect ether value sent");
        require(_claimedMintKeys[mintKey] == false, "Mint key already claimed");

        SignatureVerification.requireValidSignature(
            abi.encodePacked(msg.sender, numberOfTokens, valueInWei, mintKey, this),
            signature,
            verificationAddress
        );

        _claimedMintKeys[mintKey] = true;
        emit MintKeyClaimed(msg.sender, mintKey, numberOfTokens);

        for (uint256 i = 0; i < numberOfTokens; i++) {
            // count to next index before minting
            privateMintIndex = privateMintIndex + 1;
            while (hippyGhosts.exists(privateMintIndex)) {
                // skip tokenId minted in mintMultipleTokensWithSignature
                privateMintIndex = privateMintIndex + 1;
            }
            _privateSafeMint(msg.sender, privateMintIndex);
        }
    }

    function mintMultipleTokensWithSignature(
        uint256[] memory tokenIds,
        uint256 valueInWei,
        address mintKey,
        bytes memory signature
    ) external payable {
        require(valueInWei == msg.value, "Incorrect ether value sent");
        require(_claimedMintKeys[mintKey] == false, "Mint key already claimed");

        SignatureVerification.requireValidSignature(
            abi.encodePacked(msg.sender, tokenIds, valueInWei, mintKey, this),
            signature,
            verificationAddress
        );

        _claimedMintKeys[mintKey] = true;
        emit MintKeyClaimed(msg.sender, mintKey, tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            _privateSafeMint(msg.sender, tokenId);
        }
    }

    /* public mint functions */

    /**
     *  @dev Epoch number start from 1, will increase every [EPOCH_BLOCKS] blocks
     */
    function currentEpoch() public view returns (uint256) {
        if (publicMintStartBlock == 0 || block.number < publicMintStartBlock) {
            return 0;
        }
        uint256 epoches = (block.number - publicMintStartBlock) / EPOCH_BLOCKS;
        return epoches + 1;
    }

    function epochOfToken(uint256 tokenId) public view returns (uint256) {
        assert(tokenId > MAX_PRIVATE_MINT_INDEX);
        uint256 epoches = (tokenId - MAX_PRIVATE_MINT_INDEX - 1) / GHOSTS_PER_EPOCH;
        return epoches + 1;
    }

    // function ghostsReleased() public view returns (uint256) {
    //     uint256 released = GHOSTS_PER_EPOCH * currentEpoch();
    //     if (released > MAX_PUBLIC_MINT_INDEX - MAX_PRIVATE_MINT_INDEX) {
    //         released = MAX_PUBLIC_MINT_INDEX - MAX_PRIVATE_MINT_INDEX;
    //     }
    //     return released;
    // }

    // function _ghostsMintedInPublic() internal view returns (uint256) {
    //     return publicMintIndex - MAX_PRIVATE_MINT_INDEX;
    // }

    // function _available() internal view returns (uint256) {
    //     return ghostsReleased() - ghostsMintedInPublic();
    // }

    function priceForTokenId(uint256 tokenId) public view returns (uint256) {
        uint256 cEpoch = currentEpoch();
        uint256 tEpoch = epochOfToken(tokenId);
        assert(tEpoch > 0);
        require(cEpoch >= tEpoch, "Target epoch is not open");
        uint256 price = publicMintPriceUpper - (cEpoch - tEpoch) * publicMintPriceDecay;
        if (price < publicMintPriceLower) {
            price = publicMintPriceLower;
        }
        return price;
    }

    function mint(uint256 numberOfTokens) external payable {
        require(publicMintStartBlock > 0 && block.number >= publicMintStartBlock, "Public sale is not open");
        require(numberOfTokens <= MAX_GHOSTS_PER_MINT, "Max ghosts to mint is 10");
        uint256 _etherValue = msg.value;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            publicMintIndex = publicMintIndex + 1;
            require(publicMintIndex <= MAX_PUBLIC_MINT_INDEX, "Incorrect tokenId to mint");
            uint256 price = priceForTokenId(publicMintIndex);
            require(_etherValue >= price, "Ether value not enough");
            _etherValue = _etherValue - price;
            hippyGhosts.mint(msg.sender, publicMintIndex);
        }
        if (_etherValue > 0) {
            payable(msg.sender).transfer(_etherValue);
        }
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

interface IHippyGhosts {
    function mint(address to, uint256 tokenId) external;
    function exists(uint256 tokenId) external view returns (bool);
}
