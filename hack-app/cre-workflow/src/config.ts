export interface Config {
    polymarketConditionId: string;
    riskSignalAddress: string;
    rpcUrl: string;
    updaterPrivateKey: string;
    thresholdGreenMax: number;
    thresholdAmberMax: number;
    pollIntervalMs: number;
}

export function loadConfig(): Config {
    const required = (key: string): string => {
        const val = process.env[key];
        if (!val) throw new Error(`Missing required env var: ${key}`);
        return val;
    };

    return {
        polymarketConditionId: required("POLYMARKET_CONDITION_ID"),
        riskSignalAddress: required("RISK_SIGNAL_ADDRESS"),
        rpcUrl: required("ARBITRUM_SEPOLIA_RPC"),
        updaterPrivateKey: required("UPDATER_PRIVATE_KEY"),
        thresholdGreenMax: parseFloat(process.env.THRESHOLD_GREEN_MAX ?? "0.10"),
        thresholdAmberMax: parseFloat(process.env.THRESHOLD_AMBER_MAX ?? "0.25"),
        pollIntervalMs: parseInt(process.env.POLL_INTERVAL_MS ?? "60000", 10),
    };
}
