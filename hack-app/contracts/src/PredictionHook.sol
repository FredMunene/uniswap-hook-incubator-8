// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {RiskSignal} from "./RiskSignal.sol";

/// @title PredictionHook
/// @notice Uniswap v4 hook that enforces risk-tier policy on swaps.
/// @dev Only beforeSwap is active. Reads RiskSignal.getEffectiveTier() and returns a dynamic fee.
///      Green = 0.30%, Amber = 1.00%, Red = revert.
contract PredictionHook is IHooks {
    // ── Constants ────────────────────────────────────────────────────────
    uint24 public constant GREEN_FEE = 3000;
    uint24 public constant AMBER_FEE = 10000;

    // ── Events ───────────────────────────────────────────────────────────
    event SwapRouted(
        RiskSignal.Tier indexed tier, bool isStale, address indexed sender, int256 amountSpecified, uint24 dynamicFee
    );

    // ── Errors ───────────────────────────────────────────────────────────
    error SwapBlockedRedTier();
    error NotPoolManager();

    // ── Immutables ───────────────────────────────────────────────────────
    IPoolManager public immutable poolManager;
    RiskSignal public immutable riskSignal;

    // ── Constructor ──────────────────────────────────────────────────────
    constructor(IPoolManager _poolManager, RiskSignal _riskSignal) {
        poolManager = _poolManager;
        riskSignal = _riskSignal;
        Hooks.validateHookPermissions(
            IHooks(address(this)),
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            })
        );
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    // ── beforeSwap (active) ──────────────────────────────────────────────
    /// @notice Enforces risk-tier policy before each swap.
    /// @dev Green → 0.30% fee, Amber → 1.00% fee, Red → revert.
    function beforeSwap(address sender, PoolKey calldata, SwapParams calldata params, bytes calldata)
        external
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (RiskSignal.Tier tier, bool isStale) = riskSignal.getEffectiveTier();

        if (tier == RiskSignal.Tier.Red) {
            revert SwapBlockedRedTier();
        }

        uint24 fee = tier == RiskSignal.Tier.Amber ? AMBER_FEE : GREEN_FEE;

        emit SwapRouted(tier, isStale, sender, params.amountSpecified, fee);

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    // ── Unused hooks (no-op implementations) ─────────────────────────────
    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        returns (bytes4, int128)
    {
        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.afterDonate.selector;
    }
}
