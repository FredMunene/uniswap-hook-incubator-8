# Prediction Risk Tier Workflow (CRE)

This workflow fetches a Polymarket market signal and publishes a risk tier update to the onchain `RiskSignal` contract.

## Current behavior
- Entry point: `main.ts` (CRE SDK workflow).
- Configuration is read from `config.staging.json` / `config.production.json`.
- Secrets are defined in `../secrets.yaml`.

## Required config values (in config.*.json)
- `schedule`
- `polymarketConditionId`
- `riskSignalAddress` (receiver contract address, e.g. `RiskSignalReceiver`)
- `chainSelectorName`
- `gasLimit`
- `thresholdGreenMax`
- `thresholdAmberMax`

## Onchain receiver
This workflow writes reports to a receiver contract (e.g., `RiskSignalReceiver`) that forwards
`setTier(uint8,uint16)` to `RiskSignal`. Set the `RiskSignal` updater to the receiver address.

## Install deps
```
bun install --cwd ./my-workflow
```

## CRE simulate (dry run)
```
cre workflow simulate my-workflow
```

Note: For CRE simulation, ensure `project.yaml` and `workflow.yaml` are set and config files are populated.
