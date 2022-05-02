# HippyGhosts contracts

## Forge

### Install

```bash
curl -L https://foundry.paradigm.xyz | bash
# This will download foundryup. Then install Foundry by running:
foundryup
```

### Compile

```bash
forge build
```

### Test

Run test with `-vv` to print logs

```bash
forge test -vv
```

### Gas report

Run testMintGasReport to mint 1 token and generate gas report for minting

```bash
forge test --match-test testMintGasReport --gas-report
```

### Install

```bash
forge install openzeppelin/openzeppelin-contracts@v4.4.2
forge install brockelmore/forge-std
```

### Deploy with Hardhat

Since remappings doesn't work with hardhat, I need change the dependencies structure to hardhat style and config remappings for Forge

```bash
yarn hardhat deploy --network rinkeby --tags nft
```

#### verify contracts

```bash
yarn hardhat etherscan-verify --network rinkeby
```
