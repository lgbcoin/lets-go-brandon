export default async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  await deploy('Timestamp', {
    from: deployer,
    args: [],
    log: true
  })
}
export const tags = ['Timestamp']
