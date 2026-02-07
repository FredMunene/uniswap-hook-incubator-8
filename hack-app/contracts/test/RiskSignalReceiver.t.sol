// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {RiskSignal} from "../src/RiskSignal.sol";
import {RiskSignalReceiver} from "../src/RiskSignalReceiver.sol";

contract RiskSignalReceiverTest is Test {
    RiskSignal private signal;
    RiskSignalReceiver private receiver;

    address private updater = address(0xBEEF);
    address private forwarder = address(0xFfF1);

    function setUp() public {
        signal = new RiskSignal(updater, 300);
        receiver = new RiskSignalReceiver(signal, forwarder);
        signal.setUpdater(address(receiver));
    }

    function test_onReport_revertsIfForwarderMismatch() public {
        bytes memory report = abi.encodeWithSelector(RiskSignal.setTier.selector, uint8(1), uint16(100));
        vm.expectRevert(RiskSignalReceiver.UnauthorizedForwarder.selector);
        receiver.onReport("", report);
    }

    function test_onReport_updatesTier() public {
        bytes memory report = abi.encodeWithSelector(RiskSignal.setTier.selector, uint8(1), uint16(1200));
        vm.prank(forwarder);
        receiver.onReport("", report);

        (RiskSignal.Tier tier, uint64 updatedAt, uint16 confidence) = signal.getTier();
        assertEq(uint8(tier), uint8(RiskSignal.Tier.Amber));
        assertGt(updatedAt, 0);
        assertEq(confidence, 1200);
    }

    function test_onReport_revertsOnInvalidSelector() public {
        bytes memory report = abi.encodeWithSignature("bad(uint256)", 1);
        vm.prank(forwarder);
        vm.expectRevert(RiskSignalReceiver.InvalidReport.selector);
        receiver.onReport("", report);
    }
}
