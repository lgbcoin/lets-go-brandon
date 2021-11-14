import { constants } from '../src/utils/Constants'
import { RecordList } from '../src/utils/RecordList'
import { ethers } from 'hardhat'

export default async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments
  const { deployer, first, second, third, fourth } = await getNamedAccounts()
  const shield = first
  const monetaryPolicyReserve = second
  const executiveTeamBudget = third
  const workingCapital = fourth

  const aBDKMathContract = await deployments.get('ABDKMathQuad')
  const aBDKMath = await ethers.getContractAt('ABDKMathQuad', aBDKMathContract.address)

  const timestampContract = await deployments.get('Timestamp')
  const timestamp = await ethers.getContractAt('Timestamp', timestampContract.address)

  const uChildERC20ProxyContract = await deployments.get('UChildAdministrableERC20_Proxy')
  const SafeERC20 = await ethers.getContractFactory('@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:SafeERC20')
  const safeERC20 = SafeERC20.attach(uChildERC20ProxyContract.address)

  const rewardCalculatorContract = await deployments.get('RewardCalculator')
  const rewardCalculator = await ethers.getContractAt('RewardCalculator', rewardCalculatorContract.address)

  const interestRate = await aBDKMath.div(
    await aBDKMath.fromInt(constants.INTEREST.NUMERATOR),
    await aBDKMath.fromInt(constants.INTEREST.DENOMINATOR)
  )
  const multiplier = await aBDKMath.fromInt(constants.MULTIPLIER)
  const recordList = new RecordList([shield, monetaryPolicyReserve, executiveTeamBudget, workingCapital], [10, 10, 30, 50])

  await deploy('YieldFarming', {
    from: deployer,
    args: [
      timestamp.address,
      safeERC20.address,
      rewardCalculator.address,
      constants.TOKEN.NAME,
      constants.TOKEN.SYMBOL,
      interestRate,
      multiplier,
      constants.LOCK_TIME,
      recordList.addresses(),
      recordList.sharesList()
    ],
    log: true
  })
}
export const tags = ['YieldFarming']
module.exports.dependencies = ['ABDKMathQuad', 'Timestamp', 'RewardCalculator', 'UChildAdministrableERC20'] // this ensures the ABDKMathQuad script above is executed shield, so `deployments.get('ABDKMathQuad')` succeeds
