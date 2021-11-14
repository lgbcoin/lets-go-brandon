// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./TokenTimeLock.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./YieldFarmingToken.sol";
import "./RewardCalculator.sol";
import "./PaymentSplitter.sol";
import "./Timestamp.sol";

contract YieldFarming is PaymentSplitter {
    using SafeERC20 for YieldFarmingToken;
    using SafeERC20 for IERC20;

    event YieldFarmingTokenBurn(address burner, uint amount);
    event YieldFarmingTokenRelease(address releaser, uint amount);

    Timestamp private timestamp;
    RewardCalculator immutable private rewardCalculator;
    YieldFarmingToken immutable public yieldFarmingToken;
    IERC20 immutable private acceptedToken;
    bytes16 private interestRate;
    bytes16 private multiplier;
    uint private lockTime;
    uint private tokenomicsTimestamp;

    mapping(address => TokenTimeLock[]) private tokenTimeLocks;

    constructor(
        Timestamp _timestamp,
        IERC20 _acceptedToken,
        RewardCalculator _rewardCalculator,
        string memory _tokenName,
        string memory _tokenSymbol,
        bytes16 _interestRate,
        bytes16 _multiplier,
        uint _lockTime,
        address[] memory _payees,
        uint256[] memory _shares
    ) PaymentSplitter(_acceptedToken, _payees, _shares) {
        timestamp = _timestamp;
        updateTokenomics(_interestRate, _multiplier, _lockTime);
        yieldFarmingToken = new YieldFarmingToken(_tokenName, _tokenSymbol);
        rewardCalculator = _rewardCalculator;
        acceptedToken = _acceptedToken;
    }

    function updateTokenomics(bytes16 _newInterestRate, bytes16 _newMultiplier, uint _newLockTime) public onlyOwner{
        interestRate = _newInterestRate;
        multiplier = _newMultiplier;
        lockTime = _newLockTime;
        tokenomicsTimestamp = timestamp.getTimestamp();
    }

    function deposit(uint amount) public {
        address depositor = _msgSender();
        super.deposit(depositor, amount);
        uint timeStamp = timestamp.getTimestamp();
        TokenTimeLock tokenTimeLock = new TokenTimeLock(timestamp, yieldFarmingToken, depositor, timeStamp + lockTime);
        tokenTimeLocks[depositor].push(tokenTimeLock);
        yieldFarmingToken.mint(
            address(tokenTimeLock),
            rewardCalculator.calculateQuantity(amount, multiplier, interestRate, timeStamp - tokenomicsTimestamp)
        );
    }

    function burn(uint amount) public {
        address burner = _msgSender();
        // // Original implementation:
        // yieldFarmingToken.safeTransferFrom(burner, address(this), amount);
        // yieldFarmingToken.safeIncreaseAllowance(address(this), amount);
        // yieldFarmingToken.burn(amount);
        
        // Optimized implementation:
        yieldFarmingToken.burnFrom(burner, amount);
        
        emit YieldFarmingTokenBurn(burner, amount);
    }

    function getMyTokenTimeLock(uint tokenTimelockIndex) public view returns (TokenTimeLock) {
        address me = _msgSender();
        require(tokenTimelockIndex < tokenTimeLocks[me].length, "Index out of bounds!");
        return tokenTimeLocks[me][tokenTimelockIndex];
    }

    function getMyTokenTimeLocks() public view returns (TokenTimeLock[] memory) {
        return tokenTimeLocks[_msgSender()];
    }

    function releaseTokens(uint tokenTimelockIndex) public {
        address releaser = _msgSender();
        require(tokenTimelockIndex < tokenTimeLocks[releaser].length, "Index out of bounds!");
        TokenTimeLock tokenTimelock = takeTokenTimeLock(releaser, tokenTimelockIndex);
        uint amount = yieldFarmingToken.balanceOf(address(tokenTimelock));
        tokenTimelock.release();
        emit YieldFarmingTokenRelease(releaser, amount);
    }

    function takeTokenTimeLock(address sender, uint tokenTimelockIndex) internal returns (TokenTimeLock) {
        TokenTimeLock element = tokenTimeLocks[sender][tokenTimelockIndex];
        uint lengthM1 = tokenTimeLocks[sender].length - 1;
        tokenTimeLocks[sender][tokenTimelockIndex] = tokenTimeLocks[sender][lengthM1];
        delete tokenTimeLocks[sender][lengthM1];
        tokenTimeLocks[sender].pop;
        return element;
    }
}