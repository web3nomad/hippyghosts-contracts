module.exports = async ({
  getNamedAccounts, deployments, getChainId,
}) => {
  const chainId = +(await getChainId());
  const { deploy } = deployments;
  const {
    deployer,
    gnosisSafe,
  } = await getNamedAccounts();

  const HippyGhosts = await deployments.get('HippyGhosts');

  await deploy('HippyGhostsSwapPool', {
    from: deployer,
    log: true,
    args: [
      HippyGhosts.address,
      gnosisSafe,
    ],
  });

}

module.exports.tags = ['swappool'];
