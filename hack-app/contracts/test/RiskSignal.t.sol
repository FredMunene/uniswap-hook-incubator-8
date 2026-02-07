// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {RiskSignal} from "../src/RiskSignal.sol";

contract RiskSignalTest is Test {
    error OwnableUnauthorizedAccount(address account);

    event TierUpdated(RiskSignal.Tier indexed tier, uint64 updatedAt, uint16 confidence);
    event UpdaterChanged(address indexed oldUpdater, address indexed newUpdater);
    event StaleWindowChanged(uint64 oldWindow, uint64 newWindow);

    RiskSignal private signal;
    address private updater = address(0xBEEF);
    uint64 private staleWindow = 300;

    function setUp() public {
        signal = new RiskSignal(updater, staleWindow);
    }

    function test_constructor_revertsOnZeroStaleWindow() public {
        vm.expectRevert(RiskSignal.InvalidStaleWindow.selector);
        new RiskSignal(updater, 0);
    }

    function test_setTier_onlyUpdater() public {
        vm.expectRevert(RiskSignal.UnauthorizedUpdater.selector);
        signal.setTier(RiskSignal.Tier.Green, 100);
    }

    function test_setTier_updatesStateAndEmits() public {
        vm.warp(12345);
        vm.prank(updater);
        vm.expectEmit(true, false, false, true);
        emit TierUpdated(RiskSignal.Tier.Amber, 12345, 777);
        signal.setTier(RiskSignal.Tier.Amber, 777);

        (RiskSignal.Tier tier, uint64 updatedAt, uint16 confidence) = signal.getTier();
        assertEq(uint8(tier), uint8(RiskSignal.Tier.Amber));
        assertEq(updatedAt, 12345);
        assertEq(confidence, 777);
    }

    function test_setTier_revertsOnInvalidTier() public {
        vm.prank(updater);
        (bool ok,) = address(signal).call(
            abi.encodeWithSelector(signal.setTier.selector, uint8(3), uint16(0))
        );
        assertFalse(ok);
    }

    function test_setUpdater_onlyOwner() public {
        vm.prank(address(0xCAFE));
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0xCAFE)));
        signal.setUpdater(address(0x1234));
    }

    function test_setUpdater_updatesAndEmits() public {
        vm.expectEmit(true, true, false, true);
        emit UpdaterChanged(updater, address(0x1234));
        signal.setUpdater(address(0x1234));
        assertEq(signal.updater(), address(0x1234));
    }

    function test_setStaleWindow_onlyOwner() public {
        vm.prank(address(0xCAFE));
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0xCAFE)));
        signal.setStaleWindow(60);
    }

    function test_setStaleWindow_revertsOnZero() public {
        vm.expectRevert(RiskSignal.InvalidStaleWindow.selector);
        signal.setStaleWindow(0);
    }

    function test_setStaleWindow_updatesAndEmits() public {
        vm.expectEmit(false, false, false, true);
        emit StaleWindowChanged(staleWindow, 120);
        signal.setStaleWindow(120);
        assertEq(signal.staleWindow(), 120);
    }

    function test_getEffectiveTier_notStaleWhenNeverUpdated() public {
        (RiskSignal.Tier tier, bool isStale) = signal.getEffectiveTier();
        assertEq(uint8(tier), uint8(RiskSignal.Tier.Green));
        assertFalse(isStale);
    }

    function test_getEffectiveTier_escalatesOnStale() public {
        vm.prank(updater);
        signal.setTier(RiskSignal.Tier.Green, 0);
        vm.warp(block.timestamp + staleWindow + 1);
        (RiskSignal.Tier tier, bool isStale) = signal.getEffectiveTier();
        assertEq(uint8(tier), uint8(RiskSignal.Tier.Amber));
        assertTrue(isStale);

        vm.prank(updater);
        signal.setTier(RiskSignal.Tier.Amber, 0);
        vm.warp(block.timestamp + staleWindow + 1);
        (tier, isStale) = signal.getEffectiveTier();
        assertEq(uint8(tier), uint8(RiskSignal.Tier.Red));
        assertTrue(isStale);

        vm.prank(updater);
        signal.setTier(RiskSignal.Tier.Red, 0);
        vm.warp(block.timestamp + staleWindow + 1);
        (tier, isStale) = signal.getEffectiveTier();
        assertEq(uint8(tier), uint8(RiskSignal.Tier.Red));
        assertTrue(isStale);
    }
}
