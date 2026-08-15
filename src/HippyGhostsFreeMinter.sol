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
 * Free mint controller.
 * ----------------------------------------------------------------------------
 * Mints are sequential starting at `startTokenId_` (set at deploy time so this
 * contract can resume wherever a previous mint controller left off), free of
 * charge, capped by an owner-adjustable per-wallet limit, gated by an
 * owner-controlled open/closed switch.
 * ----------------------------------------------------------------------------
 */

import "@openzeppelin/contracts/access/Ownable.sol";

contract HippyGhostsFreeMinter is Ownable {

    /****************************************
     * Variables
     ****************************************/

    address public immutable hippyGhosts;

    uint256 public constant MAX_TOKEN_ID = 9999;

    /**
     * @dev Owner-controlled gate. Unlike the old minter's one-time
     * `publicMintStartBlock`, this can be flipped back off if something needs
     * to be paused or corrected after launch.
     */
    bool public mintOpen;

    /**
     * @dev Per-wallet cap, owner-adjustable rather than a hardcoded constant.
     */
    uint256 public maxPerWallet = 3;

    /**
     * @dev Next tokenId to be minted. Exposed so a future mint controller can
     * be constructed with this value as its own `startTokenId_` and continue
     * the sequence without collision.
     */
    uint256 public nextTokenId;

    mapping(address => uint256) public mintedCount;

    /****************************************
     * Events
     ****************************************/

    event MintOpenSet(bool open);
    event MaxPerWalletSet(uint256 maxPerWallet);

    /****************************************
     * Functions
     ****************************************/

    constructor(address hippyGhosts_, uint256 startTokenId_) {
        hippyGhosts = hippyGhosts_;
        nextTokenId = startTokenId_;
    }

    /* config functions */

    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
        emit MintOpenSet(open);
    }

    function setMaxPerWallet(uint256 maxPerWallet_) external onlyOwner {
        maxPerWallet = maxPerWallet_;
        emit MaxPerWalletSet(maxPerWallet_);
    }

    /* views */

    function remainingSupply() external view returns (uint256) {
        if (nextTokenId > MAX_TOKEN_ID) {
            return 0;
        }
        return MAX_TOKEN_ID - nextTokenId + 1;
    }

    /* mint */

    function mint(uint256 numberOfTokens) external {
        require(mintOpen, "Mint is not open");
        require(numberOfTokens > 0, "Must mint at least one");

        uint256 minted = mintedCount[msg.sender];
        require(minted + numberOfTokens <= maxPerWallet, "Exceeds per-wallet limit");

        uint256 tokenId = nextTokenId;
        require(tokenId + numberOfTokens - 1 <= MAX_TOKEN_ID, "Not enough ghosts remaining");

        // Effects before interactions: counters are fully updated before the
        // external mint calls below, so a reentrant call sees the post-mint
        // state and is bound by the same limits.
        mintedCount[msg.sender] = minted + numberOfTokens;
        nextTokenId = tokenId + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            IHippyGhosts(hippyGhosts).mint(msg.sender, tokenId + i);
        }
    }
}

interface IHippyGhosts {
    function mint(address to, uint256 tokenId) external;
}
