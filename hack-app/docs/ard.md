# ARD — Architecture Decision Record

## Decision: Hook‑Centric Design for MVP

**Date:** 2025‑02‑07
**Status:** Accepted

### Context

We need a risk‑aware execution layer for ETH/USDC on Uniswap v4. Two approaches were considered:

1. **Router‑only:** A custom router reads RiskSignal and decides whether/how to execute. The pool itself is unaware of risk.
2. **Hook‑centric:** A v4 hook attached to the pool enforces risk policy on every swap. A thin router provides the user‑facing entry point.

### Decision

**Hook‑centric (option 2).** The `PredictionHook` is the enforcement layer. It reads `RiskSignal.getEffectiveTier()` in `beforeSwap` and:

- Green → allows swap at base fee (0.30%).
- Amber → allows swap at surcharge fee (1.00%).
- Red → reverts (`SwapBlockedRedTier`).

A `PredictionRouter` provides user‑facing swap execution but does not make routing decisions — the hook enforces policy regardless of which router is used.

### Rationale

- **Composability:** Any contract or EOA that swaps through the pool gets the same protection. No bypass via alternative routers.
- **Hackathon fit:** Both the Uniswap and Chainlink hackathons reward hook usage and onchain enforcement.
- **Simplicity:** Single pool, single hook, single signal contract. No multi‑pool routing logic needed for MVP.
- **Auditability:** Tier decisions are enforced and emitted onchain via hook events.

### Consequences

- The hook must be deployed at an address satisfying v4's flag‑mining requirements (address encodes hook permissions).
- Dynamic fees require the pool to be initialized with the `DYNAMIC_FEE` flag.
- Red‑tier blocking is absolute — no override. Acceptable for MVP; post‑MVP can add whitelisting or partial blocks.

---

## Decision: Arbitrum Sepolia as Target Chain

**Date:** 2025‑02‑07
**Status:** Accepted

### Context

The project targets three hackathons: Uniswap, Chainlink CRE, and Arbitrum Open House. We need a chain supported by all three ecosystems.

### Decision

**Arbitrum Sepolia (chain ID 421614).**

### Rationale

- Uniswap v4 is deployed on Arbitrum Sepolia.
- Chainlink CRE supports Arbitrum Sepolia.
- Arbitrum Open House requires deployment on an Arbitrum chain.
- Free testnet ETH and USDC available via faucets.

---

## Decision: Polymarket as Signal Source

**Date:** 2025‑02‑07
**Status:** Accepted

See [ADR‑001](./adr-001-signal-source-and-thresholds.md) for full details on signal source, thresholds, and parameter values.

---

## Primary Objectives (MVP)

- Publish an onchain **risk tier** for ETH/USDC using a CRE workflow + Polymarket signal.
- Enforce tier‑based swap policy via a **Uniswap v4 hook** (dynamic fees + blocking).
- Demonstrate different execution outcomes across Green/Amber/Red tiers.

## Secondary Objectives (post‑MVP)

- Multi‑pair support (expand beyond ETH/USDC).
- Multi‑pool routing with splitting and fallback.
- Dynamic thresholds (risk tiering from multiple signals).
- LP‑side features: slippage bands, extra fees, MEV rebates during Red tiers.
- Production‑grade monitoring: latency, stale‑signal alarms, audit logs.
