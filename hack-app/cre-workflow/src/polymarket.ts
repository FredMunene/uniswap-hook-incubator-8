const GAMMA_API_BASE = "https://gamma-api.polymarket.com";

export interface MarketData {
    conditionId: string;
    question: string;
    probability: number;
    active: boolean;
}

/// Fetch market data from Polymarket Gamma API.
export async function fetchMarket(conditionId: string): Promise<MarketData> {
    const url = `${GAMMA_API_BASE}/markets?condition_id=${conditionId}`;
    const res = await fetch(url);

    if (!res.ok) {
        throw new Error(`Polymarket API error: ${res.status} ${res.statusText}`);
    }

    const markets = await res.json();
    if (!Array.isArray(markets) || markets.length === 0) {
        throw new Error(`No market found for condition_id: ${conditionId}`);
    }

    const market = markets[0];
    const prices: string[] = JSON.parse(market.outcomePrices ?? "[]");
    const probability = parseFloat(prices[0] ?? "0");

    if (isNaN(probability) || probability < 0 || probability > 1) {
        throw new Error(`Invalid probability value: ${prices[0]}`);
    }

    return {
        conditionId: market.condition_id,
        question: market.question,
        probability,
        active: market.active !== false && !market.closed,
    };
}
