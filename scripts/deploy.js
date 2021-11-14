import { rawDeploy, Timestamp, waffle, ethers, MULTIPLIER, RecordList } from './mainDeploy'
import { stringify } from 'flatted'
const fs = require('fs')

const deployMe = async (_multiplier) => {
  const LOCK_TIME = 24 * 60 * 60
  const INTEREST_NUMERATOR = 100
  const INTEREST_DENOMINATOR = 10000
  const INTEREST = { NUMERATOR: INTEREST_NUMERATOR, DENOMINATOR: INTEREST_DENOMINATOR }
  const TOKEN_NAME = "Let's Go Brandon"
  const TOKEN_SYMBOL = "LGBC"
  const TOKEN = { NAME: TOKEN_NAME, SYMBOL: TOKEN_SYMBOL }
  const SafeERC20 = await ethers.getContractFactory('@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:SafeERC20')
  const safeERC20 = SafeERC20.attach('0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174')
  const MULTIPLIER = _multiplier
  const constants = { MULTIPLIER, LOCK_TIME, INTEREST, TOKEN }
  const [first, second, third, fourth] = await ethers.getSigners()
  const payees = new RecordList([first.address, second.address, third.address, fourth.address], [10, 10, 30, 50])
  const timestamp = await waffle.deployContract(first, Timestamp)
  return await rawDeploy(timestamp, safeERC20, payees, [first, second, third, fourth], constants)
}

const main = async () => {
  const deploy = await deployMe(MULTIPLIER)
  const deployString = stringify(deploy)
  fs.writeFileSync('deploy.json', deployString)
  // const readDeployString = fs.readFileSync('deploy.json')
  // const readDeploy = parse(readDeployString)
  // expect(deploy.acceptedToken.address)
  //   .to.be.equal(readDeploy.acceptedToken.address)
  // expect(deploy.first.address)
  //   .to.be.equal(readDeploy.first.address)
  // expect(deploy.second.address)
  //   .to.be.equal(readDeploy.second.address)
  // expect(deploy.third.address)
  //   .to.be.equal(readDeploy.third.address)
  // expect(deploy.yieldFarming.address)
  //   .to.be.equal(readDeploy.yieldFarming.address)
  // expect(deploy.yieldFarmingToken.address)
  //   .to.be.equal(readDeploy.yieldFarmingToken.address)
  // expect(deploy.timestamp.address)
  //   .to.be.equal(readDeploy.timestamp.address)
  // expect(deploy.payees)
  //   .to.be.deep.equal(readDeploy.payees)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
