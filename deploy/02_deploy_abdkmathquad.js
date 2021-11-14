export default async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  await deploy('ABDKMathQuad', {
    from: deployer,
    args: [],
    log: true
  })
}
export const tags = ['ABDKMathQuad']
