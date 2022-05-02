module.exports = async ({
  getNamedAccounts, deployments, getChainId,
}) => {
  const chainId = +(await getChainId());
  const { deploy } = deployments;
  const {
    deployer,
    whitelistVerificationAddress,
  } = await getNamedAccounts();

  let baseURI = 'https://hippyghosts.io/~/storage/tokens/test/';

  await deploy('HippyGhosts', {
    from: deployer,
    log: true,
    args: [
      // baseURI,
      // whitelistVerificationAddress,
    ],
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
