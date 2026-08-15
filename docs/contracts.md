# HippyGhosts Contracts

## Overview

HippyGhosts is a collection of 9,999 NFTs on Ethereum mainnet. The contract system is modular: the NFT contract only handles storage, while minting logic, metadata rendering, and NFT swapping are separated into independent contracts.

```
HippyGhosts (ERC721)  <--  HippyGhostsMinter (mint logic)
     ^                          ^
HippyGhostsRenderer           SignatureVerification (library)
HippyGhostsSwapPool
```

### Deployed Addresses (Mainnet)

| Contract | Address |
|----------|---------|
| HippyGhosts | `0x2a5503280d66A47DE0754ddc73252CA9a4e93dcb` |
| HippyGhostsMinter | `0x6E4e27fE40cc66484Cf386535900fbE34899D3e8` |
| HippyGhostsRenderer | `0x856bd414d7C4718f844795b30510AF2f5FEe2Ee1` |
| HippyGhostsSwapPool | `0x454e030F23A5587B4a96fBaE663e59389Eb5f460` |

---

## Contract Architecture

### HippyGhosts.sol — NFT Token

The main ERC721 contract. Uses Solmate's gas-optimized ERC721 implementation.

- **`mintController`**: Only this address can call `mint()`. The NFT contract itself contains no minting logic (pricing, phases, allowlists). All of that is delegated to an external Minter contract. The controller can be updated via `setAddresses()` without redeploying the NFT contract.
- **`renderer`**: Delegates `tokenURI()` to an external Renderer contract. Can also be swapped.
- **`mint(address to, uint256 tokenId)`**: Validates caller is `mintController` and tokenId is in [1, 9999], then calls `_safeMint`.
- **`royaltyInfo()`**: ERC2981 royalty standard, returns 5% royalty to the contract address. Owner withdraws via `withdraw()`.
- **`receive()`**: Contract can receive ETH (royalty income).

### HippyGhostsMinter.sol — Minting Logic

The core contract managing all minting rules across three phases.

#### Token ID Allocation

```
[   1, 180 ] -> Phase 1: Team Mint    (180 tokens)
[ 181,1500 ] -> Phase 2: Private Mint (1,320 tokens)
[1501,9999 ] -> Phase 3: Public Mint  (8,499 tokens)
```

#### Phase 1: Team Mint — `ownerMint()`

- Owner-only, can specify arbitrary tokenIds (up to 1500) and target addresses.
- Capped at `MAX_OWNER_MINT_COUNT = 300` total mints.
- Used for team reserves and airdrops.

#### Phase 2: Private Mint — `mintWithSignature()`

Allowlist minting using ECDSA signature verification (not Merkle tree):

```
User -> Frontend -> Backend API (signs with private key) -> Returns signature -> Frontend calls contract -> Contract verifies signature
```

1. Validates ETH sent matches `valueInWei` in signature.
2. Validates `mintKey` has not been used (each key is one-time use).
3. Verifies signature: `keccak256(abi.encodePacked(msg.sender, numberOfTokens, valueInWei, mintKey, this))` must recover to `verificationAddress`.
4. Marks mintKey as claimed.
5. Minting loop uses low-level `call` instead of direct invocation — if a tokenId is already taken by `ownerMint`, it automatically skips to the next ID. This resolves the conflict of Team Mint and Private Mint sharing the [1-1500] range.

Price: 0.04 ETH per token. Max 10 per transaction.

#### Phase 3: Public Mint — `mint()`

Dynamic pricing with epoch-based release:

- **Epoch**: Every 40,000 blocks (~1 week), 300 new tokens are released.
- **Price decay**: `price = 0.24 ETH - (currentEpoch - tokenEpoch) * 0.04 ETH`, minimum 0.08 ETH.
- Uses Solidity 0.8 arithmetic underflow as a natural require — if the user doesn't send enough ETH, subtraction reverts automatically.
- Excess ETH is refunded after minting.
- Max 10 per transaction.

Price examples (for a token from epoch 1):
| Purchased in | Price |
|-------------|-------|
| Epoch 1 | 0.24 ETH |
| Epoch 2 | 0.20 ETH |
| Epoch 3 | 0.16 ETH |
| Epoch 4 | 0.12 ETH |
| Epoch 5+ | 0.08 ETH (floor) |

### SignatureVerification.sol — Signature Library

Standard ECDSA verification using OpenZeppelin's library:

```
keccak256(data) -> toEthSignedMessageHash() -> recover(signature) == verificationAddress
```

### HippyGhostsRenderer.sol — Metadata

Simple `baseURI + tokenId` concatenation. The `MERKLE_ROOT` is an on-chain commitment of all 9,999 ghost image hashes, proving image content was determined before minting (fairness proof).

### HippyGhostsSwapPool.sol — NFT Swap

Atomic swaps leveraging ERC721's `safeTransferFrom` callback:

- User calls `safeTransferFrom(me, SwapPool, myTokenId, swapData)`.
- Pool's `onERC721Received` decodes data: if it contains a `swap(uint256)` operation and a target tokenId, the pool transfers the requested token back to the user in the same transaction.
- No data = simple deposit into pool.
- Gnosis Safe has `setApprovalForAll` for administrative withdrawal.

---

## Development Toolchain

The project uses a **Foundry + Hardhat hybrid** setup (circa 2022):

- **Foundry (forge)**: Compilation and testing (Solidity-native tests)
- **Hardhat + hardhat-deploy**: Deployment scripts (JavaScript) and Etherscan verification

### Build

```bash
forge build
```

### Test

```bash
forge test
forge test -vvvv          # verbose with traces
forge test --gas-report   # with gas reporting
```

### Dependencies

Dual dependency management:

- **git submodules** (for Foundry): `lib/forge-std`, `lib/solmate`
- **npm/yarn** (for Hardhat): `@openzeppelin/contracts`, `ethers`, etc.
- **`remappings.txt`** bridges npm packages for Foundry:
  ```
  @openzeppelin/=node_modules/@openzeppelin/
  @rari-capital/=node_modules/@rari-capital/
  ```

### Configuration

**`foundry.toml`**: Source, test, output directories and gas reporting.

**`hardhat.config.js`**: Solidity 0.8.11, optimizer enabled (200 runs), network configs for hardhat/rinkeby/mainnet, named accounts for deployer/verificationAddress/gnosisSafe.

---

## Test Coverage

5 test files in `test/`, all written in Solidity using `forge-std/Test.sol`:

| Test File | What It Covers |
|-----------|---------------|
| `PrivateMint.t.sol` | Owner mint, signature mint, tokenId auto-skip when ID is taken |
| `PublicMintOpen.t.sol` | Epoch release, price decay across epochs, full supply depletion |
| `PublicMintClosed.t.sol` | Pre-sale revert (start block not set / not reached) |
| `Renderer.t.sol` | tokenURI generation, baseURI change, renderer swap |
| `SwapPool.t.sol` | Simple transfer, Gnosis Safe withdrawal, atomic swap, swap failure |

Key test techniques:
- `vm.sign()` to simulate backend signature generation
- `vm.roll()` to advance block numbers for epoch testing
- `vm.prank()` / `hoax()` to impersonate users
- `vm.deal()` to fund test accounts
- `vm.expectRevert()` for failure case assertions

---

## Deployment

### Deploy Scripts (`deploy/`)

Executed in order via `hardhat-deploy`:

**`1.HippyGhosts.js`** (tag: `nft`)
Deploys three contracts in dependency order:
1. `HippyGhosts` (no args)
2. `HippyGhostsRenderer` (hippyGhosts address, IPFS baseURI)
3. `HippyGhostsMinter` (hippyGhosts address, whitelistVerificationAddress)

**`2.SetAddresses.js`** (tag: `connect`)
Calls `hippyGhosts.setAddresses(renderer, minter)` to wire contracts together. Only runs if both addresses are zero (prevents double-execution).

**`3.SwapPool.js`** (tag: `swappool`)
Deploys `HippyGhostsSwapPool` with hippyGhosts address and Gnosis Safe address.

### Deploy Commands

```bash
# Deploy all
npx hardhat deploy --network mainnet

# Deploy specific tag
npx hardhat deploy --network mainnet --tags swappool

# Verify on Etherscan
npx hardhat verify --network mainnet <address> <constructor args...>
```

### Deployment Artifacts

Saved in `deployments/<network>/` as JSON files containing addresses, ABIs, and constructor arguments.

### Post-Deploy Manual Steps

- `setPublicMintStartBlock(blockNumber)` — manually called to open public sale at a chosen time.

### Switching to a New Minter (Free Mint and Beyond)

`HippyGhosts.mintController` can be repointed at any time by the contract owner
via `setAddresses`, so the minting mechanism can change without touching
`HippyGhosts` itself. For the ownership model this depends on, why the deploy
must be split into two separate transactions on mainnet, and the exact runbook,
see **[mainnet-deploy-runbook.md](./mainnet-deploy-runbook.md)**.

---

## Modernization Notes

This project was built in 2022. Below is a comparison with current best practices (2025+) for reference if the contracts or toolchain are ever updated.

### Foundry Now Handles Everything

The biggest change: **Foundry can now handle the full lifecycle** without Hardhat.

| Aspect | This Project (2022) | Modern Approach |
|--------|-------------------|-----------------|
| Compilation | `forge build` | `forge build` |
| Testing | `forge test` | `forge test` + fuzz + invariant |
| Deployment | `hardhat deploy` (JS) | **`forge script`** (Solidity) |
| Verification | `hardhat verify` | `forge script --verify` (one step) |
| Local node | Hardhat Network | **`anvil`** |
| Chain interaction | ethers.js | **`cast`** CLI |
| Dependencies | git submodule + npm | **Soldeer** (or still submodules) |
| Remappings | Manual `remappings.txt` | Auto-managed |
| Testnet | Rinkeby (shut down) | **Sepolia** / Holesky |

### Modern Deploy Script Example

```solidity
// script/Deploy.s.sol
contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        HippyGhosts hippyGhosts = new HippyGhosts();
        HippyGhostsRenderer renderer = new HippyGhostsRenderer(
            address(hippyGhosts), "ipfs://xxx/"
        );
        HippyGhostsMinter minter = new HippyGhostsMinter(
            address(hippyGhosts), verificationAddress
        );
        hippyGhosts.setAddresses(address(renderer), address(minter));

        vm.stopBroadcast();
    }
}
```

```bash
# Simulate locally
forge script script/Deploy.s.sol

# Deploy to testnet with verification
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify

# Deploy to mainnet
forge script script/Deploy.s.sol --rpc-url mainnet --broadcast --verify --gas-estimate-multiplier 120

# Resume a failed deployment
forge script script/Deploy.s.sol --rpc-url mainnet --resume

# Multi-chain deployment
forge script script/Deploy.s.sol --slow --multi --broadcast --verify
```

### Soldeer Package Manager

Foundry's built-in package manager, replacing git submodules + npm:

```bash
forge soldeer init
forge soldeer install forge-std~1.9.2 --git https://github.com/foundry-rs/forge-std.git
forge soldeer install @openzeppelin-contracts~5.0.0
# Remappings are auto-managed
```

### Enhanced Testing

Modern Foundry supports fuzz and invariant testing out of the box:

```solidity
// Fuzz test — forge auto-generates random inputs
function testMint(uint256 numberOfTokens) public {
    numberOfTokens = bound(numberOfTokens, 1, 10);
    mintController.mint{value: 0.24 ether * numberOfTokens}(numberOfTokens);
    assertEq(hippyGhosts.balanceOf(EOA1), numberOfTokens);
}

// Invariant test — system property that must always hold
function invariant_totalSupplyNeverExceedsMax() public {
    assertLe(hippyGhosts.totalSupply(), 9999);
}
```

### Library Updates

- **OpenZeppelin**: v4.6.0 -> v5.x (Solidity >=0.8.20, `Ownable` now requires `initialOwner` in constructor)
- **Solmate**: Succeeded by **Solady** (even more gas-optimized)
