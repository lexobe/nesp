// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {IFeeValidator} from "../interfaces/IFeeValidator.sol";

contract AlwaysYesValidator is IFeeValidator {
    function validate(address, uint16) external pure returns (bool ok) { return true; }
}

