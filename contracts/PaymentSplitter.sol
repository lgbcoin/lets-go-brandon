// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Timestamp.sol";

/**
 * @title PaymentSplitter
 * @dev This contract allows to split Token payments among a group of accounts. The sender does not need to be aware
 * that the Tokens will be split in this way, since it is handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares. Of all the Tokens that this contract receives, each account will then be able to claim
 * an amount proportional to the percentage of total shares they were assigned.
 *
 * `PaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
 * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
 * function.
 */
struct Record {
    uint256 shares;
    uint256 released;
}
struct RecordArchive {
    mapping(address => Record) records;
    address[] addresses;
}
contract PaymentSplitter is Context, Ownable {
    using SafeERC20 for IERC20;
    event PayeeAdded(address account, uint256 shares);
    event PayeeUpdated(address account, int256 shares);
    event PayeeRemoved(address account);
    event PaymentReleased(address to, uint256 amount);
    event AcceptedTokenDeposit(address depositor, uint amount);
    event SharesTransferred(address transferrer, address to, uint sharesAmount);

    IERC20 immutable private acceptedToken;
    RecordArchive private payeeArchive;

    /**
     * @dev Creates an instance of `PaymentSplitter` where each account in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     */
    constructor (IERC20 _acceptedToken, address[] memory _payees, uint256[] memory _shares) {
        // solhint-disable-next-line max-line-length, reason-string
        require(_payees.length == _shares.length, "PaymentSplitter: payees and shares length mismatch");
        require(_payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < _payees.length; i++) {
            addPayee(_payees[i], _shares[i]);
        }
        acceptedToken = _acceptedToken;
    }

    /**
     * @dev The Tokens received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Tokens without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Tokens.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    function deposit(address depositor, uint amount) internal {
        acceptedToken.safeTransferFrom(depositor, address(this), amount);
        emit AcceptedTokenDeposit(depositor, amount);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return shares(address(this));
    }

    /**
     * @dev Getter for the total amount of Tokens already released.
     */
    function totalReleased() public view returns (uint256) {
        return released(address(this));
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function record(address account) public view returns (Record memory) {
        return payeeArchive.records[account];
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return record(account).shares;
    }

    /**
     * @dev Getter for the amount of Tokens already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return record(account).released;
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (address) {
        return payeeArchive.addresses[index];
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of tokens they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address account) public virtual {
        // solhint-disable-next-line reason-string
        require(isPayee(account), "PaymentSplitter: account is not a payee");

        uint256 totalReceived = acceptedToken.balanceOf(address(this))  + totalReleased();
        uint256 payment = totalReceived * shares(account) / totalShares() - released(account);

        // solhint-disable-next-line reason-string
        require(payment != 0, "PaymentSplitter: account is not due payment");

        payeeArchive.records[account].released += payment;
        payeeArchive.records[address(this)].released += payment;

        acceptedToken.safeTransfer(account, payment);
        emit PaymentReleased(account, payment);
    }

    function isPayee(address account) public view returns (bool){
        return (shares(account) > 0);
    }

    /**
     * @dev Transfer shares.
     * @param to The address of the shares destinatary to transfer to.
     * @param sharesAmount The number of shares to be transfered by the transferrer.
     */
    function transferShares(address to, uint256 sharesAmount) public {
        address transferrer = _msgSender();
        // solhint-disable-next-line reason-string
        require(isPayee(transferrer), "PaymentSplitter: transferrer not a payee");
        // solhint-disable-next-line reason-string
        require(shares(transferrer) >= sharesAmount, "PaymentSplitter: not enough shares balance");
        // Deduct from transferrer shares balance
        _updatePayee(transferrer, shares(transferrer)-sharesAmount);
        if(isPayee(to)){
            _updatePayee(to, shares(to)+sharesAmount);
        }else{
            _addPayee(to, sharesAmount);
        }
        emit SharesTransferred(transferrer, to, sharesAmount);
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param _shares The number of shares owned by the payee.
     */
    function _updatePayee(address account, uint256 _shares) private {
        require(isPayee(account), "PaymentSplitter: not a payee");
        if (_shares == 0) {
            _removePayee(account);
            return;
        }
        // solhint-disable-next-line reason-string
        require(shares(account) != _shares, "PaymentSplitter: account already has that many shares");
        int256 delta = int256(_shares) - int256(shares(account));
        payeeArchive.records[account].shares = _shares;
        payeeArchive.records[address(this)].shares = uint256(int256(payeeArchive.records[address(this)].shares) + delta);
        emit PayeeUpdated(account, delta);
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param _shares The number of shares owned by the payee.
     */
    function _addPayee(address account, uint256 _shares) private {
        // solhint-disable-next-line reason-string
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(_shares > 0, "PaymentSplitter: shares are 0");
        // solhint-disable-next-line reason-string
        require(!isPayee(account), "PaymentSplitter: account is already payee");

        payeeArchive.addresses.push(account);
        payeeArchive.records[account].shares = _shares;
        payeeArchive.records[address(this)].shares += _shares;
        emit PayeeAdded(account, _shares);
    }

    /**
     * @dev Remove a payee from the contract.
     * @param account The address of the payee to remove.
     */
    function _removePayee(address account) private {
        // solhint-disable-next-line reason-string
        require(payeeArchive.addresses.length > 0, "PaymentSplitter: empty payee list");
        
        Record memory recordToBeRemoved = record(account);
        delete payeeArchive.records[account];
        _remove(payeeArchive.addresses, account);
        payeeArchive.records[address(this)].shares -= recordToBeRemoved.shares;
        emit PayeeRemoved(account);
    }
    function getIndex(address[] memory list, address _address) private pure returns(uint256){
        for (uint256 i = 0; i < list.length; i++) {
            if(list[i] == _address){
                return i;
            }
        }
        // solhint-disable-next-line reason-string
        revert("PaymentSplitter: account not found");
    }
    function _remove(address[] storage list, address account) private {
        _remove(list, getIndex(list, account));
    }
    function _remove(address[] storage list, uint index) private {
        // Move the last element into the place to delete
        list[index] = list[list.length - 1];
        // Remove the last element
        list.pop();
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param _shares The number of shares owned by the payee.
     */
    function updatePayee(address account, uint256 _shares) public onlyOwner {
        _updatePayee(account, _shares);
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param _shares The number of shares owned by the payee.
     */
    function addPayee(address account, uint256 _shares) public onlyOwner {
        _addPayee(account, _shares);
    }

    /**
     * @dev Remove a payee from the contract.
     * @param account The address of the payee to remove.
     */
    function removePayee(address account) public onlyOwner {
        _removePayee(account);
    }
}
