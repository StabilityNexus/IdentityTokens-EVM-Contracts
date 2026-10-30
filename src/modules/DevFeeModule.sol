// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Errors } from "../libraries/Errors.sol";
import { Events } from "../libraries/Events.sol";

abstract contract DevFeeModule {
    // devFee is a percentage of each transaction's gas fee; frontends compute the donation from it
    uint256 public constant MAX_DEV_FEE = 5000;

    address public dev;
    address public pendingDev;
    address public devFeeReceiver;
    uint256 public devFee;

    constructor(address _dev, address _devFeeReceiver, uint256 _devFee) {
        if (_dev == address(0) || _devFeeReceiver == address(0)) revert Errors.ZeroAddress();
        if (_devFee > MAX_DEV_FEE) revert Errors.DevFeeTooHigh();
        dev = _dev;
        devFeeReceiver = _devFeeReceiver;
        devFee = _devFee;
    }

    modifier onlyDev() {
        if (msg.sender != dev) revert Errors.NotDev();
        _;
    }

    function setDevFee(uint256 newDevFee) external onlyDev {
        if (newDevFee > MAX_DEV_FEE) revert Errors.DevFeeTooHigh();
        devFee = newDevFee;
        emit Events.DevFeeSet(newDevFee);
    }

    function setDevFeeReceiver(address receiver) external onlyDev {
        if (receiver == address(0)) revert Errors.ZeroAddress();
        devFeeReceiver = receiver;
        emit Events.DevFeeReceiverSet(receiver);
    }

    // First step of handing over the dev role; address(0) cancels a pending proposal
    function proposeDev(address newDev) external onlyDev {
        pendingDev = newDev;
        emit Events.DevTransferProposed(msg.sender, newDev);
    }

    function acceptDev() external {
        if (msg.sender != pendingDev) revert Errors.NotPendingDev();
        emit Events.DevTransferred(dev, msg.sender);
        dev = msg.sender;
        pendingDev = address(0);
    }
}
