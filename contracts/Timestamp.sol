// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Timestamp {

    function getTimestamp() public view returns (uint256){
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }
}