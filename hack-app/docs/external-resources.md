# External Resources

Consolidated reference links, contract addresses, APIs, and documentation.

## Arbitrum Sepolia (Chain ID 421614)

### Network

| Property     | Value                                      |
|-------------|---------------------------------------------|
| Chain ID     | 421614                                      |
| RPC (primary)| `https://sepolia-rollup.arbitrum.io/rpc`   |
| RPC (backup) | `https://arbitrum-sepolia-rpc.publicnode.com`|
| Explorer     | https://sepolia.arbiscan.io                 |
| Currency     | ETH (testnet)                               |

### Faucets

| Resource          | URL                                |
|------------------|------------------------------------|
| Arbitrum Sepolia ETH | https://arbitrum.faucet.dev/    |
| Arbitrum Sepolia ETH | https://faucet.quicknode.com/arbitrum/sepolia |
| USDC (Circle)     | https://faucet.circle.com/        |
| Ethereum Sepolia (to bridge) | https://sepoliafaucet.com/ |

### Uniswap v4 Contracts (Arbitrum Sepolia)

| Contract              | Address                                      |
|----------------------|----------------------------------------------|
| PoolManager           | `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317` |
| UniversalRouter       | `0xefd1d4bd4cf1e86da286bb4cb1b8bced9c10ba47` |
| PositionManager       | `0xAc631556d3d4019C95769033B5E719dD77124BAc` |
| StateView             | `0x9d467fa9062b6e9b1a46e26007ad82db116c67cb` |
| V4Quoter              | `0x7de51022d70a725b508085468052e25e22b5c4c9` |
| PoolSwapTest          | `0xf3a39c86dbd13c45365e57fb90fe413371f65af8` |
| PoolModifyLiquidityTest| `0x9a8ca723f5dccb7926d00b71dec55c2fea1f50f7`|
| Permit2               | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

Source: https://docs.uniswap.org/contracts/v4/deployments

### Token Addresses (Arbitrum Sepolia)

| Token | Address                                      | Source         |
|-------|----------------------------------------------|----------------|
| WETH  | `0x980B62Da83eFf3D4576C647993b0c1D7faf17c73` | Arbitrum bridge|
| USDC  | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` | Circle official|

## Chainlink CRE

| Resource                 | URL                                           |
|-------------------------|-----------------------------------------------|
| CRE documentation        | https://docs.chain.link/cre                   |
| Supported networks (TS)  | https://docs.chain.link/cre/supported-networks-ts |
| Hackathon hub            | https://chain.link/hackathon                  |
| Hackathon prizes         | https://chain.link/hackathon/prizes           |

**Arbitrum Sepolia** is a confirmed supported testnet for CRE.

## Uniswap v4

| Resource                | URL                                           |
|------------------------|-----------------------------------------------|
| v4 deployments          | https://docs.uniswap.org/contracts/v4/deployments |
| Hooks overview          | https://docs.uniswap.org/concepts/protocol/hooks |
| v4‑core GitHub          | https://github.com/Uniswap/v4-core           |
| v4‑periphery GitHub     | https://github.com/Uniswap/v4-periphery      |
| Builder toolkit         | https://uniswaplabs.notion.site/hackmoney     |

## Polymarket

| Resource              | URL                                              |
|----------------------|--------------------------------------------------|
| Data feeds docs       | https://docs.polymarket.com/developers/market-makers/data-feeds |
| CLOB API              | https://clob.polymarket.com/                     |
| Market endpoint       | `GET https://clob.polymarket.com/markets/{MARKET_ID}` |

## Arbitrum

| Resource              | URL                                              |
|----------------------|--------------------------------------------------|
| Developer docs        | https://docs.arbitrum.io/                        |
| Contract addresses    | https://docs.arbitrum.io/build-decentralized-apps/reference/contract-addresses |
| Arbitrum SDK          | https://github.com/OffchainLabs/arbitrum-sdk     |

## Academic / Reference

| Resource                          | URL                                    |
|----------------------------------|----------------------------------------|
| LVR paper (Arxiv 2208.06046)     | https://arxiv.org/abs/2208.06046       |
| Uniswap FLAIR                    | https://uniswap.org/flair.pdf          |
| SEC Rule 605 execution quality   | https://www.sec.gov/newsroom/press-releases/2024-32 |
| Prediction markets (NBER)        | https://www.nber.org/papers/w12083     |
| Implementation shortfall          | https://en.wikipedia.org/wiki/Implementation_shortfall |

## Our Deployed Contracts (to be filled post‑deploy)

| Contract          | Address | Deploy tx | Date |
|------------------|---------|-----------|------|
| RiskSignal        | TBD     | TBD       | TBD  |
| PredictionHook    | TBD     | TBD       | TBD  |
| PredictionRouter  | TBD     | TBD       | TBD  |
| ETH/USDC Pool     | TBD     | TBD       | TBD  |
