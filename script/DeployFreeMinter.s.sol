// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 * Deploys HippyGhostsFreeMinter and hands its ownership to ADMIN_ADDRESS.
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
 * setMintOpen/setMaxPerWallet — on mainnet that must be the Gnosis Safe, not
 * a throwaway deployer key.
 *
 * Reads HIPPYGHOSTS_ADDRESS, START_TOKEN_ID, and ADMIN_ADDRESS from the
 * environment so the same script runs unmodified against any network — only
 * --rpc-url/--account (or --private-key) change between a testnet run and
 * the eventual mainnet run.
 */

import "forge-std/Script.sol";
import "../src/HippyGhostsFreeMinter.sol";

contract DeployFreeMinterScript is Script {
    function run() public {
        address hippyGhostsAddress = vm.envAddress("HIPPYGHOSTS_ADDRESS");
        uint256 startTokenId = vm.envUint("START_TOKEN_ID");
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast();

        HippyGhostsFreeMinter minter = new HippyGhostsFreeMinter(
            hippyGhostsAddress, startTokenId
        );
        minter.transferOwnership(adminAddress);

        vm.stopBroadcast();

        console.log("HippyGhostsFreeMinter:", address(minter));
        console.log("startTokenId:", startTokenId);
        console.log("owner:", adminAddress);
        console.log("");
        console.log("Next step (must be done by the HippyGhosts owner):");
        console.log("  HippyGhosts.setAddresses(address(0), <minter address above>)");
    }
}
