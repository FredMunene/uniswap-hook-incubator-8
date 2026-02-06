# Prediction‑Informed Router — Evidence & Claims

## Do we need to prove prediction markets affect price movement?
**Short answer:** No. You don’t need to prove prediction markets *cause* price moves. You only need to show the signal **improves routing decisions** (risk‑aware execution).

## What you *do* need to show
- The signal changes routing behavior in a **transparent, measurable** way.
- The new routing **improves execution** vs a baseline router (e.g., better realized price, lower slippage, fewer bad fills).
- Your policy is **consistent and auditable** (tiers, thresholds, fallback behavior).

## Why this is sufficient
Your system is a **risk filter**, not a price‑prediction oracle. The value comes from:
- avoiding toxic flow during high‑risk windows
- steering trades to safer/deeper pools
- optional guardrails (slippage caps, block rules)

You can demonstrate value with **A/B tests**:
- Baseline: normal routing
- Variant: prediction‑informed routing
- Metrics: realized price, slippage, variance, user‑side cost, LP adverse selection

## Practical framing for the hackathon
- “We do not claim to predict price. We use prediction market signals to classify risk tiers and improve execution quality.”
- “We prove improvement with measurable metrics, not causal claims about prediction markets.”
