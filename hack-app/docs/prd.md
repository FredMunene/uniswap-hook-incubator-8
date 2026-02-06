# PRD — Prediction‑Informed Router (Uniswap v4)

## Problem
Routers optimize for best quoted price only. In volatile periods, the best quote can be the worst execution due to adverse selection and rapid price moves.

## Goal
Provide a risk‑aware router that uses external prediction signals to improve execution quality and protect LPs during high‑risk windows.

## Target users
- Traders who want more reliable execution under volatility.
- LPs who want reduced toxic flow.

## Non‑goals (MVP)
- Multi‑pair or multi‑chain routing.
- Full UI.
- Perfect price prediction.

## MVP scope
- Single pair: ETH/USDC.
- Risk tiers: green / amber / red.
- Policy:
  - Green: best quote routing.
  - Amber: prefer safer/deeper pool + tighter slippage.
  - Red: reroute to safest pool or block.
- Onchain `RiskSignal` contract updated by CRE workflow.
- Router consumes `RiskSignal` and executes swaps.
- Demo: show swaps under different tiers.

## Success criteria
- Demonstrate different routing decisions across tiers.
- Show measurable improvement vs baseline in at least one metric (e.g., slippage or effective spread in a controlled demo).
- Provide clear, auditable tier decisions onchain.

## Risks & mitigations
- **Signal latency** → fallback to safe default if stale.
- **Over‑blocking** → keep red tier strict but rare.
- **Liquidity fragmentation** → start with one pool and document limitations.

## Deliverables
- Contracts: `RiskSignal`, `Router` (and optional hook).
- CRE workflow to fetch and publish risk tier.
- README + demo video.
