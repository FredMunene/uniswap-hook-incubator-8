# Deployment Guide — Prediction-Informed Router

Step-by-step guide to deploy the full system on Arbitrum Sepolia.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed (`forge`, `cast`)
- Node.js 18+ and npm
- A funded wallet on Arbitrum Sepolia (ETH for gas + WETH + USDC for liquidity)

## 1. Fund the Deployer Wallet

### Get Arbitrum Sepolia ETH

Use any faucet to get testnet ETH:
- https://arbitrum.faucet.dev/
- https://faucet.quicknode.com/arbitrum/sepolia

You need ~0.05 ETH for deployment + liquidity wrapping.

### Get USDC

Mint test USDC from Circle's faucet:
- https://faucet.circle.com/ (select Arbitrum Sepolia)

### Derive private key from mnemonic (if needed)

```bash
cast wallet derive-private-key "<your mnemonic>" 0
# Verify it matches your address:
cast wallet address <private-key>
```

### Wrap ETH to WETH

The WETH on Arbitrum Sepolia supports standard `deposit()`:

```bash
cast send 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73 "deposit()" \
  --value 10000000000000000 \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --private-key $DEPLOYER_PRIVATE_KEY
```

This wraps 0.01 ETH into WETH.

### Verify balances

```bash
RPC=https://sepolia-rollup.arbitrum.io/rpc
WALLET=<your-address>

# ETH
cast balance $WALLET --rpc-url $RPC --ether

# WETH (18 decimals)
cast call 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73 \
  "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC

# USDC (6 decimals)
cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC
```

## 2. Configure Environment

Create `hack-app/contracts/.env`:

```env
DEPLOYER_PRIVATE_KEY=0x_YOUR_PRIVATE_KEY
```

## 3. Install Dependencies

```bash
cd hack-app/contracts
forge install
```

If dependencies are already present in `lib/`, skip this step.

## 4. Build Contracts

```bash
forge build
```

Verify all three contracts compile without errors:
- `src/RiskSignal.sol`
- `src/PredictionHook.sol`
- `src/PredictionRouter.sol`

## 5. Run Tests

```bash
forge test -vv
```

All 21 tests should pass.

## 6. Deploy to Arbitrum Sepolia

```bash
forge script script/Deploy.s.sol \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --broadcast -vvv
```

The deploy script performs four operations in sequence:

| Step | Operation | Details |
|------|-----------|---------|
| 1 | Deploy RiskSignal | Updater = deployer, staleWindow = 300s |
| 2 | Deploy PredictionHook | CREATE2 address mining for `BEFORE_SWAP_FLAG` (bit 7) |
| 3 | Initialize pool | USDC/WETH, `DYNAMIC_FEE_FLAG` (0x800000), tickSpacing=60 |
| 4 | Deploy PredictionRouter | Configured with PoolManager + PoolKey |

The script outputs all deployed addresses. Record them.

### What the deploy script does under the hood

1. **RiskSignal**: Standard CREATE deploy. The deployer becomes both `owner` and `updater`.
2. **PredictionHook**: Uses `HookMiner.find()` to grind a CREATE2 salt that produces an address with the `BEFORE_SWAP_FLAG` (bit 7 = 0x0080) set in the low 14 bits. The CREATE2 Deployer Proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`) is the deployer for address computation.
3. **Pool initialization**: Calls `PoolManager.initialize()` with `fee = DYNAMIC_FEE_FLAG` so the hook can override fees per swap. Initialized at tick 0 (sqrtPriceX96 = 2^96, 1:1 price ratio).
4. **PredictionRouter**: Standard CREATE deploy with the PoolKey baked in.

## 7. Seed Pool with Liquidity

After deployment, the pool exists but has no liquidity. Use the Uniswap v4 `PoolModifyLiquidityTest` helper (pre-deployed on Arbitrum Sepolia).

### Approve tokens

```bash
RPC=https://sepolia-rollup.arbitrum.io/rpc
PK=$DEPLOYER_PRIVATE_KEY
POOL_MODIFY_LIQ=0x9a8ca723f5dccb7926d00b71dec55c2fea1f50f7

# Approve USDC
cast send 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "approve(address,uint256)" $POOL_MODIFY_LIQ 20000000 \
  --rpc-url $RPC --private-key $PK

# Approve WETH
cast send 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73 \
  "approve(address,uint256)" $POOL_MODIFY_LIQ 10000000000000000 \
  --rpc-url $RPC --private-key $PK
```

### Add liquidity

```bash
# Replace HOOK_ADDRESS with your deployed PredictionHook address
HOOK=0x5CD3508356402e4b3D7E60E7DFeb75eBC8414080

cast send $POOL_MODIFY_LIQ \
  "modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)" \
  "(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d,0x980B62Da83eFf3D4576C647993b0c1D7faf17c73,8388608,60,$HOOK)" \
  "(-600,600,100000000,0x0000000000000000000000000000000000000000000000000000000000000000)" \
  "0x" \
  --rpc-url $RPC --private-key $PK
```

Parameters explained:
- **PoolKey**: (USDC, WETH, 8388608=DYNAMIC_FEE_FLAG, tickSpacing=60, hook)
- **tickLower=-600, tickUpper=600**: 10 tick spacings on each side of tick 0
- **liquidityDelta=100000000**: Amount of liquidity units
- **salt=0**: Default position salt

## 8. Verify Deployment

```bash
RPC=https://sepolia-rollup.arbitrum.io/rpc

# Check RiskSignal effective tier (should be Green=0, not stale)
cast call $RISK_SIGNAL_ADDRESS \
  "getEffectiveTier()(uint8,bool)" --rpc-url $RPC

# Check RiskSignal updater
cast call $RISK_SIGNAL_ADDRESS \
  "updater()(address)" --rpc-url $RPC

# Check PredictionHook's riskSignal address
cast call $PREDICTION_HOOK_ADDRESS \
  "riskSignal()(address)" --rpc-url $RPC

# Check PredictionHook's poolManager address
cast call $PREDICTION_HOOK_ADDRESS \
  "poolManager()(address)" --rpc-url $RPC
```

## 9. Configure CRE Workflow

```bash
cd hack-app/cre-workflow
cp .env.example .env
```

Edit `.env` and set:
- `RISK_SIGNAL_ADDRESS` — your deployed RiskSignal address
- `UPDATER_PRIVATE_KEY` — the deployer's private key (deployer = updater by default)

Then install and run:

```bash
npm install
npm run dev          # Continuous polling (every 60s)
npm run simulate     # Single run
```

## 10. Execute Demo Swaps

### Green tier swap (default state)

```bash
# Swap using PoolSwapTest helper (pre-deployed)
POOL_SWAP_TEST=0xf3a39c86dbd13c45365e57fb90fe413371f65af8

# Approve tokens to PoolSwapTest first
cast send 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "approve(address,uint256)" $POOL_SWAP_TEST 1000000 \
  --rpc-url $RPC --private-key $PK
```

### Manually set tier for demo

```bash
# Set Amber tier (tier=1, confidence=1500 bps)
cast send $RISK_SIGNAL_ADDRESS \
  "setTier(uint8,uint16)" 1 1500 \
  --rpc-url $RPC --private-key $PK

# Set Red tier (tier=2, confidence=3000 bps)
cast send $RISK_SIGNAL_ADDRESS \
  "setTier(uint8,uint16)" 2 3000 \
  --rpc-url $RPC --private-key $PK

# Reset to Green (tier=0, confidence=500 bps)
cast send $RISK_SIGNAL_ADDRESS \
  "setTier(uint8,uint16)" 0 500 \
  --rpc-url $RPC --private-key $PK
```

## Current Deployment (2026-02-07)

| Contract | Address | Arbiscan |
|----------|---------|----------|
| RiskSignal | `0x7EA6F46b1005B1356524148CDDE4567192301B6e` | [View](https://sepolia.arbiscan.io/address/0x7EA6F46b1005B1356524148CDDE4567192301B6e) |
| PredictionHook | `0x5CD3508356402e4b3D7E60E7DFeb75eBC8414080` | [View](https://sepolia.arbiscan.io/address/0x5CD3508356402e4b3D7E60E7DFeb75eBC8414080) |
| PredictionRouter | `0xA2f89e0e429861602AC731FEa0855d7D8ba7C152` | [View](https://sepolia.arbiscan.io/address/0xA2f89e0e429861602AC731FEa0855d7D8ba7C152) |

### Deploy Transactions

| Operation | Tx Hash |
|-----------|---------|
| RiskSignal deploy | [`0x0961...6ff3`](https://sepolia.arbiscan.io/tx/0x09614794c2c00293e1deb81f2e6cbcaf3c79eebf5a88fcc118abc1ae175f6ff3) |
| PredictionHook deploy (CREATE2) | [`0xe201...1701`](https://sepolia.arbiscan.io/tx/0xe201e45dc873cc0aaddeb98682968eda654d621c2a097cea31bc7f8f49301701) |
| Pool initialize | [`0x815f...f80c`](https://sepolia.arbiscan.io/tx/0x815fcf8c39927e0075498304962bc21daa180dafaea6e10e279f70fd7c1af80c) |
| PredictionRouter deploy | [`0x883b...49b5`](https://sepolia.arbiscan.io/tx/0x883bb10644e34a69f12931d66e6bd2c1368cbffcd58ca0ff0ae46f518a6d49b5) |
| Seed liquidity | [`0x382c...dde1`](https://sepolia.arbiscan.io/tx/0x382c9e2ecc3a35884047928c2146c4552e5390720de3d4d7d1d06b44a8addde1) |

### External Contracts Used

| Contract | Address |
|----------|---------|
| PoolManager | `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317` |
| WETH | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73` |
| USDC | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| PoolModifyLiquidityTest | `0x9a8ca723f5dccb7926d00b71dec55c2fea1f50f7` |
| PoolSwapTest | `0xf3a39c86dbd13c45365e57fb90fe413371f65af8` |
| CREATE2 Deployer Proxy | `0x4e59b44847b379578588920cA78FbF26c0B4956C` |

## Troubleshooting

### Hook deploy reverts with `HookAddressNotValid`

The CREATE2 address doesn't have the correct permission bits. This happens when the HookMiner uses the wrong deployer address. In forge scripts, `new Contract{salt: salt}(...)` goes through the CREATE2 Deployer Proxy at `0x4e59b44847b379578588920cA78FbF26c0B4956C`, not the EOA.

**Fix:** Ensure `HookMiner.find()` uses `0x4e59b44847b379578588920cA78FbF26c0B4956C` as the deployer, not `msg.sender`.

### Pool initialize reverts

- Check that `fee = 8388608` (DYNAMIC_FEE_FLAG = 0x800000)
- Check that the hook address has `BEFORE_SWAP_FLAG` set (bit 7 in low 14 bits)
- Ensure the pool hasn't been initialized already (cannot initialize twice)

### `SwapBlockedRedTier` revert

The RiskSignal tier is Red (either set directly or escalated via staleness). Check:
```bash
cast call $RISK_SIGNAL_ADDRESS "getEffectiveTier()(uint8,bool)" --rpc-url $RPC
```

### Stale tier escalation

If no `setTier` call is made within 300 seconds (5 min), the effective tier escalates:
- Green → Amber
- Amber → Red
- Red → Red (stays Red)

To reset, call `setTier` again with the desired tier.
