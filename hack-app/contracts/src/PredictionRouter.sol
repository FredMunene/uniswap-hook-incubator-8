// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";

/// @title PredictionRouter
/// @notice User-facing swap contract for the prediction-informed ETH/USDC pool.
/// @dev Calls PoolManager.unlock() and settles tokens in the callback.
contract PredictionRouter is IUnlockCallback {
    // ── Events ───────────────────────────────────────────────────────────
    event SwapExecuted(
        address indexed user, bool zeroForOne, int256 amountSpecified, int256 amount0Delta, int256 amount1Delta
    );

    // ── Errors ───────────────────────────────────────────────────────────
    error DeadlineExpired();
    error NotPoolManager();

    // ── Immutables ───────────────────────────────────────────────────────
    IPoolManager public immutable poolManager;
    PoolKey public poolKey;

    // ── Constructor ──────────────────────────────────────────────────────
    constructor(IPoolManager _poolManager, PoolKey memory _poolKey) {
        poolManager = _poolManager;
        poolKey = _poolKey;
    }

    struct CallbackData {
        address sender;
        PoolKey key;
        SwapParams params;
    }

    /// @notice Execute a swap on the ETH/USDC pool.
    /// @param zeroForOne True = sell token0 for token1, false = opposite.
    /// @param amountSpecified Negative = exact input, positive = exact output.
    /// @param sqrtPriceLimitX96 Price limit for the swap.
    /// @param deadline Swap must execute before this timestamp.
    function swap(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, uint256 deadline)
        external
        payable
        returns (BalanceDelta delta)
    {
        if (block.timestamp > deadline) revert DeadlineExpired();

        SwapParams memory params =
            SwapParams({zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: sqrtPriceLimitX96});

        delta = abi.decode(
            poolManager.unlock(abi.encode(CallbackData({sender: msg.sender, key: poolKey, params: params}))),
            (BalanceDelta)
        );

        // Return excess ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            CurrencyLibrary.ADDRESS_ZERO.transfer(msg.sender, ethBalance);
        }

        emit SwapExecuted(msg.sender, zeroForOne, amountSpecified, delta.amount0(), delta.amount1());
    }

    /// @notice Callback invoked by PoolManager during unlock.
    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();

        CallbackData memory data = abi.decode(rawData, (CallbackData));

        BalanceDelta delta = poolManager.swap(data.key, data.params, "");

        // Settle negative deltas (tokens owed to pool) and take positive deltas (tokens owed to user)
        _settleDelta(data.sender, data.key.currency0, delta.amount0());
        _settleDelta(data.sender, data.key.currency1, delta.amount1());

        return abi.encode(delta);
    }

    /// @dev Settle a single currency delta. Negative = pay pool, positive = receive from pool.
    function _settleDelta(address user, Currency currency, int128 delta) internal {
        if (delta < 0) {
            // User owes the pool — pull tokens from user and send to PoolManager
            uint256 amount = uint256(uint128(-delta));
            if (currency.isAddressZero()) {
                // Native ETH
                poolManager.settle{value: amount}();
            } else {
                poolManager.sync(currency);
                IERC20Minimal(Currency.unwrap(currency)).transferFrom(user, address(poolManager), amount);
                poolManager.settle();
            }
        } else if (delta > 0) {
            // Pool owes the user — take tokens from PoolManager to user
            uint256 amount = uint256(uint128(delta));
            poolManager.take(currency, user, amount);
        }
    }

    receive() external payable {}
}
