export enum Tier {
    Green = 0,
    Amber = 1,
    Red = 2,
}

export const TIER_LABELS: Record<Tier, string> = {
    [Tier.Green]: "Green",
    [Tier.Amber]: "Amber",
    [Tier.Red]: "Red",
};

export interface Classification {
    tier: Tier;
    confidence: number; // basis points (0–10000)
}

/// Classify a probability into a risk tier.
/// Thresholds are calibrated for ETH downside-dip markets (see ADR-001).
export function classifyTier(
    probability: number,
    greenMax: number,
    amberMax: number
): Classification {
    const confidence = Math.round(probability * 10000);
    if (probability < greenMax) return { tier: Tier.Green, confidence };
    if (probability < amberMax) return { tier: Tier.Amber, confidence };
    return { tier: Tier.Red, confidence };
}
