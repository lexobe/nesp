// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IFeeValidator {
    function validate(address feeRecipient, uint16 feeBps) external view returns (bool ok);
}

