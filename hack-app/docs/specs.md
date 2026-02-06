# Specs — Prediction‑Informed Router (MVP)

## 1) Risk tiers

| Value | Tier  | Meaning                                |
|-------|-------|----------------------------------------|
| 0     | Green | Normal conditions — low perceived risk |
| 1     | Amber | Caution — moderate uncertainty          |
| 2     | Red   | High risk — adverse event likely       |

`RiskSignal` stores (packed in one slot):
- `tier: uint8` — 0/1/2
- `updatedAt: uint64` — block.timestamp at last update
- `confidence: uint16` — 0–10000 bps (0 if unavailable)

## 2) Tier thresholds (Polymarket → tier)

Signal: "Will Ethereum dip to $1,600?" (condition ID `0xa2e0...13ee`).

| Polymarket probability | Tier  |
|-----------------------|-------|
| p < 0.10              | Green |
| 0.10 ≤ p < 0.25      | Amber |
| p ≥ 0.25              | Red   |

Thresholds are calibrated for ETH downside‑dip markets (see [ADR‑001](./adr-001-signal-source-and-thresholds.md)). Configurable via CRE workflow environment variables.

## 3) Tier policy (hook enforcement)

| Tier  | Action          | Dynamic fee           | Notes                         |
|-------|----------------|-----------------------|-------------------------------|
| Green | Allow swap      | 3000 (0.30%)          | Standard execution            |
| Amber | Allow + surcharge | 10000 (1.00%)       | LP protection; higher fee discourages toxic flow |
| Red   | **Block swap**  | N/A (revert)          | `SwapBlockedRedTier` error    |

The hook enforces this in `beforeSwap` regardless of which router initiates the swap.

## 4) Staleness policy

**STALE_WINDOW: 300 seconds (5 minutes)**

If `block.timestamp - updatedAt > staleWindow`:
- Stored Green → effective **Amber**
- Stored Amber → effective **Red**
- Stored Red → stays **Red**

Staleness is computed on‑chain in `RiskSignal.getEffectiveTier()`. The hook always reads the effective tier, not the raw stored tier.

## 5) Hook requirements

- Inherits `BaseHook` from `v4-periphery`.
- Only `beforeSwap` flag enabled.
- Reads `riskSignal.getEffectiveTier()` on each swap.
- Returns dynamic fee override to PoolManager.
- Emits `SwapRouted(tier, isStale, sender, amountSpecified, dynamicFee)` on allowed swaps.
- Emits `SwapBlocked(tier, sender, amountSpecified)` and reverts on Red tier.
- Pool must be initialized with `DYNAMIC_FEE_FLAG` and `tickSpacing = 60`.
- Hook address must be mined to encode `beforeSwap` permission.

## 6) Router requirements

- Accept ETH/USDC swaps only (MVP).
- Call `PoolManager.unlock()` → in callback, call `PoolManager.swap()`.
- Validate slippage tolerance and deadline.
- Settle tokens via PoolManager `settle()` / `take()`.
- Emit `SwapExecuted(user, zeroForOne, amountSpecified, amount0Delta, amount1Delta)`.

## 7) RiskSignal requirements

- `setTier(tier, confidence)` — only callable by authorized updater.
- `getTier()` — returns raw tier, updatedAt, confidence.
- `getEffectiveTier()` — returns staleness‑adjusted tier + isStale flag.
- `setUpdater(newUpdater)` — only callable by owner.
- `setStaleWindow(newWindow)` — only callable by owner.
- Emit `TierUpdated`, `UpdaterChanged`, `StaleWindowChanged` events.

## 8) CRE workflow requirements

- Pull probability for "Will Ethereum dip to $1,600?" via Polymarket REST API.
- Apply threshold logic (section 2 above): Green < 0.10, Amber 0.10–0.24, Red ≥ 0.25.
- Convert probability to confidence (p × 10000 bps).
- Call `RiskSignal.setTier(tier, confidence)` on Arbitrum Sepolia.
- Poll every 60 seconds.
- On API failure or tx revert: skip update, log error. Staleness handles the rest.
- Log: timestamp, probability, computed tier, tx hash.

## 9) Security

- `RiskSignal` write access restricted to single updater EOA (CRE workflow).
- Owner can rotate updater address.
- Hook validates it is called on the correct pool (optional — pool key is immutable).
- Guard against stale signal (on‑chain staleness escalation).
- Router validates slippage and deadline.
- No admin override for Red‑tier blocking in MVP.

## 10) Demo requirements

- Show ≥ 3 swaps with different tiers:
  1. Green tier swap → executes at 0.30% fee
  2. Amber tier swap → executes at 1.00% fee
  3. Red tier swap → reverts with `SwapBlockedRedTier`
- Show onchain `RiskSignal` tier updates (TierUpdated events).
- Show routing decisions change with tier (SwapRouted events).
- Record all TxIDs for submission.

## 11) Test plan

### Unit tests
- `RiskSignal`: setTier access control (authorized vs unauthorized)
- `RiskSignal`: getTier returns correct values
- `RiskSignal`: staleness escalation (Green→Amber, Amber→Red, Red→Red)
- `RiskSignal`: setUpdater and setStaleWindow access control
- `PredictionHook`: Green tier → base fee returned
- `PredictionHook`: Amber tier → surcharge fee returned
- `PredictionHook`: Red tier → revert
- `PredictionHook`: stale Green → Amber behavior
- `PredictionHook`: stale Amber → Red (blocked)

### Integration tests
- Mock signal update → swap routed at correct fee
- Tier change between swaps → different fee applied
- Stale signal → escalation → correct behavior

## 12) Target chain & addresses

**Chain:** Arbitrum Sepolia (421614)
**RPC:** `https://sepolia-rollup.arbitrum.io/rpc`
**Explorer:** `https://sepolia.arbiscan.io`

| Contract        | Address                                      |
|----------------|----------------------------------------------|
| PoolManager     | `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317` |
| PositionManager | `0xAc631556d3d4019C95769033B5E719dD77124BAc`  |
| PoolSwapTest    | `0xf3a39c86dbd13c45365e57fb90fe413371f65af8`  |
| Permit2         | `0x000000000022D473030F116dDEE9F6B43aC78BA3`  |
| WETH            | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73`  |
| USDC            | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`  |
