# Chainlink CRE Hackathon — Tracks, Prizes, Requirements (Updated)

## Event
- **Name:** Convergence: A Chainlink Hackathon
- **Dates:** Feb 6 – Mar 1
- **Core requirement:** Use a CRE Workflow as an orchestration layer that integrates at least one blockchain with an external API/system/data source/LLM/AI agent, and show a successful simulation via CRE CLI or a live CRE deployment.

## Prize Tracks (Main)
### DeFi & Tokenization — **$20,000**
- 1st: **$12,000**
- 2nd: **$8,000**
- Examples: stablecoin issuance, tokenized asset servicing, custom Proof of Reserve feeds.

### CRE & AI — **$17,000**
- 1st: **$10,500**
- 2nd: **$6,500**
- Examples: AI agents consuming CRE workflows with x402 payments, AI‑assisted CRE workflows.

### Prediction Markets — **$16,000**
- 1st: **$10,000**
- 2nd: **$6,000**
- Focus: decentralized prediction/forecasting apps with verifiable market resolution.

### Risk & Compliance — **$16,000**
- 1st: **$10,000**
- 2nd: **$6,000**
- Focus: monitoring, safeguards, automated controls, reserve health checks.

### Privacy — **$16,000**
- 1st: **$10,000**
- 2nd: **$6,000**
- Focus: Confidential HTTP and/or private transactions for privacy‑preserving workflows.

### Top 10 Projects — **$15,000 total**
- **$1,500 x 10** for runner‑up projects using CRE.

## Additional Partner / Special Tracks
- **Best use of World ID with CRE — $5,000** (1st $3,000; 2nd $1,500; 3rd $500)
- **Best usage of CRE within a World Mini App — $5,000** (1st $3,000; 2nd $1,500; 3rd $500)
- **Build CRE workflows with Tenderly Virtual TestNets — $5,000** (1st $2,500; 2nd $1,750; 3rd $750)
- **thirdweb x CRE** — non‑cash rewards (free months of Scale/Growth plans)

## Submission Requirements (apply broadly)
- Build/simulate/deploy a CRE workflow that integrates onchain + external data/AI.
- **3–5 minute public demo video** showing workflow execution or CLI simulation.
- **Public source repo** (e.g., GitHub).
- **README** linking all files that use Chainlink.
- Past projects are not accepted unless updated with new components.

## Links
- Prizes & tracks: https://chain.link/hackathon/prizes
- Event hub: https://chain.link/hackathon
- CRE docs: https://docs.chain.link/cre

## Submission Form Fields

- **Logo:** (upload project logo)
- **Project name:** Prediction-Informed Router
- **1‑line description (80–100 chars):** Uniswap v4 hook that adjusts swap fees in real time using Polymarket prediction signals via CRE
- **Full description (what it is / how it works / problem it solves):**
  - What it is: A Uniswap v4 dynamic-fee hook on Arbitrum Sepolia that reads a live prediction market signal to enforce risk-tier-based swap policy — low fees when risk is low, higher fees when risk rises, and full swap blocking when risk is critical.
  - How it works: A Chainlink CRE workflow polls Polymarket's CLOB API every 60 seconds for the probability of "Will ETH dip to $1,600?", classifies it into Green/Amber/Red tiers, and publishes the tier on-chain to a RiskSignal contract via writeReport. The Uniswap v4 PredictionHook reads this tier in beforeSwap and returns a dynamic fee override (0.30% for Green, 1.00% for Amber) or reverts the swap entirely on Red. A 5-minute staleness window auto-escalates tiers if the CRE workflow stops updating, ensuring fail-safe behavior.
  - Problem solved: DeFi liquidity providers and swappers have no way to react to off-chain risk signals in real time. This hook bridges prediction market intelligence directly into swap execution policy, protecting users during adverse market conditions without requiring manual intervention.
- **How is it built?** Solidity smart contracts (Foundry) for RiskSignal, PredictionHook (IHooks), PredictionRouter (IUnlockCallback), and RiskSignalReceiver (IReceiver). CRE TypeScript workflow using CronCapability, HTTPClient (Polymarket CLOB API), and EVMClient (writeReport). Deployed on Arbitrum Sepolia with CREATE2-mined hook address for beforeSwap permission bit. All 24 Foundry tests pass. CRE simulation succeeds end-to-end.
- **Challenges encountered:** Hook address mining requires the CREATE2 Deployer Proxy (0x4e59...56C) as the deployer in HookMiner, not the EOA — forge scripts route CREATE2 through this proxy. BaseHook was removed from v4-periphery, so we implement IHooks directly with no-op stubs for unused callbacks. The Polymarket Gamma API doesn't reliably filter by condition_id, so we switched to the CLOB API which returns correct market data.
- **Project repo link:** (your GitHub URL)
- **Chainlink usage:** CRE workflow as the orchestration layer — CronCapability triggers every 60s, HTTPClient fetches Polymarket probability, classify logic maps probability to risk tier, EVMClient writeReport publishes setTier(tier, confidence) to RiskSignalReceiver on Arbitrum Sepolia.
- **Link to code showing Chainlink usage:** (your GitHub URL)/hack-app/cre-workflow/my-workflow/main.ts
- **Project demo video link (<= 5 min):** (your video URL)
- **Chainlink prize track(s):** Prediction Markets (primary), Risk & Compliance (secondary)
- **Sponsor track(s):** Arbitrum
- **Submitter name:** (your name)
- **Submitter email:** (your email)
- **Team or individual:** (individual / team)

Notes:
- Demo video is required and must be **under 5 minutes**.
- Provide a **direct link** to the code showing CRE usage.

## Track Fit for This Project
**Project:** Prediction‑Informed Router for Uniswap v4

**Qualifies for CRE?** Yes — if a CRE workflow fetches external prediction data and writes an onchain risk signal used by the router/hook.

**Best‑fit track:**
- **Prediction Markets** (primary)

**Also applicable (optional):**
- **Risk & Compliance** (risk tiering, safeguards)
- **CRE & AI** (only if using agents/LLMs for signal classification)
