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

## Our Deployed Contracts (Arbitrum Sepolia)

Deployed: 2026-02-07

| Contract          | Address                                      | Tx Hash |
|------------------|----------------------------------------------|---------|
| RiskSignal        | `0x7EA6F46b1005B1356524148CDDE4567192301B6e` | [`0x0961...6ff3`](https://sepolia.arbiscan.io/tx/0x09614794c2c00293e1deb81f2e6cbcaf3c79eebf5a88fcc118abc1ae175f6ff3) |
| PredictionHook    | `0x5CD3508356402e4b3D7E60E7DFeb75eBC8414080` | [`0xe201...1701`](https://sepolia.arbiscan.io/tx/0xe201e45dc873cc0aaddeb98682968eda654d621c2a097cea31bc7f8f49301701) |
| Pool Initialize   | PoolManager                                   | [`0x815f...f80c`](https://sepolia.arbiscan.io/tx/0x815fcf8c39927e0075498304962bc21daa180dafaea6e10e279f70fd7c1af80c) |
| PredictionRouter  | `0xA2f89e0e429861602AC731FEa0855d7D8ba7C152` | [`0x883b...49b5`](https://sepolia.arbiscan.io/tx/0x883bb10644e34a69f12931d66e6bd2c1368cbffcd58ca0ff0ae46f518a6d49b5) |

**Pool config:** USDC/WETH, fee = `DYNAMIC_FEE_FLAG` (0x800000), tickSpacing = 60, hook = PredictionHook
