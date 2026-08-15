// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 * Deploys HippyGhostsFreeMinter and points HippyGhosts.mintController at it.
 *
 * Reads HIPPYGHOSTS_ADDRESS and START_TOKEN_ID from the environment so the same
 * script runs unmodified against any network — only --rpc-url/--account (or
 * --private-key) change between a testnet run and the eventual mainnet run.
 *
 * The caller must be the current owner of HIPPYGHOSTS_ADDRESS, since
 * setAddresses() is onlyOwner.
 */

import "forge-std/Script.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsFreeMinter.sol";

contract DeployFreeMinterScript is Script {
    function run() public {
        address hippyGhostsAddress = vm.envAddress("HIPPYGHOSTS_ADDRESS");
        uint256 startTokenId = vm.envUint("START_TOKEN_ID");

        vm.startBroadcast();

        HippyGhostsFreeMinter minter = new HippyGhostsFreeMinter(
            hippyGhostsAddress, startTokenId
        );
        HippyGhosts(payable(hippyGhostsAddress)).setAddresses(address(0), address(minter));

        vm.stopBroadcast();

        console.log("HippyGhostsFreeMinter:", address(minter));
        console.log("startTokenId:", startTokenId);
    }
}
