# Metrics & Evidence (Prediction‑Informed Routing)

This doc lists the metrics to evaluate a prediction‑informed router and links to public references that define or motivate those metrics.

## 1) Execution quality (user‑side)
Goal: show the router improves realized execution vs a baseline route.

**Core metrics**
- **Effective spread**: execution price vs midpoint of best quotes.
- **Realized spread**: execution price vs midpoint after a short delay; proxies adverse selection.
- **Price improvement / slippage**: deviation from quoted price at decision time.
- **Implementation shortfall**: decision price vs execution price (standard trading‑cost metric).
- **Time‑to‑execution**: routing/settlement latency.

**References**
- SEC Rule 605 execution‑quality metrics (effective/realized spreads, speed):
  - https://www.sec.gov/newsroom/press-releases/2024-32
  - https://www.sec.gov/rules-regulations/2001/03/disclosure-order-execution-routing-practices
- Implementation shortfall overview:
  - https://en.wikipedia.org/wiki/Implementation_shortfall

## 2) LP impact / toxic flow
Goal: show the router reduces adverse‑selection cost to LPs without collapsing volume.

**Core metrics**
- **LVR (Loss‑Versus‑Rebalancing)**: measures LP losses from price movements and arbitrage.
- **Fee APR vs LVR**: net LP profitability after adverse selection.
- **Volume share during high‑risk windows**: shows how much flow is filtered or rerouted.

**References**
- LVR paper (Arxiv 2208.06046):
  - https://arxiv.org/abs/2208.06046
- Uniswap FLAIR (LP competitiveness + returns):
  - https://uniswap.org/flair.pdf

## 3) Prediction signal quality
Goal: show the signal is useful as a *risk tier* input (not a perfect price forecast).

**Core metrics**
- **Calibration / Brier score** for event‑probability forecasts.
- **Signal stability / update latency** (time to reflect new info).
- **Policy response accuracy** (did the router choose safer routes during high‑risk tiers?).

**References**
- Prediction markets as forecast aggregators (NBER):
  - https://www.nber.org/papers/w12083
  - https://www.nber.org/papers/w12200

## 4) Router policy metrics (product‑level)
Goal: show the system is transparent and not overly restrictive.

**Core metrics**
- **Reroute rate**: % of swaps routed away from baseline.
- **Block rate**: % of swaps blocked (should be low and justified).
- **Tier distribution**: time spent in green/amber/red.
- **User savings**: realized improvement vs baseline route.

## 5) Data sources for signals (example)
If using Polymarket as the signal source:
- Data feeds & WebSocket docs:
  - https://docs.polymarket.com/developers/market-makers/data-feeds

## Suggested evaluation setup
- **A/B test**: baseline router vs prediction‑informed router.
- **Hold constant**: liquidity, pool set, and slippage settings.
- **Report**: effective spread, implementation shortfall, LVR, and reroute/block rates.
