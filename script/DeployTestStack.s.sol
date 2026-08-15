// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 * Deploys a fresh HippyGhosts + HippyGhostsRenderer pair for testnet use.
 *
 * There is nothing to migrate from a prior testnet: Rinkeby (the only network this
 * project was previously deployed to besides mainnet) has been shut down since
 * 2022, so every testnet deployment starts from zero. The old priced
 * HippyGhostsMinter is intentionally not deployed here — this stack exists only to
 * give DeployFreeMinter.s.sol something to attach to.
 */

import "forge-std/Script.sol";
import "../src/HippyGhosts.sol";
import "../src/HippyGhostsRenderer.sol";

contract DeployTestStackScript is Script {
    function run() public {
        vm.startBroadcast();

        HippyGhosts hippyGhosts = new HippyGhosts();
        HippyGhostsRenderer renderer = new HippyGhostsRenderer(
            address(hippyGhosts),
            "https://api.hippyghosts.io/~/storage/tokens/test/"
        );
        hippyGhosts.setAddresses(address(renderer), address(0));

        vm.stopBroadcast();

        console.log("HippyGhosts:", address(hippyGhosts));
        console.log("HippyGhostsRenderer:", address(renderer));
    }
}
