// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";

import {RiskSignal} from "../src/RiskSignal.sol";
import {PredictionHook} from "../src/PredictionHook.sol";

contract PredictionHookTest is Test {
    RiskSignal private signal;
    PredictionHook private hook;

    address private poolManager = address(0x1234);
    address private updater = address(0xBEEF);

    function setUp() public {
        signal = new RiskSignal(updater, 300);

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        deployCodeTo("PredictionHook.sol", abi.encode(poolManager, signal), address(flags));
        hook = PredictionHook(address(flags));
    }

    function test_beforeSwap_revertsIfNotPoolManager() public {
        PoolKey memory key = _dummyKey();
        SwapParams memory params = _dummyParams();
        vm.expectRevert(PredictionHook.NotPoolManager.selector);
        hook.beforeSwap(address(this), key, params, "");
    }

    function test_beforeSwap_greenTierReturnsGreenFee() public {
        PoolKey memory key = _dummyKey();
        SwapParams memory params = _dummyParams();

        vm.prank(poolManager);
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(address(this), key, params, "");

        assertEq(selector, IHooks.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(delta), BeforeSwapDelta.unwrap(BeforeSwapDeltaLibrary.ZERO_DELTA));
        uint24 expectedFee = uint24(3000) | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        assertEq(fee, expectedFee);
    }

    function test_beforeSwap_amberTierReturnsAmberFee() public {
        vm.prank(updater);
        signal.setTier(RiskSignal.Tier.Amber, 0);

        PoolKey memory key = _dummyKey();
        SwapParams memory params = _dummyParams();

        vm.prank(poolManager);
        (, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(address(this), key, params, "");

        assertEq(BeforeSwapDelta.unwrap(delta), BeforeSwapDelta.unwrap(BeforeSwapDeltaLibrary.ZERO_DELTA));
        uint24 expectedFee = uint24(10000) | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        assertEq(fee, expectedFee);
    }

    function test_beforeSwap_redTierReverts() public {
        vm.prank(updater);
        signal.setTier(RiskSignal.Tier.Red, 0);

        PoolKey memory key = _dummyKey();
        SwapParams memory params = _dummyParams();

        vm.prank(poolManager);
        vm.expectRevert(PredictionHook.SwapBlockedRedTier.selector);
        hook.beforeSwap(address(this), key, params, "");
    }

    function test_beforeSwap_staleEscalatesToAmberFee() public {
        vm.prank(updater);
        signal.setTier(RiskSignal.Tier.Green, 0);

        vm.warp(block.timestamp + signal.staleWindow() + 1);

        PoolKey memory key = _dummyKey();
        SwapParams memory params = _dummyParams();

        vm.prank(poolManager);
        (, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(address(this), key, params, "");

        assertEq(BeforeSwapDelta.unwrap(delta), BeforeSwapDelta.unwrap(BeforeSwapDeltaLibrary.ZERO_DELTA));
        uint24 expectedFee = uint24(10000) | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        assertEq(fee, expectedFee);
    }

    function _dummyKey() internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(0x1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _dummyParams() internal pure returns (SwapParams memory) {
        return SwapParams({zeroForOne: true, amountSpecified: -1, sqrtPriceLimitX96: 0});
    }
}
