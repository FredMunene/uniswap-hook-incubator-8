# Solidity Interfaces — Prediction‑Informed Router (MVP)

## Overview

Three contracts form the MVP:

1. **`RiskSignal`** — Stores the current risk tier, updated by the CRE workflow.
2. **`PredictionHook`** — Uniswap v4 hook attached to the ETH/USDC pool; enforces tier‑based policy on every swap.
3. **`PredictionRouter`** — User‑facing contract that executes swaps through the v4 `PoolManager`.

---

## 1) IRiskSignal

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRiskSignal {
    // ── Types ────────────────────────────────────────────────────────────
    enum Tier {
        Green,  // 0 — normal
        Amber,  // 1 — caution
        Red     // 2 — high risk
    }

    // ── Events ───────────────────────────────────────────────────────────
    /// @notice Emitted when the risk tier is updated.
    event TierUpdated(Tier indexed tier, uint64 updatedAt, uint16 confidence);

    /// @notice Emitted when the authorized updater address changes.
    event UpdaterChanged(address indexed oldUpdater, address indexed newUpdater);

    /// @notice Emitted when the stale window is changed.
    event StaleWindowChanged(uint64 oldWindow, uint64 newWindow);

    // ── Errors ───────────────────────────────────────────────────────────
    /// @notice Caller is not the authorized updater.
    error UnauthorizedUpdater();

    /// @notice Provided tier value is out of range.
    error InvalidTier(uint8 tier);

    /// @notice New stale window is zero.
    error InvalidStaleWindow();

    // ── Write ────────────────────────────────────────────────────────────
    /// @notice Set the current risk tier. Only callable by the authorized updater.
    /// @param tier Risk tier (0 = Green, 1 = Amber, 2 = Red).
    /// @param confidence Confidence score in basis points (0–10000). Pass 0 if unavailable.
    function setTier(Tier tier, uint16 confidence) external;

    /// @notice Change the authorized updater address. Only callable by the owner.
    /// @param newUpdater Address of the new updater (CRE workflow EOA).
    function setUpdater(address newUpdater) external;

    /// @notice Change the staleness window. Only callable by the owner.
    /// @param newWindow New stale window in seconds.
    function setStaleWindow(uint64 newWindow) external;

    // ── Read ─────────────────────────────────────────────────────────────
    /// @notice Return the current tier, the timestamp it was set, and confidence.
    /// @return tier Current risk tier.
    /// @return updatedAt Block timestamp of the last update.
    /// @return confidence Confidence in basis points (0–10000).
    function getTier() external view returns (Tier tier, uint64 updatedAt, uint16 confidence);

    /// @notice Return the effective tier, accounting for staleness.
    /// @dev If the signal is stale (block.timestamp - updatedAt > staleWindow),
    ///      returns Amber (if stored Green) or Red (if stored Amber/Red).
    /// @return tier Effective tier after staleness adjustment.
    /// @return isStale Whether the signal is currently stale.
    function getEffectiveTier() external view returns (Tier tier, bool isStale);

    /// @notice Return the configured stale window in seconds.
    function staleWindow() external view returns (uint64);

    /// @notice Return the authorized updater address.
    function updater() external view returns (address);
}
```

### Storage layout

| Slot | Field        | Type     | Notes                         |
|------|-------------|----------|-------------------------------|
| 0    | `tier`      | `uint8`  | Enum → 0/1/2                  |
| 0    | `updatedAt` | `uint64` | `block.timestamp` at set time |
| 0    | `confidence`| `uint16` | 0–10000 bps                   |
| 1    | `updater`   | `address`| CRE workflow EOA              |
| 2    | `staleWindow`| `uint64`| Default: 300 (5 min)         |

---

## 2) PredictionHook (BaseHook)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {IRiskSignal} from "./IRiskSignal.sol";

/// @title PredictionHook
/// @notice Uniswap v4 hook that enforces risk‑tier policy on swaps.
/// @dev Attached to the ETH/USDC pool. Reads RiskSignal before each swap.
abstract contract PredictionHook is BaseHook {
    // ── Events ───────────────────────────────────────────────────────────
    /// @notice Emitted after every swap with the routing decision.
    event SwapRouted(
        IRiskSignal.Tier indexed tier,
        bool isStale,
        address indexed sender,
        int256 amountSpecified,
        uint24 dynamicFee
    );

    /// @notice Emitted when a swap is blocked due to Red tier.
    event SwapBlocked(
        IRiskSignal.Tier indexed tier,
        address indexed sender,
        int256 amountSpecified
    );

    // ── Errors ───────────────────────────────────────────────────────────
    /// @notice Swap blocked because the current effective tier is Red.
    error SwapBlockedRedTier();

    /// @notice Pool key does not match the authorized ETH/USDC pool.
    error UnauthorizedPool();

    // ── Immutables ───────────────────────────────────────────────────────
    /// @notice Reference to the RiskSignal oracle contract.
    // IRiskSignal public immutable riskSignal;

    // ── Hook permissions ─────────────────────────────────────────────────
    // Flags (from Hooks.sol):
    //   BEFORE_SWAP_FLAG              = true
    //   AFTER_SWAP_FLAG               = false
    //   BEFORE_ADD_LIQUIDITY_FLAG     = false
    //   BEFORE_REMOVE_LIQUIDITY_FLAG  = false
    //   (all others false)

    // ── Hook callbacks ───────────────────────────────────────────────────

    /// @notice Called before every swap on the attached pool.
    /// @dev Reads RiskSignal.getEffectiveTier() and enforces policy:
    ///   - Green: allow swap, base fee.
    ///   - Amber: allow swap, apply LP‑protection surcharge fee.
    ///   - Red:   revert (block swap).
    /// @return selector The function selector for beforeSwap.
    /// @return delta BeforeSwapDelta (unused, returns 0).
    /// @return fee Dynamic fee override (in hundredths of a bip):
    ///   - Green: 3000 (0.30%)
    ///   - Amber: 10000 (1.00%)
    ///   - Red:   N/A (reverts)
    // function beforeSwap(
    //     address sender,
    //     PoolKey calldata key,
    //     IPoolManager.SwapParams calldata params,
    //     bytes calldata hookData
    // ) external override returns (bytes4, BeforeSwapDelta, uint24);
}
```

### Hook behavior per tier

| Tier   | Action         | Dynamic Fee | Slippage | Notes                          |
|--------|---------------|-------------|----------|--------------------------------|
| Green  | Allow          | 3000 (0.30%)| Normal   | Standard routing               |
| Amber  | Allow + surcharge | 10000 (1.00%) | Tighter  | LP protection; higher fee discourages toxic flow |
| Red    | **Revert**     | N/A         | N/A      | `SwapBlockedRedTier()` emitted before revert |

### Hook flags

```
getHookPermissions() returns:
  beforeInitialize:        false
  afterInitialize:         false
  beforeAddLiquidity:      false
  afterAddLiquidity:       false
  beforeRemoveLiquidity:   false
  afterRemoveLiquidity:    false
  beforeSwap:              true   ← enforces tier policy
  afterSwap:               false
  beforeDonate:            false
  afterDonate:             false
  beforeSwapReturnDelta:   false
  afterSwapReturnDelta:    false
  afterAddLiquidityReturnDelta:    false
  afterRemoveLiquidityReturnDelta: false
```

---

## 3) PredictionRouter

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

/// @title PredictionRouter
/// @notice User‑facing contract for executing swaps on the prediction‑informed ETH/USDC pool.
/// @dev Calls PoolManager.swap() via unlock callback pattern.
interface IPredictionRouter {
    // ── Events ───────────────────────────────────────────────────────────
    /// @notice Emitted after a successful swap.
    event SwapExecuted(
        address indexed user,
        bool zeroForOne,
        int256 amountSpecified,
        int256 amount0Delta,
        int256 amount1Delta
    );

    // ── Errors ───────────────────────────────────────────────────────────
    /// @notice Slippage tolerance exceeded.
    error SlippageExceeded(uint256 expected, uint256 actual);

    /// @notice Swap deadline has passed.
    error DeadlineExpired();

    // ── Structs ──────────────────────────────────────────────────────────
    struct SwapParams {
        /// @dev true = sell token0 (WETH) for token1 (USDC); false = opposite.
        bool zeroForOne;
        /// @dev Positive = exact input; negative = exact output.
        int256 amountSpecified;
        /// @dev Minimum output (exact‑input) or maximum input (exact‑output).
        uint256 slippageTolerance;
        /// @dev Swap must execute before this timestamp.
        uint256 deadline;
    }

    // ── Write ────────────────────────────────────────────────────────────
    /// @notice Execute a swap on the ETH/USDC pool.
    /// @param params Swap parameters.
    /// @return amount0Delta Change in token0 balance (negative = sent, positive = received).
    /// @return amount1Delta Change in token1 balance.
    function swap(SwapParams calldata params) external payable returns (int256 amount0Delta, int256 amount1Delta);

    // ── Read ─────────────────────────────────────────────────────────────
    /// @notice Return the pool key for the attached ETH/USDC pool.
    function poolKey() external view returns (PoolKey memory);

    /// @notice Return the PoolManager address.
    function poolManager() external view returns (IPoolManager);
}
```

---

## Contract dependency graph

```
User
 │
 ▼
PredictionRouter ──swap()──► PoolManager.unlock()
                                  │
                                  ▼
                             PoolManager.swap(poolKey, params)
                                  │
                                  ▼
                             PredictionHook.beforeSwap()
                                  │
                                  ├── reads RiskSignal.getEffectiveTier()
                                  ├── Green  → return (selector, 0, 3000)
                                  ├── Amber  → return (selector, 0, 10000)
                                  └── Red    → revert SwapBlockedRedTier()
```

---

## Deployment order

1. Deploy `RiskSignal` → set updater to CRE workflow EOA, set `staleWindow = 300`.
2. Deploy `PredictionHook` → pass `RiskSignal` address and `PoolManager` address. Hook address must satisfy v4 flag‑mining requirements.
3. Initialize pool on `PoolManager` with the hook address in the pool key.
4. Deploy `PredictionRouter` → pass `PoolManager` address and `PoolKey`.
5. Seed pool with initial liquidity via `PositionManager`.
6. Configure CRE workflow to call `RiskSignal.setTier()`.
