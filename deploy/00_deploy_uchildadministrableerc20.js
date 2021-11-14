export default async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  await deploy('UChildAdministrableERC20', {
    from: deployer,
    proxy: true,
    log: true
  })
}
export const tags = ['UChildAdministrableERC20']
