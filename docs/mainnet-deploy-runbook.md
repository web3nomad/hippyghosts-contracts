# Mainnet Free Mint Rollout — Runbook & Notes

This doc captures the operational knowledge from switching HippyGhosts to a free
mint: the ownership model (which confused everyone at least once — see below),
why the deploy has to be split into two steps, the security practices we settled
on, and the exact runbook for doing it. It's a living doc — update it as the
rollout actually happens, and again if the minter ever gets swapped a second time.

For contract architecture (what each contract does), see [contracts.md](./contracts.md).
This doc is about the *process* of changing which minter is live, not the contracts
themselves.

## The two addresses that matter, and why they're different

`HippyGhosts.sol` stores two separate address variables. Mixing them up is the
single easiest way to get confused about this whole rollout, so spelling it out
plainly:

- **`owner`** — who is allowed to call the two `onlyOwner` functions:
  `setAddresses(renderer_, mintController_)` and `withdraw()`. This is the "who
  holds the keys to the admin panel" address.
- **`mintController`** — which contract is currently allowed to call `mint(to,
  tokenId)`. This is "one of the settings on that admin panel" — a value the
  owner can change via `setAddresses`.

`owner` decides *who can change* `mintController`. They are not the same thing,
and changing one does not touch the other. `setAddresses` never touches `owner` —
changing `owner` uses a separate function, `transferOwnership` (standard
OpenZeppelin `Ownable`).

### Current mainnet state (verified on-chain, 2026-08-15)

```
HippyGhosts:      0x2a5503280d66A47DE0754ddc73252CA9a4e93dcb
  owner:           0xCA4F157682559551AC39b66be5766355DFE66EF9   (Gnosis Safe)
  mintController:  0x6E4e27fE40cc66484Cf386535900fbE34899D3e8   (old priced HippyGhostsMinter)
  renderer:        0x856bd414d7C4718f844795b30510AF2f5FEe2Ee1   (unchanged by this rollout)
  minted:          1500 / 9999  (tokenId 1–1500; 1501 confirmed NOT_MINTED)
```

`owner` was originally the deploying EOA (`0x03793EB77F02B730B1842AFC4f4F66B8305F16a3`,
same address for all four original contracts — see `deployments/mainnet/*.json`
`receipt.from`), and was manually transferred to the Gnosis Safe at some point
after launch via `transferOwnership`. That transfer is why `owner` is the Safe
today and not the original deployer.

## Why the deploy has to be two separate transactions

Deploying a new minter contract and connecting it to `HippyGhosts` are two
different operations with two different permission requirements:

1. **Deploy the new minter contract.** Permissionless — anyone with enough ETH
   for gas can do this. It confers no privilege on `HippyGhosts` at all.
2. **`HippyGhosts.setAddresses(0, newMinterAddress)`.** Restricted to `owner`.
   On mainnet, `owner` is a Gnosis Safe — a multisig contract with no single
   private key, so it cannot sign and broadcast a transaction the way an EOA
   can. Only the Safe's own UI (Contract Interaction → collect signer
   approvals → execute) can perform this call.

The first `HippyGhostsFreeMinter` deploy script bundled both steps into one
broadcast, which works fine on a testnet where the deploying EOA happens to
also be the contract's `owner` (true on every fresh testnet deployment, false
on mainnet). This was caught on review before ever touching mainnet — see the
"Add HippyGhostsFreeMinter" and "Fix mainnet-unsafe deploy assumptions" commits.
`script/DeployFreeMinter.s.sol` now only does step 1 (deploy + hand the new
minter's own ownership to `ADMIN_ADDRESS`); step 2 is always a separate,
manual Safe transaction.

## `HippyGhostsFreeMinter`'s own ownership is a third, unrelated thing

`HippyGhostsFreeMinter` is itself `Ownable` — its `owner` controls
`setMintOpen`/`setMaxPerWallet` on *that* contract, and starts out as whichever
EOA deploys it (standard `Ownable` behavior: `owner = msg.sender` at
construction). Left alone, that means a throwaway deploy key would end up
controlling the mint toggle — not what we want on mainnet.

`script/DeployFreeMinter.s.sol` requires an `ADMIN_ADDRESS` env var and calls
`minter.transferOwnership(ADMIN_ADDRESS)` in the same broadcast as the deploy,
so by the time the deploy transaction is mined, the new minter's `owner` is
already `ADMIN_ADDRESS` (the Safe, on mainnet) — never the deploying EOA. This
is unrelated to and independent of `HippyGhosts.owner`, which is never touched
by this script at all.

Net effect: after the two-step process completes, `HippyGhosts.owner` is still
the Safe (never moved), and the new `HippyGhostsFreeMinter.owner` is also the
Safe (handed off automatically during deploy). There is no window where either
contract's admin control sits on an EOA.

## Deployer key: reused on purpose, by explicit choice

The original mainnet deployer (`0x03793EB77F02B730B1842AFC4f4F66B8305F16a3`,
private key held by the project owner) is being reused for this deploy, at the
project owner's explicit preference. This is **not required** — deploying a
contract confers no ongoing privilege on the deployer once ownership is handed
off in the same transaction, so any funded EOA would work identically. A fresh
throwaway key would have been marginally safer (less reuse of an
already-used-elsewhere key), but reusing the known deployer was a deliberate,
informed choice, not an oversight.

## Security practice: private keys never pass through chat or shell history

Two separate deploy wallets were set up this way, and it's the pattern to
repeat for any future one:

- **Sepolia dry-run wallet**: freshly generated with `cast wallet new`, its
  password stored in a local file (`~/.foundry/keystores/hippyghosts-sepolia-deployer.password`,
  `chmod 600`) since it holds no mainnet-relevant funds or permissions.
- **Mainnet deployer**: imported by the project owner directly, via
  `cast wallet import mainnet-deployer --interactive`, entering the existing
  private key and a password known only to them. The agent never saw the
  private key or the password — only the resulting keystore file (encrypted at
  rest) and the address it holds (cross-checked against the known mainnet
  deployer address, which is public information).

Because forge/cast keystore commands need an interactive password prompt and
this session's tool doesn't have a real terminal (`Device not configured`
errors on any command needing hidden input), **the actual signing step for the
mainnet deploy has to be run by the project owner directly in their own
terminal**, pasting the exact command handed to them and typing the keystore
password themselves. Verification of the result (checking addresses, contract
state, etc.) happens afterward via read-only on-chain calls, which need no
password.

## Runbook: switching mainnet to `HippyGhostsFreeMinter`

Preconditions (all satisfied as of 2026-08-15):
- `HippyGhostsFreeMinter.sol` written, tested (34/34 passing:
  `forge test`), and verified end-to-end on Sepolia with real transactions
  (deploy, ownership handoff, mint-closed revert, successful mint, per-wallet
  limit revert, and a full minter-to-minter handoff rehearsal).
- `0x03793EB77F02B730B1842AFC4f4F66B8305F16a3` funded with mainnet ETH for gas.
- Its private key imported into a local encrypted keystore named
  `mainnet-deployer`, address cross-checked against the value above.

Steps:

1. **Re-verify `START_TOKEN_ID` right before deploying** — don't trust a
   number from an earlier conversation turn; someone could have minted between
   then and now. It should be `(highest currently-minted tokenId) + 1`:
   ```bash
   cast call 0x2a5503280d66A47DE0754ddc73252CA9a4e93dcb \
     "mintController()(address)" --rpc-url <mainnet RPC>
   # then binary-search or scan ownerOf() near the expected boundary to confirm
   ```

2. **Deploy `HippyGhostsFreeMinter`, handing ownership to the Safe** (run this
   directly in a real terminal — it needs the keystore password interactively):
   ```bash
   HIPPYGHOSTS_ADDRESS=0x2a5503280d66A47DE0754ddc73252CA9a4e93dcb \
   START_TOKEN_ID=<confirmed above> \
   ADMIN_ADDRESS=0xCA4F157682559551AC39b66be5766355DFE66EF9 \
     forge script script/DeployFreeMinter.s.sol \
     --rpc-url <mainnet RPC> \
     --account mainnet-deployer \
     --broadcast
   ```
   Note the deployed `HippyGhostsFreeMinter` address printed at the end.

3. **Independently verify before touching the Safe** — read state from an RPC
   provider other than the one used to deploy, to rule out a stale/lying node:
   ```bash
   cast call <new minter address> "owner()(address)" --rpc-url <a different RPC>
   # must equal 0xCA4F157682559551AC39b66be5766355DFE66EF9 (the Safe), not the deployer
   ```

4. **Via the Safe's own UI** (Contract Interaction, not this session): call
   ```
   HippyGhosts.setAddresses(0x0000000000000000000000000000000000000000, <new minter address>)
   ```
   The zero address for `renderer_` is deliberate — `setAddresses` skips
   updating a field when passed `address(0)`, so this only changes
   `mintController` and leaves `renderer` alone.

5. **Verify the switch landed**, again via an independent RPC:
   ```bash
   cast call 0x2a5503280d66A47DE0754ddc73252CA9a4e93dcb "mintController()(address)" --rpc-url <RPC>
   ```

6. **Update the off-chain side** — the on-chain switch alone does not make
   minting possible through the website:
   - Update the `chainconfig` table (`chain_id=1`, `name='MintController'`,
     `value=<new minter address>`) in the app's database — `/api/chainconfig/1`
     serves this to the frontend.
   - Add the new minter's address + ABI to `lib/web3/contracts.ts` in
     `hippyghosts-app`.
   - Build an actual `/mint` page wired to `mint(numberOfTokens)`,
     `mintOpen()`, `maxPerWallet()`, `mintedCount(address)` — none of this
     exists yet. Until it does, minting is only possible by calling the
     contract directly (Etherscan's Write Contract tab, `cast send`, etc.),
     not through hippyghosts.io.
   - The old minter's signature-based mint API routes
     (`/api/mint/sign-mint-key` etc.) become dead code after the switch — not
     urgent to remove, just no longer meaningful.

7. **Owner then calls `setMintOpen(true)`** (via the Safe, same
   Contract-Interaction flow as step 4) whenever the mint should actually go
   live — this is a separate, reversible action from connecting the minter.

## Reversibility

Switching back to a priced model later needs no changes to `HippyGhosts` or
`HippyGhostsFreeMinter` — deploy a new minter contract with
`startTokenId_ = <the retiring minter's current nextTokenId()>`, then repeat
steps 2–6 above pointing at the new contract. This exact handoff (one minter's
`nextTokenId()` feeding the next minter's constructor, with no collision or
gap) was verified with real transactions on Sepolia.

## Sepolia deployment records (for reference, not mainnet)

These addresses only exist on Sepolia (chain 11155111) and cost nothing to
throw away or ignore — kept here only as a trace of what was tested and how,
in case any of it needs re-running:

| Contract | Address | Notes |
|---|---|---|
| HippyGhosts (test) | `0x7Da3a8B8c76Ca307FCda8cd071c7828E770732E6` | fresh deploy, unrelated to mainnet |
| HippyGhostsRenderer (test) | `0x45eA432fde993B01CdBbeC554CeB2f30060e3374` | |
| HippyGhostsFreeMinter (test, superseded) | `0x8963Ac6167abD0f10b56cBEb58ff8Df1008f4f72` | first deploy; owner was the test deployer itself |
| HippyGhostsFreeMinter (test, handoff rehearsal) | `0xc424f0d63362ed0a239abda8aa11b53e1052c0e0` | owner transferred to a Safe stand-in (`0x…dEaD`), then connected via a separate `setAddresses` call — this is the exact two-step flow the mainnet runbook above follows |
| Sepolia dry-run deployer | `0xD7bFC3b9cc7184ea77B58F77314cdE7aEB8Fe532` | encrypted keystore `hippyghosts-sepolia-deployer`, password stored in plaintext file (fine — no mainnet-relevant value at risk) |

Full transaction records for these are in `broadcast/*/11155111/`.
