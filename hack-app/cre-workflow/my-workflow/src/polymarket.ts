import type { HTTPSendRequester } from "@chainlink/cre-sdk";
import type { Config } from "./config";

const CLOB_API_BASE = "https://clob.polymarket.com";

export interface MarketData {
    probability: number;
    active: number; // 1 = active, 0 = inactive (for consensus aggregation)
}

/// Fetch market data from Polymarket CLOB API using the CRE HTTP capability.
export function fetchMarket(sendRequester: HTTPSendRequester, config: Config): MarketData {
    const url = `${CLOB_API_BASE}/markets/${config.polymarketConditionId}`;
    const response = sendRequester.sendRequest({ method: "GET", url }).result();

    if (response.statusCode !== 200) {
        throw new Error(`Polymarket API error: ${response.statusCode}`);
    }

    const market = JSON.parse(Buffer.from(response.body).toString("utf-8")) as Record<string, unknown>;

    if (!market.condition_id) {
        throw new Error(`No market found for condition_id: ${config.polymarketConditionId}`);
    }

    const tokens = market.tokens as Array<{ outcome: string; price: number }> | undefined;
    const yesToken = tokens?.find((t) => t.outcome === "Yes");
    const probability = yesToken?.price ?? 0;

    if (isNaN(probability) || probability < 0 || probability > 1) {
        throw new Error(`Invalid probability value: ${probability}`);
    }

    const active = market.active === true && market.closed === false ? 1 : 0;

    return { probability, active };
}
