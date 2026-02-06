# Architecture — Prediction‑Informed Router (MVP)

## System overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Off‑chain                                │
│                                                                 │
│  ┌──────────────┐      ┌───────────────────┐                    │
│  │  Polymarket   │─────►│  CRE Workflow      │                   │
│  │  REST API     │      │  (fetch + classify)│                   │
│  └──────────────┘      └────────┬──────────┘                    │
│                                 │ setTier(tier, confidence)      │
└─────────────────────────────────┼───────────────────────────────┘
                                  │
┌─────────────────────────────────┼───────────────────────────────┐
│                    Arbitrum Sepolia (421614)                     │
│                                 │                               │
│                                 ▼                               │
│  ┌──────────────────────────────────────┐                       │
│  │          RiskSignal                   │                       │
│  │  ┌────────┬───────────┬────────────┐ │                       │
│  │  │ tier   │ updatedAt │ confidence │ │                       │
│  │  └────────┴───────────┴────────────┘ │                       │
│  │  getEffectiveTier() → (tier, stale)  │                       │
│  └──────────────────▲───────────────────┘                       │
│                     │ reads                                     │
│                     │                                           │
│  ┌──────────────────┴───────────────────┐                       │
│  │         PredictionHook (v4 hook)      │                       │
│  │  beforeSwap():                        │                       │
│  │    Green  → fee 3000   (0.30%)        │                       │
│  │    Amber  → fee 10000  (1.00%)        │                       │
│  │    Red    → revert                    │                       │
│  └──────────────────▲───────────────────┘                       │
│                     │ callback                                  │
│  ┌──────────────────┴───────────────────┐                       │
│  │          PoolManager (v4)             │                       │
│  │    pool: ETH/USDC + PredictionHook    │                       │
│  └──────────────────▲───────────────────┘                       │
│                     │ unlock → swap                             │
│  ┌──────────────────┴───────────────────┐                       │
│  │        PredictionRouter               │                       │
│  │  swap(params) → PoolManager.unlock()  │                       │
│  └──────────────────▲───────────────────┘                       │
│                     │                                           │
└─────────────────────┼───────────────────────────────────────────┘
                      │
                   User / Script
```

## Components

### 1) RiskSignal (contract)

**Purpose:** Single‑slot oracle that stores the current risk tier.

- **Owner:** Deployer (can change updater and staleWindow).
- **Updater:** CRE workflow EOA (can call `setTier`).
- **Storage:** tier (uint8), updatedAt (uint64), confidence (uint16) — packed into one slot.
- **Staleness:** `getEffectiveTier()` escalates tier if `block.timestamp - updatedAt > staleWindow`.
  - Green + stale → Amber
  - Amber + stale → Red
  - Red + stale → Red

**Key parameters:**
| Parameter    | Value | Notes                              |
|-------------|-------|------------------------------------|
| staleWindow | 300s  | 5 minutes; 5× CRE polling interval |

See [interfaces.md](./interfaces.md) for full Solidity interface.

### 2) PredictionHook (v4 hook)

**Purpose:** Enforce risk‑tier policy on every swap in the ETH/USDC pool.

- Inherits `BaseHook` from v4‑periphery.
- Only `beforeSwap` is enabled.
- Reads `riskSignal.getEffectiveTier()` on each call.
- Returns a **dynamic fee override** based on the tier.
- Emits `SwapRouted` or `SwapBlocked` events for auditability.

**Pool initialization requirements:**
- The pool must be created with `fee = DYNAMIC_FEE_FLAG` so the hook can override fees.
- Pool key: `{currency0: WETH, currency1: USDC, fee: DYNAMIC_FEE_FLAG, tickSpacing: 60, hooks: PredictionHook}`.
- Token ordering: `currency0 < currency1` by address. WETH and USDC addresses must be checked at deploy time.

**Hook address mining:**
- v4 encodes hook permissions in the address. The `beforeSwap` flag must be set.
- Use `CREATE2` salt mining (e.g., v4‑periphery `HookMiner`) to find a valid address.

### 3) PredictionRouter (contract)

**Purpose:** User‑facing swap execution. Thin wrapper around `PoolManager.unlock()`.

- Accepts `SwapParams` (zeroForOne, amountSpecified, slippageTolerance, deadline).
- Calls `PoolManager.unlock()` with encoded callback data.
- In the `unlockCallback`, calls `PoolManager.swap()` with the pool key.
- Settles token transfers via `PoolManager.settle()` and `PoolManager.take()`.
- Validates slippage and deadline.

**Token flow:**
1. User approves tokens to PredictionRouter (or uses Permit2).
2. Router calls `PoolManager.unlock()`.
3. In callback: `PoolManager.swap()` → hook `beforeSwap` fires → fee/block applied.
4. Router settles: transfers input tokens to PoolManager, takes output tokens to user.

### 4) CRE Workflow (off‑chain)

**Purpose:** Fetch Polymarket signal, compute tier, publish to RiskSignal.

- **Language:** TypeScript (CRE SDK).
- **Trigger:** Polling every 60 seconds.
- **Steps:**
  1. Fetch event probability from Polymarket REST API.
  2. Apply threshold logic: p < 0.10 → Green, 0.10 ≤ p < 0.25 → Amber, p ≥ 0.25 → Red.
  3. Call `RiskSignal.setTier(tier, confidence)` on Arbitrum Sepolia.
  4. Log result (tier, probability, tx hash).
- **Error handling:** On API failure or tx revert, skip update. Staleness on `RiskSignal` auto‑escalates.

See [cre-workflow-spec.md](./cre-workflow-spec.md) for full specification.

## Data flow (happy path)

```
1. CRE polls Polymarket API → gets probability 0.18
2. CRE classifies: 0.10 ≤ 0.18 < 0.25 → Amber
3. CRE calls RiskSignal.setTier(Amber, 1800) → tier stored, event emitted
4. User calls PredictionRouter.swap(...)
5. Router calls PoolManager.unlock()
6. PoolManager calls PredictionHook.beforeSwap()
7. Hook reads RiskSignal.getEffectiveTier() → (Amber, false)
8. Hook returns fee = 10000 (1.00%), emits SwapRouted
9. PoolManager executes swap at 1.00% fee
10. Router settles tokens, emits SwapExecuted
```

## Data flow (stale signal)

```
1. CRE last updated 6 minutes ago (> 300s staleWindow)
2. Stored tier = Green, but stale
3. User calls PredictionRouter.swap(...)
4. Hook reads RiskSignal.getEffectiveTier() → (Amber, true)  [escalated]
5. Hook returns fee = 10000, emits SwapRouted with isStale=true
```

## Data flow (Red tier — blocked)

```
1. RiskSignal.getEffectiveTier() → (Red, false)
2. Hook reverts with SwapBlockedRedTier()
3. Entire swap transaction reverts
4. SwapBlocked event emitted (via try/catch in future; for MVP, revert is sufficient)
```

## Trust model

| Component         | Trust level | Failure mode                        |
|-------------------|-------------|-------------------------------------|
| Polymarket API    | External    | Returns stale/wrong data → tier may lag |
| CRE Workflow      | Controlled  | Fails to post → staleness escalation |
| RiskSignal        | Onchain     | Updater compromised → wrong tier posted |
| PredictionHook    | Onchain     | Immutable once deployed; reads RiskSignal |
| PoolManager       | Onchain     | Uniswap v4 — audited, trusted       |

**Key invariant:** If anything upstream fails, the staleness mechanism pushes the effective tier toward Red (conservative). The system fails safe.

## Gas considerations (Arbitrum)

- Arbitrum Sepolia has low gas costs (~0.1 gwei L2 gas).
- `RiskSignal.getEffectiveTier()` is a single SLOAD + comparison (~2100 gas).
- Hook overhead is minimal — one external call + one SLOAD + fee return.
- Total hook cost: ~5000–8000 gas on top of base swap gas.

## Deployment addresses (to be filled post‑deploy)

| Contract         | Address | Deploy tx |
|-----------------|---------|-----------|
| RiskSignal       | TBD     | TBD       |
| PredictionHook   | TBD     | TBD       |
| PredictionRouter | TBD     | TBD       |
| ETH/USDC Pool    | TBD     | TBD       |

## References

- [Interfaces](./interfaces.md) — Full Solidity interfaces
- [ADR‑001](./adr-001-signal-source-and-thresholds.md) — Signal source & threshold decisions
- [ARD](./ard.md) — Architecture decision record
- [External Resources](./external-resources.md) — Links, addresses, APIs
