module.exports = async ({
  getNamedAccounts, deployments, getChainId, ethers
}) => {
  const chainId = +(await getChainId());
  const {
    deployer,
    whitelistVerificationAddress,
  } = await getNamedAccounts();

  const [
    HippyGhosts,
    HippyGhostsRenderer,
    HippyGhostsMinter,
  ] = await Promise.all([
    deployments.get('HippyGhosts'),
    deployments.get('HippyGhostsRenderer'),
    deployments.get('HippyGhostsMinter'),
  ]);

  const signer = await ethers.getSigner(deployer);
  const hippyGhosts = new ethers.Contract(HippyGhosts.address, HippyGhosts.abi, signer);
  const [
    mintController,
    renderer,
  ] = await Promise.all([
    hippyGhosts.mintController(),
    hippyGhosts.renderer(),
  ]);

  if (
    mintController === '0x0000000000000000000000000000000000000000' &&
    renderer === '0x0000000000000000000000000000000000000000'
  ) {
    const tx = await hippyGhosts.setAddresses(
      HippyGhostsRenderer.address, HippyGhostsMinter.address, {
        gasPrice: 30000000000
      });
    console.log(`setAddresses ${HippyGhostsRenderer.address} ${HippyGhostsMinter.address}`);
    console.log(`tx: ${tx.hash}`);
    await tx.wait();
  }

  // const hippyGhostsMinter = new ethers.Contract(HippyGhostsMinter.address, HippyGhostsMinter.abi, signer);
  // await hippyGhostsMinter.setPublicMintStartBlock(14684334).then(tx => tx.wait());

}

module.exports.tags = ['connect'];
