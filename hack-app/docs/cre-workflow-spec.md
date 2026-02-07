# CRE Workflow Specification

## Overview

A Chainlink CRE (Compute, Read, Execute) workflow that fetches prediction‑market data from Polymarket, classifies it into a risk tier, and publishes the result on‑chain to the `RiskSignal` contract on Arbitrum Sepolia.

## Workflow identity

- **Name:** `prediction-risk-tier`
- **Language:** TypeScript (CRE SDK)
- **Trigger:** Time‑based polling (every 60 seconds)
- **Target chain:** Arbitrum Sepolia (421614)

## Steps

### Step 1 — Fetch signal (Compute/Read)

**Source:** Polymarket REST API

**Selected market:** "Will Ethereum dip to $1,600?" (February 2026)
**Condition ID:** `0xa2e0e21aab2d6dbdae148134b816c461b6582d216fdc2a783a107b44018713ee`
**CLOB Token (Yes):** `82121777749417734370177233650828079004582489419890469190956844628489628493771`

**Endpoint:**
```
GET https://gamma-api.polymarket.com/markets?condition_id=0xa2e0e21aab2d6dbdae148134b816c461b6582d216fdc2a783a107b44018713ee
```

**Fields used:**
- `outcomePrices[0]` — probability of the "Yes" outcome (0.00–1.00)
- Market must be active (not resolved)

**Example response (relevant fields):**
```json
{
  "condition_id": "0xa2e0e21aab2d6dbdae148134b816c461b6582d216fdc2a783a107b44018713ee",
  "question": "Will Ethereum dip to $1,600?",
  "outcomePrices": ["0.2245", "0.7755"],
  "active": true
}
```

The relevant probability is `outcomePrices[0]` (the "Yes" outcome — probability ETH dips to $1,600).

### Step 2 — Classify tier (Compute)

Apply fixed thresholds to the probability `p`:

```typescript
function classifyTier(p: number): { tier: 0 | 1 | 2; confidence: number } {
  const confidence = Math.round(p * 10000); // bps
  if (p < 0.10) return { tier: 0, confidence }; // Green
  if (p < 0.25) return { tier: 1, confidence }; // Amber
  return { tier: 2, confidence };                // Red
}
```

**Thresholds (environment variables):**

Calibrated for ETH downside‑dip markets (see [ADR‑001](./adr-001-signal-source-and-thresholds.md)).

| Variable               | Default | Description                    |
|-----------------------|---------|--------------------------------|
| `THRESHOLD_GREEN_MAX` | 0.10    | Below this → Green             |
| `THRESHOLD_AMBER_MAX` | 0.25    | Below this (and ≥ green) → Amber |
| `POLYMARKET_CONDITION_ID`| `0xa2e0...13ee` | Market condition ID to monitor |

### Step 3 — Publish on‑chain (Execute)

**Target contract:** `RiskSignal` on Arbitrum Sepolia

**Function call:**
```solidity
RiskSignal.setTier(uint8 tier, uint16 confidence)
```

**Transaction parameters:**
- Gas limit: 100,000 (generous for a single SSTORE + event)
- Gas price: use Arbitrum Sepolia defaults (~0.1 gwei L2)

**Signer:** CRE workflow EOA (must be set as `updater` on RiskSignal)

### Step 4 — Log result

Log the following for each update cycle:

```json
{
  "timestamp": "2025-02-07T12:00:00Z",
  "marketId": "0x...",
  "probability": 0.45,
  "tier": 1,
  "tierLabel": "Amber",
  "confidence": 4500,
  "txHash": "0x...",
  "status": "success"
}
```

On failure:
```json
{
  "timestamp": "2025-02-07T12:01:00Z",
  "marketId": "0x...",
  "error": "Polymarket API timeout",
  "status": "skipped"
}
```

## Error handling

| Failure mode              | Action                                | Recovery                    |
|--------------------------|---------------------------------------|-----------------------------|
| Polymarket API timeout    | Skip this cycle, log error            | Staleness escalation on‑chain |
| Polymarket API 4xx/5xx   | Skip this cycle, log error            | Staleness escalation on‑chain |
| Market resolved/inactive  | Skip update, log warning              | Manual intervention needed  |
| Invalid probability value | Skip update, log error                | Staleness escalation on‑chain |
| Transaction revert        | Log revert reason                     | Retry next cycle            |
| Insufficient gas          | Log error                             | Manual top‑up needed        |
| RPC unavailable           | Skip this cycle, log error            | Retry next cycle            |

**Key invariant:** On any failure, the workflow does NOT write a stale or incorrect tier. It simply skips the update. The on‑chain `RiskSignal.getEffectiveTier()` staleness mechanism will auto‑escalate to protect users.

## Environment variables

| Variable                  | Required | Description                              |
|--------------------------|----------|------------------------------------------|
| `POLYMARKET_CONDITION_ID`| Yes      | `0xa2e0e21aab2d6dbdae148134b816c461b6582d216fdc2a783a107b44018713ee` |
| `RISK_SIGNAL_ADDRESS`    | Yes      | Deployed RiskSignal contract address     |
| `ARBITRUM_SEPOLIA_RPC`   | Yes      | RPC URL (default: `https://sepolia-rollup.arbitrum.io/rpc`) |
| `UPDATER_PRIVATE_KEY`    | Yes      | Private key of the CRE updater EOA      |
| `THRESHOLD_GREEN_MAX`    | No       | Default: 0.10                            |
| `THRESHOLD_AMBER_MAX`    | No       | Default: 0.25                            |
| `POLL_INTERVAL_MS`       | No       | Default: 60000 (60s)                     |

## CRE CLI simulation

For local testing without deploying:

```bash
# Simulate the workflow
cre simulate --workflow prediction-risk-tier --input '{"marketId": "0x..."}'

# Deploy to CRE
cre deploy --workflow prediction-risk-tier --network arbitrum-sepolia
```

## Monitoring

For the demo, monitor:
- `TierUpdated` events on RiskSignal (via Arbiscan or event listener)
- CRE workflow logs (stdout or CRE dashboard)
- Transaction success/failure on Arbitrum Sepolia explorer
