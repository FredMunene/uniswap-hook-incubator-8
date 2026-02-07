# Prediction-Informed Router

A Uniswap v4 hook that dynamically adjusts swap fees based on live prediction market signals. When the probability of an adverse ETH price event rises, the hook increases fees or blocks swaps entirely — protecting LPs and swappers in real time.

## How It Works

```
Polymarket API ──► CRE Workflow ──► RiskSignal.setTier() on-chain
                                          │ (read)
User ──► PredictionRouter ──► PoolManager ──► PredictionHook.beforeSwap()
                                                    │
                                           Green: fee 0.30%
                                           Amber: fee 1.00%
                                           Red:   swap blocked
```

1. A **Chainlink CRE workflow** polls Polymarket every 60 seconds for the probability of "Will ETH dip to $1,600?"
2. The probability is classified into a risk tier (Green / Amber / Red) and published on-chain to **RiskSignal**
3. When a user swaps through **PredictionHook**, the hook reads the current tier and either applies a dynamic fee or reverts the transaction

### Tier Thresholds

| Probability | Tier | Swap Fee | Rationale |
|-------------|------|----------|-----------|
| < 10% | Green | 0.30% | Low risk — normal trading |
| 10–24% | Amber | 1.00% | Elevated risk — surcharge discourages large swaps |
| >= 25% | Red | Blocked | High risk — swaps reverted to protect users |

### Staleness Escalation

If the CRE workflow fails to update within 5 minutes, tiers automatically escalate (Green → Amber → Red), ensuring the system fails safe.

## Contracts

| Contract | Purpose | Address (Arbitrum Sepolia) |
|----------|---------|---------------------------|
| RiskSignal | On-chain oracle storing risk tier | [`0x7EA6...1B6e`](https://sepolia.arbiscan.io/address/0x7EA6F46b1005B1356524148CDDE4567192301B6e) |
| PredictionHook | v4 hook enforcing tier policy in `beforeSwap` | [`0x5CD3...4080`](https://sepolia.arbiscan.io/address/0x5CD3508356402e4b3D7E60E7DFeb75eBC8414080) |
| PredictionRouter | User-facing swap execution via `PoolManager.unlock()` | [`0xA2f8...7152`](https://sepolia.arbiscan.io/address/0xA2f89e0e429861602AC731FEa0855d7D8ba7C152) |
| RiskSignalReceiver | CRE report decoder → calls `RiskSignal.setTier()` | [`0x0Cdb...4433`](https://sepolia.arbiscan.io/address/0x0CdbE45B99b6f2D1c2CEc65034DA60bA51ef4433) |

## CRE Workflow

The Chainlink CRE workflow lives in [`cre-workflow/my-workflow/`](cre-workflow/my-workflow/).

**Key files:**
- [`main.ts`](cre-workflow/my-workflow/main.ts) — Workflow entry point (CronCapability trigger → HTTP fetch → EVM write)
- [`src/polymarket.ts`](cre-workflow/my-workflow/src/polymarket.ts) — Fetches market data from Polymarket CLOB API
- [`src/classify.ts`](cre-workflow/my-workflow/src/classify.ts) — Probability → tier classification logic
- [`src/config.ts`](cre-workflow/my-workflow/src/config.ts) — Zod config schema
- [`config.staging.json`](cre-workflow/my-workflow/config.staging.json) — Staging config with deployed addresses

**Polymarket market:** [Will Ethereum dip to $1,600 in February?](https://polymarket.com/event/what-price-will-ethereum-hit-in-february-2026) (condition_id: `0xa2e0...13ee`)

## On-Chain Proof

### Deploy Transactions

| Operation | Tx Hash |
|-----------|---------|
| RiskSignal deploy | [`0x0961...6ff3`](https://sepolia.arbiscan.io/tx/0x09614794c2c00293e1deb81f2e6cbcaf3c79eebf5a88fcc118abc1ae175f6ff3) |
| PredictionHook deploy (CREATE2) | [`0xe201...1701`](https://sepolia.arbiscan.io/tx/0xe201e45dc873cc0aaddeb98682968eda654d621c2a097cea31bc7f8f49301701) |
| Pool initialize | [`0x815f...f80c`](https://sepolia.arbiscan.io/tx/0x815fcf8c39927e0075498304962bc21daa180dafaea6e10e279f70fd7c1af80c) |
| PredictionRouter deploy | [`0x883b...49b5`](https://sepolia.arbiscan.io/tx/0x883bb10644e34a69f12931d66e6bd2c1368cbffcd58ca0ff0ae46f518a6d49b5) |
| Seed liquidity | [`0x382c...dde1`](https://sepolia.arbiscan.io/tx/0x382c9e2ecc3a35884047928c2146c4552e5390720de3d4d7d1d06b44a8addde1) |
| RiskSignalReceiver deploy | [`0x8d80...6abe`](https://sepolia.arbiscan.io/tx/0x8d803b9c0b9d3d68b4b4d719d62bda1623159dcffcd72fe9cfc4002d66f46abe) |
| Set updater to receiver | [`0x025a...a616`](https://sepolia.arbiscan.io/tx/0x025a6e688cb63cb7ee7c7d313643b544ee930e2dff0e571d3845df2130d0a616) |

### Demo Swap Results

| Tier | Fee (bps) | USDC Input | WETH Output | Tx |
|------|-----------|------------|-------------|----|
| Green | 3,000 (0.30%) | 100,000 | 99,600 | [`0x7955...768d`](https://sepolia.arbiscan.io/tx/0x795517ad120037d970b28d4f4cd9d20cdcfeddb2ba2d308187b46f8ca3aa768d) |
| Amber | 10,000 (1.00%) | 100,000 | 98,705 | [`0x9557...7ebd`](https://sepolia.arbiscan.io/tx/0x955738e668d3065bf997781356ccc69f3817f96f38fe9cd7c0ee3cbc38437ebd) |
| Red | N/A (blocked) | — | Reverted `SwapBlockedRedTier` | — |

### CRE Workflow Live Run

| Probability | Tier | Confidence | Tx |
|-------------|------|------------|----|
| 27.55% | Red | 2755 bps | [`0xbaed...bf92`](https://sepolia.arbiscan.io/tx/0xbaed99b3d527a5607ae78b9ae63f3bf13689c1f19369fa079da6632e61e0bf92) |

## Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`)
- [Bun](https://bun.sh/) (for CRE workflow)
- [Chainlink CRE CLI](https://cre.chain.link/install.sh) (`cre`)
- Funded wallet on Arbitrum Sepolia

### Build & Test Contracts

```bash
cd hack-app/contracts
forge install
forge build
forge test -vv    # 24 tests pass
```

### Run CRE Simulation

```bash
cd hack-app/cre-workflow
bun install --cwd ./my-workflow
cre workflow simulate my-workflow --target staging-settings
```

### Deploy

See [deployment-guide.md](docs/deployment-guide.md) for the full step-by-step guide.

## Architecture

### RiskSignal

On-chain oracle storing tier (Green/Amber/Red) with packed storage (tier + updatedAt + confidence in one slot). `getEffectiveTier()` applies staleness escalation automatically.

### PredictionHook

Implements `IHooks` directly. Only `beforeSwap` is active. Reads `RiskSignal.getEffectiveTier()` and returns a dynamic fee override using `LPFeeLibrary.OVERRIDE_FEE_FLAG`. Reverts with `SwapBlockedRedTier()` on Red tier.

### PredictionRouter

Implements `IUnlockCallback`. Calls `PoolManager.unlock()` → `swap()` → `settle/take`. Handles both ERC20 and native ETH settlement with slippage + deadline validation.

### RiskSignalReceiver

Minimal `IReceiver` implementation for CRE `writeReport`. Decodes the report payload, validates the `setTier` selector, and forwards the call to RiskSignal.

## Tech Stack

- **Uniswap v4** — Hook framework with dynamic fees
- **Chainlink CRE** — Off-chain workflow orchestration (cron trigger + HTTP + EVM write)
- **Polymarket** — Prediction market signal source (CLOB API)
- **Arbitrum Sepolia** — Deployment chain
- **Foundry** — Smart contract development and testing
- **TypeScript** — CRE workflow language (compiled to WASM)

## Hackathon Tracks

- **Chainlink Convergence** — Prediction Markets track
- **Uniswap Hook Incubator** — Dynamic fee hook
- **Arbitrum Open House** — Deployed on Arbitrum Sepolia
