// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RiskSignal} from "./RiskSignal.sol";

/// @notice Minimal receiver interface used by CRE writeReport.
interface IReceiver {
    function onReport(bytes calldata metadata, bytes calldata report) external;
}

/// @title RiskSignalReceiver
/// @notice CRE receiver that decodes reports and calls RiskSignal.setTier.
contract RiskSignalReceiver is IReceiver, Ownable {
    error UnauthorizedForwarder();
    error InvalidReport();

    RiskSignal public immutable riskSignal;
    address public forwarder;

    constructor(RiskSignal _riskSignal, address _forwarder) Ownable(msg.sender) {
        riskSignal = _riskSignal;
        forwarder = _forwarder;
    }

    /// @notice Update the forwarder allowed to call onReport.
    function setForwarder(address newForwarder) external onlyOwner {
        forwarder = newForwarder;
    }

    /// @notice Called by the CRE forwarder with an encoded setTier call.
    function onReport(bytes calldata, bytes calldata report) external override {
        if (forwarder != address(0) && msg.sender != forwarder) revert UnauthorizedForwarder();
        if (report.length < 4) revert InvalidReport();

        // Report is expected to be the calldata for RiskSignal.setTier(uint8,uint16)
        bytes4 selector;
        assembly ("memory-safe") {
            selector := calldataload(report.offset)
        }
        if (selector != RiskSignal.setTier.selector) revert InvalidReport();

        (uint8 tier, uint16 confidence) = abi.decode(report[4:], (uint8, uint16));
        riskSignal.setTier(RiskSignal.Tier(tier), confidence);
    }
}
