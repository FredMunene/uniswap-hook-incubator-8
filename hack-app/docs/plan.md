# Implementation Plan — Prediction‑Informed Router

## Summary

Build a risk‑aware Uniswap v4 hook for ETH/USDC on **Arbitrum Sepolia** that uses a Chainlink CRE workflow to publish a prediction‑market risk tier (Green/Amber/Red) and enforces tier‑based swap policy (dynamic fees + blocking).

## Confirmed decisions

- **Target chain:** Arbitrum Sepolia (421614)
- **Architecture:** Hook‑centric (PredictionHook enforces policy in `beforeSwap`)
- **Signal source:** Polymarket event probability
- **Tier thresholds:** Green < 0.10, Amber 0.10–0.24, Red ≥ 0.25 (calibrated for ETH $1,600 dip market)
- **STALE_WINDOW:** 300 seconds (5 minutes)
- **Dynamic fees:** Green 0.30%, Amber 1.00%, Red = block
- **CRE language:** TypeScript
- **Pool strategy:** Single ETH/USDC pool with hook attached
- **Demo video:** ≤ 3 minutes (Uniswap limit; Chainlink allows up to 5)

## Checklist

### Phase 0 — Setup

- [x] Confirm Arbitrum Sepolia as target chain
- [x] Confirm RPC URL: `https://sepolia-rollup.arbitrum.io/rpc`
- [x] Fund deployer wallet with Arbitrum Sepolia ETH (faucet: https://arbitrum.faucet.dev/)
- [x] Mint/obtain test USDC (faucet: https://faucet.circle.com/)
- [x] Confirm Polymarket market ID + token ID to monitor
- [x] Choose CRE workflow language: TypeScript

### Phase 1 — Docs & decisions

- [x] Create ADR for signal source + tier thresholds (`adr-001-signal-source-and-thresholds.md`)
- [x] Create Solidity interfaces doc (`interfaces.md`)
- [x] Differentiate ARD vs architecture doc
- [x] Create external resources doc (`external-resources.md`)
- [x] Create CRE workflow spec (`cre-workflow-spec.md`)
- [x] Update specs with concrete values
- [x] Fill in CLAUDE.md
- [ ] Update README with system overview + dependencies

### Phase 2 — Contracts (MVP)

- [x] Initialize Foundry project (`forge init`)
- [x] Install v4‑core and v4‑periphery dependencies
- [x] Implement `RiskSignal` contract (tier + timestamp + access control + staleness)
- [x] Implement `PredictionHook` contract (IHooks, beforeSwap, dynamic fee)
- [x] Implement `PredictionRouter` contract (unlock callback, swap, settle)
- [x] Add NatSpec documentation for all public functions
- [x] Mine hook address with correct `beforeSwap` flag

### Phase 3 — CRE workflow

- [x] Build CRE workflow to fetch Polymarket signal
- [x] Implement threshold logic (probability → tier mapping)
- [x] Publish tier + confidence to `RiskSignal`
- [x] Add logging and error handling
- [ ] Test workflow locally via CRE CLI simulation

### Phase 4 — Tests

- [x] Unit test: `RiskSignal` — access control, setTier, getTier
- [x] Unit test: `RiskSignal` — staleness escalation logic
- [x] Unit test: `PredictionHook` — Green tier allows swap at base fee
- [x] Unit test: `PredictionHook` — Amber tier allows swap at surcharge fee
- [x] Unit test: `PredictionHook` — Red tier reverts swap
- [x] Unit test: `PredictionHook` — stale signal escalation
- [x] Integration test: mock signal update → routed swap end‑to‑end

### Phase 5 — Deploy & demo

- [x] Deploy `RiskSignal` to Arbitrum Sepolia
- [x] Deploy `PredictionHook` to Arbitrum Sepolia (CREATE2 mined address)
- [x] Initialize ETH/USDC pool with hook + dynamic fee flag
- [x] Deploy `PredictionRouter` to Arbitrum Sepolia
- [x] Seed pool with initial liquidity
- [ ] Run CRE workflow to update tier
- [x] Execute swap under Green tier — fee=3000 (0.30%)
- [x] Execute swap under Amber tier — fee=10000 (1.00%)
- [x] Attempt swap under Red tier — reverted with SwapBlockedRedTier
- [x] Record all TxIDs in deployment guide

### Phase 6 — Hackathon deliverables

- [ ] Demo video (≤ 3 min) showing tier changes + swap outcomes
- [ ] README with runbook, TxIDs, and setup instructions
- [ ] Fill Chainlink submission form fields
- [ ] Fill Uniswap submission fields
- [ ] Confirm Arbitrum Open House submission

## Required inputs (pause points)

| Input                        | Status      | Value / Notes                                     |
|-----------------------------|-------------|---------------------------------------------------|
| Arbitrum Sepolia RPC URL     | ✅ Confirmed | `https://sepolia-rollup.arbitrum.io/rpc`          |
| Deployer wallet              | ✅ Funded    | `0xc879982490b3aB07705eF70d165fd13B391e7704`     |
| CRE account credentials      | ⬜ Needed    | Chainlink CRE access                             |
| Polymarket market ID         | ✅ Confirmed | "Will Ethereum dip to $1,600?" — `0xa2e0...13ee`  |
| WETH address (Arb Sepolia)   | ✅ Confirmed | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73`     |
| USDC address (Arb Sepolia)   | ✅ Confirmed | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`     |
| PoolManager (Arb Sepolia)    | ✅ Confirmed | `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317`     |

## Key references

- Uniswap v4 deployments: https://docs.uniswap.org/contracts/v4/deployments
- Chainlink CRE supported networks: https://docs.chain.link/cre/supported-networks-ts
- Hooks are v4‑only; pool must be initialized with `DYNAMIC_FEE_FLAG` for the hook to override fees.
- Hook address must be mined via CREATE2 to encode the `beforeSwap` permission flag.
