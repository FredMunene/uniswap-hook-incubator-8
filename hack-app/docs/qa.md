# Q&A — Prediction‑Informed Router

Common questions and design clarifications.

---

## Why WETH and not ETH?

Uniswap v4's `PoolManager` operates on ERC-20 tokens internally. Native ETH is not an ERC-20 — it doesn't have `approve()`, `transferFrom()`, etc. So Uniswap v4 pools use **WETH (Wrapped ETH)**, which is an ERC-20 wrapper around native ETH.

That said, v4 does support native ETH at the **router level** — the `PredictionRouter` (or `UniversalRouter`) can accept native ETH from the user via `msg.value`, wrap it to WETH internally, and then interact with the pool. So from the **user's perspective**, they can send ETH. But the **pool itself** always deals in WETH.

In our docs, "ETH/USDC pool" is shorthand, but the `PoolKey` uses `currency0: WETH` and `currency1: USDC` addresses. The router handles wrap/unwrap transparently.

**WETH address (Arbitrum Sepolia):** `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73`
