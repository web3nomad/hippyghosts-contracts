module.exports = async ({
  getNamedAccounts, deployments, getChainId,
}) => {
  const chainId = +(await getChainId());
  const { deploy } = deployments;
  const {
    deployer,
    whitelistVerificationAddress,
  } = await getNamedAccounts();

  // const baseURI = 'https://api.hippyghosts.io/~/storage/tokens/test/';
  const baseURI = 'ipfs://bafybeiglzxoeyxwt3psivtxd34kd6yiifbsovs23xumqpobluoxakbpkiu/';

  await deploy('HippyGhosts', {
    from: deployer,
    log: true,
    args: [],
  });

  const HippyGhosts = await deployments.get('HippyGhosts');

  await deploy('HippyGhostsRenderer', {
    from: deployer,
    log: true,
    args: [
      HippyGhosts.address,
      baseURI,
    ],
  });

  await deploy('HippyGhostsMinter', {
    from: deployer,
    log: true,
    args: [
      HippyGhosts.address,
      whitelistVerificationAddress,
    ],
  });

}

module.exports.tags = ['nft'];
