// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 * Deploys HippyGhostsDynamicMinter and hands its ownership to ADMIN_ADDRESS.
 *
 * This deliberately does NOT call HippyGhosts.setAddresses(). On mainnet,
 * HippyGhosts is owned by a Gnosis Safe, which cannot sign a broadcast
 * transaction — connecting the newly deployed minter is a separate action the
 * Safe must take on its own (via the Safe UI's Contract Interaction feature,
 * calling setAddresses(address(0), <minter address>) on HippyGhosts). Bundling
 * both steps into one broadcast only works when the deployer happens to also
 * be the HippyGhosts owner, which is true on a fresh testnet deployment but
 * false on mainnet.
 *
 * ADMIN_ADDRESS is required, not defaulted to the deployer, so whoever runs
 * this script has to consciously decide who ends up controlling
 * setMintOpen/setMaxPerWallet/withdraw — on mainnet that must be the Gnosis
 * Safe, not a throwaway deployer key.
 *
 * Reads HIPPYGHOSTS_ADDRESS, START_TOKEN_ID, and ADMIN_ADDRESS from the
 * environment so the same script runs unmodified against any network. The
 * price parameters are NOT env vars: they are the economic commitment being
 * deployed, so they live here as reviewed constants.
 */

import "forge-std/Script.sol";
import "../src/HippyGhostsDynamicMinter.sol";

contract DeployDynamicMinterScript is Script {

    // Free in quiet times (floor 0). Every mint bumps the price by 0.0001
    // ETH; it decays back by 0.0000007 ETH per block (~50 free mints/day
    // sustainable; a 0.01 ETH spike takes ~2 days to fall back to 0). Hard
    // cap 0.08 ETH — the old priced minter's floor becomes this one's
    // ceiling; reaching it takes a sustained rush of 800 mints.
    uint256 constant FLOOR_PRICE = 0;
    uint256 constant MAX_PRICE = 0.08 ether;
    uint256 constant PRICE_BUMP = 0.0001 ether;
    uint256 constant DECAY_PER_BLOCK = 0.0000007 ether;

    function run() public {
        address hippyGhostsAddress = vm.envAddress("HIPPYGHOSTS_ADDRESS");
        uint256 startTokenId = vm.envUint("START_TOKEN_ID");
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast();

        HippyGhostsDynamicMinter minter = new HippyGhostsDynamicMinter(
            hippyGhostsAddress,
            startTokenId,
            FLOOR_PRICE,
            MAX_PRICE,
            PRICE_BUMP,
            DECAY_PER_BLOCK
        );
        minter.transferOwnership(adminAddress);

        vm.stopBroadcast();

        console.log("HippyGhostsDynamicMinter:", address(minter));
        console.log("startTokenId:", startTokenId);
        console.log("owner:", adminAddress);
        console.log("");
        console.log("Next step (must be done by the HippyGhosts owner):");
        console.log("  HippyGhosts.setAddresses(address(0), <minter address above>)");
    }
}
