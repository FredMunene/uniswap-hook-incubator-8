# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

**Prediction-Informed Router** — A Uniswap v4 hook that uses Chainlink CRE + Polymarket signals to enforce risk-tier-based swap policy (dynamic fees + blocking) on an ETH/USDC pool on Arbitrum Sepolia.

Three contracts:
- **RiskSignal** — On-chain oracle storing risk tier (Green/Amber/Red), updated by CRE workflow.
- **PredictionHook** — v4 hook enforcing tier policy in `beforeSwap` (dynamic fees, Red-tier blocking).
- **PredictionRouter** — User-facing swap execution via `PoolManager.unlock()`.

One off-chain component:
- **CRE Workflow** — TypeScript. Polls Polymarket, classifies risk tier, publishes to RiskSignal.

## Development Commands

### Smart Contracts (Foundry)

```bash
forge build --sizes
forge test -vv
forge test --match-contract "RiskSignal" -vvv
forge test --match-contract "PredictionHook" -vvv
forge test --gas-report
forge coverage --report lcov
```

### CRE Workflow (TypeScript)

```bash
cd cre-workflow/
npm install
npm run build
npm run dev
```

## Architecture

### Hook-Centric Design

- **RiskSignal**: Ownable, single updater EOA. Stores tier + updatedAt + confidence in one slot. `getEffectiveTier()` handles staleness escalation.
- **PredictionHook**: Implements `IHooks` directly (BaseHook removed in latest v4-periphery). Only `beforeSwap` enabled. Reads `RiskSignal.getEffectiveTier()`, returns dynamic fee override. Reverts on Red tier.
- **PredictionRouter**: Implements `IUnlockCallback`. Calls `PoolManager.unlock()` -> `swap()` -> settle/take. Validates slippage + deadline.

### Data Flow

```
Polymarket API -> CRE Workflow -> RiskSignal.setTier()
                                       | (read)
User -> PredictionRouter -> PoolManager -> PredictionHook.beforeSwap()
                                                |
                                       Green: fee 0.30%
                                       Amber: fee 1.00%
                                       Red:   revert
```

## Key Configuration

### Networks

| Network          | Chain ID | RPC                                      |
|-----------------|----------|------------------------------------------|
| Arbitrum Sepolia | 421614   | `https://sepolia-rollup.arbitrum.io/rpc` |
| Local (Anvil)    | 31337    | `http://localhost:8545`                  |

### Key Addresses (Arbitrum Sepolia)

| Contract     | Address                                      |
|-------------|----------------------------------------------|
| PoolManager  | `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317` |
| WETH         | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73` |
| USDC         | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| Permit2      | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

## Testing Conventions

### Solidity Tests

- Location: `test/`
- Naming: `ContractName.t.sol`
- Function naming: `test_OperationName()`, `testFail_OperationName()`, `testFuzz_OperationName()`
- Use `forge-std/Test.sol` for assertions and VM cheatcodes

### TypeScript Tests

- Location: `cre-workflow/src/__tests__/`
- Framework: Jest with ts-jest

## Code Conventions

### Solidity

- Solidity ^0.8.26
- NatSpec on all public/external functions
- Custom errors preferred over require strings
- Events for all state changes
- Line length: 120 characters, 4 space indent

### TypeScript

- Ethers.js v6
- Strict TypeScript (`strict: true`)

## Commit Format

`type: clear_commit_message` — no scope, no parentheses. Types: feat, fix, docs, refactor, test

## Implementation Notes

- Pool must be initialized with `DYNAMIC_FEE_FLAG` for hook fee overrides.
- Hook address must be mined via CREATE2 to encode the `beforeSwap` permission bit.
- Token ordering in PoolKey: `currency0 < currency1` by address.
- `RiskSignal.getEffectiveTier()` escalates stale tiers: Green->Amber, Amber->Red, Red->Red.
- Tier thresholds: Green < 0.10, Amber 0.10-0.24, Red >= 0.25 (calibrated for ETH $1,600 dip market).
