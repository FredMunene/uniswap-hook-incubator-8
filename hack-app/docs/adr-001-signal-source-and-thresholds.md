# ADR‑001: Signal Source & Tier Thresholds

**Status:** Accepted (revised)
**Date:** 2025‑02‑07
**Revised:** 2025‑02‑07T20:00Z — recalibrated thresholds for selected market
**Deciders:** Team

---

## Context

The Prediction‑Informed Router needs an external signal to classify market risk into three tiers (Green / Amber / Red). We must choose a signal source, define the mapping from raw signal to tier, and set concrete parameter values for STALE_WINDOW, fees, and slippage.

## Decision

### 1) Signal source: Polymarket event probabilities

We use **Polymarket** prediction‑market data as the external signal. Polymarket exposes real‑time event probabilities via a public API that does not require authentication for reads.

**Why Polymarket:**
- Public, permissionless data — no API key needed for read access.
- Probabilities are market‑derived and continuously updated.
- Well‑documented REST + WebSocket APIs.
- Aligns with the Chainlink CRE "Prediction Markets" hackathon track.

### 2) Selected market: "Will Ethereum dip to $1,600?" (February 2026)

**Decision date:** 2025‑02‑07T20:00Z

**Market details:**

| Field            | Value                                                              |
|-----------------|--------------------------------------------------------------------|
| Event           | "What price will Ethereum hit in February?" (Feb 1–28, 2026)       |
| Market question | "Will Ethereum dip to $1,600?"                                     |
| Condition ID    | `0xa2e0e21aab2d6dbdae148134b816c461b6582d216fdc2a783a107b44018713ee` |
| CLOB Token (Yes)| `82121777749417734370177233650828079004582489419890469190956844628489628493771` |
| CLOB Token (No) | `40411130812261238538407619417947282474287451254294139346128479972921715636297` |
| Resolution      | Binance ETH/USDT 1‑minute candles, Feb 1–28 2026                  |
| Liquidity       | ~$35k at time of selection                                         |
| Current price   | **0.2245** (22.45% probability) at time of selection               |

**API endpoint:**
```
GET https://gamma-api.polymarket.com/markets?condition_id=0xa2e0e21aab2d6dbdae148134b816c461b6582d216fdc2a783a107b44018713ee
```

The CRE workflow reads `outcomePrices[0]` (the "Yes" outcome price) as the probability `p`.

**Why this market:**

We surveyed all active ETH price markets under the February 2026 event. Markets for dips to $2,600, $2,400, $2,200, $2,000, and $1,800 had already resolved YES (ETH had already traded below those levels). The remaining active downside markets:

| Market               | Probability | Liquidity |
|---------------------|-------------|-----------|
| Dip to $1,600       | 22.45%      | $35k      |
| Dip to $1,400       | 13.70%      | $39k      |
| Dip to $1,200       | 4.65%       | $49k      |
| Dip to $1,000       | 1.05%       | —         |
| Dip to $800         | 1.20%       | $56k      |

**"Dip to $1,600" was selected because:**
- It is the nearest unresolved downside level — its probability is the most sensitive to ETH price movements.
- At 22.45%, it sits in a range where further ETH weakness would push it higher (into Amber/Red), giving us live tier transitions.
- It has sufficient liquidity for the probability to be meaningful.
- The $1,400 and lower markets have probabilities too low to produce realistic tier transitions during a demo window.

### 3) Tier thresholds (recalibrated)

The original generic thresholds (0.30 / 0.60) were designed for an abstract probability space. After selecting the $1,600 dip market, we recalibrated to match the observed probability dynamics of ETH downside markets.

**Observation:** ETH dip markets operate in the 0.01–0.30 probability range under normal conditions. A probability of 0.60 would represent an extreme crash scenario where the market is nearly certain ETH will fall below $1,600 — at that point, the price has likely already crashed. The original thresholds would keep us in Green almost permanently, making the risk tier useless.

**Recalibrated thresholds:**

| Tier    | Probability range    | Interpretation                                    |
|---------|---------------------|---------------------------------------------------|
| Green   | p < 0.10            | Low crash probability — business as usual          |
| Amber   | 0.10 ≤ p < 0.25     | Elevated risk — market pricing in meaningful downside |
| Red     | p ≥ 0.25            | High crash probability — significant downside expected |

**Rationale for 0.10 / 0.25:**
- **0.10 (Green→Amber):** A 10% dip probability signals the market is starting to price in real downside risk. Below 10%, the event is considered unlikely — normal background noise.
- **0.25 (Amber→Red):** A 25% probability means 1‑in‑4 chance of a crash to $1,600. This is a serious warning. At current levels (22.45%), we are in Amber — a realistic and useful signal.
- The range gives us meaningful tier distribution: Green during calm, Amber during uncertainty, Red during active selloffs.

**Edge cases:**
- Exactly 0.10 → Amber.
- Exactly 0.25 → Red.
- Signal unavailable (API error) → CRE does not update; staleness kicks in.

These thresholds are configurable via CRE workflow environment variables (`THRESHOLD_GREEN_MAX`, `THRESHOLD_AMBER_MAX`) and can be tuned post‑deployment without redeploying contracts.

### 4) STALE_WINDOW

**Value: 300 seconds (5 minutes)**

**Rationale:**
- Polymarket prices update frequently (seconds to minutes).
- A 5‑minute window is generous enough to tolerate occasional CRE delays.
- Short enough that stale signals don't persist during fast‑moving markets.
- Matches expected CRE polling interval of 60 seconds with a 5× buffer.

**Staleness escalation:**
- If stored tier is Green and signal is stale → effective tier becomes **Amber**.
- If stored tier is Amber and signal is stale → effective tier becomes **Red**.
- If stored tier is Red and signal is stale → stays **Red**.

### 5) Dynamic fees per tier

| Tier   | Dynamic fee (hundredths of bip) | Human‑readable | Purpose                           |
|--------|--------------------------------|----------------|-----------------------------------|
| Green  | 3000                           | 0.30%          | Standard v4 fee tier              |
| Amber  | 10000                          | 1.00%          | LP‑protection surcharge           |
| Red    | N/A (swap blocked)             | N/A            | Full block; no execution          |

**Rationale:**
- Green uses the standard 0.30% fee tier (most liquid ETH/USDC tier on v4).
- Amber triples the fee to discourage toxic flow while still allowing swaps. The 1.00% surcharge compensates LPs for increased adverse‑selection risk.
- Red blocks entirely. During high‑risk windows, the priority is protecting LPs from toxic flow; traders can wait for the tier to drop.

### 6) Pool selection strategy (MVP)

**Single pool.** The MVP uses one ETH/USDC pool on Arbitrum Sepolia with the PredictionHook attached.

- No multi‑pool routing for MVP.
- "Routing" is expressed through the hook's dynamic fee and blocking behavior, not by switching between pools.
- The hook is the enforcement layer; the router simply executes swaps through the single pool.

**Post‑MVP:** Add multiple pools with different fee tiers. The router reads the effective tier and selects the pool (e.g., Green → low‑fee pool, Amber → high‑fee pool).

### 7) Target chain

**Arbitrum Sepolia (chain ID 421614)**

**Why:**
- Supported by both Uniswap v4 and Chainlink CRE.
- Supported by the Arbitrum Open House hackathon.
- Low‑cost testnet for rapid iteration.
- Free faucet ETH and USDC available.

**RPC:** `https://sepolia-rollup.arbitrum.io/rpc`
**Explorer:** `https://sepolia.arbiscan.io`

### 8) Key addresses (Arbitrum Sepolia)

| Contract           | Address                                      |
|-------------------|----------------------------------------------|
| PoolManager        | `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317` |
| UniversalRouter    | `0xefd1d4bd4cf1e86da286bb4cb1b8bced9c10ba47` |
| PositionManager    | `0xAc631556d3d4019C95769033B5E719dD77124BAc` |
| StateView          | `0x9d467fa9062b6e9b1a46e26007ad82db116c67cb` |
| PoolSwapTest       | `0xf3a39c86dbd13c45365e57fb90fe413371f65af8` |
| Permit2            | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| WETH               | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73` |
| USDC (Circle)      | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |

## Consequences

- **Positive:** Thresholds calibrated to real market dynamics. At current probability (22.45%), we start in Amber — demonstrating the system is actively routing based on live signal. Tier transitions will occur naturally with ETH price movements.
- **Negative:** Single market dependency; if the February event resolves or the market becomes illiquid, signal quality degrades. Mitigated by staleness fallback. Post‑February, switch to the next month's market.
- **Trade‑off:** Lower thresholds (0.10/0.25) mean the system is more sensitive to market signals. This is appropriate for a downside‑dip market where probabilities are naturally low.

## Alternatives considered

1. **Chainlink Data Feeds (ETH/USD price):** Reliable, but provides price, not risk classification. Would need additional logic to derive a tier from price movement, which adds complexity.
2. **Volatility index (e.g., on‑chain realized vol):** More direct risk signal but harder to source on‑chain in real time. Better suited for post‑MVP.
3. **Multi‑source composite:** Combine Polymarket + vol + price. Overkill for MVP; adds latency and complexity.
4. **Generic thresholds (0.30/0.60):** Would keep us in Green almost permanently on dip markets. Rejected in favor of market‑calibrated thresholds.
5. **Lower dip markets ($1,400, $1,200):** Probabilities too low (4–14%) to produce meaningful tier transitions during a demo window. The $1,600 market has the highest and most responsive probability.
