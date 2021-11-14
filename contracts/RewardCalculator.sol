// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./abdk-libraries-solidity/ABDKMathQuad.sol";

contract RewardCalculator{
    using ABDKMathQuad for bytes16;

    bytes16 private immutable oneDay;
    bytes16 private immutable half;

    constructor (){
        oneDay = ABDKMathQuad.fromUInt(1 days);
        half = ABDKMathQuad.fromUInt(1).div(ABDKMathQuad.fromUInt(2));
    }

    function calculateQuantity(uint inputValue, bytes16 multiplier, bytes16 interestRate, uint elapsedTime) public view returns(uint){
        return multiplier.mul(ABDKMathQuad.fromUInt(inputValue))
        .div(
            ABDKMathQuad.fromUInt(1)
            .add(interestRate)
            .pow(
                ABDKMathQuad.fromUInt(elapsedTime)
                .div(oneDay)
            )
        )
        .add(half) // rounding
        .toUInt();
    }
}