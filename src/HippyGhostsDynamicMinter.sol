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
 * Demand-responsive mint controller.
 * ----------------------------------------------------------------------------
 * Pricing works like a base fee (EIP-1559) / linear VRGDA: every mint pushes
 * the price up by `priceBump`, and the price decays back toward `floorPrice`
 * by `decayPerBlock` per block while nobody mints. The sustainable free rate
 * is decayPerBlock / priceBump tokens per block — mint slower than that and
 * the price stays at the floor; mint faster and it climbs, capped at
 * `maxPrice`.
 *
 * With floorPrice = 0 this is a free mint in quiet times that automatically
 * charges a congestion price during demand spikes — which also makes sybil
 * sweeps of the free supply self-defeating: the sweep itself drives the price
 * up under the sweeper.
 *
 * Mints are sequential starting at `startTokenId_` (set at deploy time so this
 * contract can resume wherever a previous mint controller left off), capped by
 * an owner-adjustable per-wallet limit, gated by an owner-controlled
 * open/closed switch. All price parameters are immutable: the pricing rule is
 * a public commitment, and changing it later means deploying a new mint
 * controller — the same swap mechanism that installed this one.
 * ----------------------------------------------------------------------------
 */

import "@openzeppelin/contracts/access/Ownable.sol";

contract HippyGhostsDynamicMinter is Ownable {

    /****************************************
     * Variables
     ****************************************/

    address public immutable hippyGhosts;

    uint256 public constant MAX_TOKEN_ID = 9999;

    /**
     * @dev Price the curve decays back to when nobody is minting.
     */
    uint256 public immutable floorPrice;

    /**
     * @dev Hard ceiling the price can never exceed, however heavy demand gets.
     */
    uint256 public immutable maxPrice;

    /**
     * @dev How much each minted token pushes the price up.
     */
    uint256 public immutable priceBump;

    /**
     * @dev How much the price decays back toward the floor per block.
     */
    uint256 public immutable decayPerBlock;

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

    /**
     * @dev Price immediately after the most recent mint, and the block it
     * happened in. `currentPrice()` is derived from these by applying decay
     * for the blocks elapsed since.
     */
    uint256 public lastPrice;
    uint256 public lastMintBlock;

    mapping(address => uint256) public mintedCount;

    /****************************************
     * Events
     ****************************************/

    event MintOpenSet(bool open);
    event MaxPerWalletSet(uint256 maxPerWallet);

    /****************************************
     * Functions
     ****************************************/

    constructor(
        address hippyGhosts_,
        uint256 startTokenId_,
        uint256 floorPrice_,
        uint256 maxPrice_,
        uint256 priceBump_,
        uint256 decayPerBlock_
    ) {
        require(startTokenId_ >= 1 && startTokenId_ <= MAX_TOKEN_ID, "Invalid start token id");
        require(maxPrice_ >= floorPrice_, "Invalid price bounds");
        hippyGhosts = hippyGhosts_;
        nextTokenId = startTokenId_;
        floorPrice = floorPrice_;
        maxPrice = maxPrice_;
        priceBump = priceBump_;
        decayPerBlock = decayPerBlock_;
        lastPrice = floorPrice_;
        lastMintBlock = block.number;
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

    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    /* views */

    function remainingSupply() external view returns (uint256) {
        if (nextTokenId > MAX_TOKEN_ID) {
            return 0;
        }
        return MAX_TOKEN_ID - nextTokenId + 1;
    }

    /**
     * @dev Price of the next single token: last post-mint price minus decay
     * for the blocks elapsed since, never below the floor. The division-based
     * comparison (instead of computing blocksElapsed * decayPerBlock directly)
     * keeps the multiplication bounded so it can never overflow no matter how
     * long the quiet period is.
     */
    function currentPrice() public view returns (uint256) {
        uint256 drop = lastPrice - floorPrice;
        if (decayPerBlock == 0 || drop == 0) {
            return lastPrice;
        }
        uint256 blocksElapsed = block.number - lastMintBlock;
        if (blocksElapsed > drop / decayPerBlock) {
            return floorPrice;
        }
        return lastPrice - blocksElapsed * decayPerBlock;
    }

    /**
     * @dev Total cost of minting `numberOfTokens` right now. The first token
     * costs `currentPrice()`, and each subsequent token in the batch costs
     * `priceBump` more, all capped at `maxPrice` — the batch pushes the price
     * up under itself the same way separate transactions would. Frontends
     * should send this value (the price can shift between quote and
     * inclusion if others mint in between; excess is refunded, shortfall
     * reverts).
     */
    function priceForNext(uint256 numberOfTokens) public view returns (uint256) {
        uint256 unitPrice = currentPrice();
        uint256 total = 0;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            total += unitPrice;
            unitPrice += priceBump;
            if (unitPrice > maxPrice) {
                unitPrice = maxPrice;
            }
        }
        return total;
    }

    /* mint */

    function mint(uint256 numberOfTokens) external payable {
        require(mintOpen, "Mint is not open");
        require(numberOfTokens > 0, "Must mint at least one");

        uint256 minted = mintedCount[msg.sender];
        require(minted + numberOfTokens <= maxPerWallet, "Exceeds per-wallet limit");

        uint256 tokenId = nextTokenId;
        require(tokenId + numberOfTokens - 1 <= MAX_TOKEN_ID, "Not enough ghosts remaining");

        uint256 totalPrice = priceForNext(numberOfTokens);
        require(msg.value >= totalPrice, "Insufficient payment");

        // Effects before interactions: counters and price state are fully
        // updated before the external mint calls and the refund below, so a
        // reentrant call sees the post-mint state and is bound by the same
        // limits and the already-raised price.
        mintedCount[msg.sender] = minted + numberOfTokens;
        nextTokenId = tokenId + numberOfTokens;
        uint256 raisedPrice = currentPrice() + numberOfTokens * priceBump;
        lastPrice = raisedPrice > maxPrice ? maxPrice : raisedPrice;
        lastMintBlock = block.number;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            IHippyGhosts(hippyGhosts).mint(msg.sender, tokenId + i);
        }

        if (msg.value > totalPrice) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(success, "Refund failed");
        }
    }
}

interface IHippyGhosts {
    function mint(address to, uint256 tokenId) external;
}
