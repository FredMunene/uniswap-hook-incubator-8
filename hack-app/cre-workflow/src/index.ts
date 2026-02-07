import { loadConfig } from "./config";
import { fetchMarket } from "./polymarket";
import { classifyTier, TIER_LABELS } from "./classify";
import { RiskSignalPublisher } from "./publisher";

async function cycle(config: ReturnType<typeof loadConfig>, publisher: RiskSignalPublisher): Promise<void> {
    const timestamp = new Date().toISOString();

    try {
        // Step 1: Fetch signal
        const market = await fetchMarket(config.polymarketConditionId);

        if (!market.active) {
            console.log(JSON.stringify({
                timestamp,
                marketId: config.polymarketConditionId,
                status: "skipped",
                error: "Market is resolved or inactive",
            }));
            return;
        }

        // Step 2: Classify tier
        const { tier, confidence } = classifyTier(
            market.probability,
            config.thresholdGreenMax,
            config.thresholdAmberMax
        );

        // Step 3: Publish on-chain
        const result = await publisher.publish(tier, confidence);

        // Step 4: Log result
        console.log(JSON.stringify({
            timestamp,
            marketId: config.polymarketConditionId,
            question: market.question,
            probability: market.probability,
            tier,
            tierLabel: TIER_LABELS[tier],
            confidence,
            txHash: result.txHash,
            gasUsed: result.gasUsed.toString(),
            status: "success",
        }));
    } catch (err) {
        console.error(JSON.stringify({
            timestamp,
            marketId: config.polymarketConditionId,
            error: err instanceof Error ? err.message : String(err),
            status: "error",
        }));
    }
}

async function main(): Promise<void> {
    const config = loadConfig();
    const publisher = new RiskSignalPublisher(
        config.rpcUrl,
        config.updaterPrivateKey,
        config.riskSignalAddress
    );

    console.log(`CRE Workflow started`);
    console.log(`  Updater: ${publisher.address}`);
    console.log(`  RiskSignal: ${config.riskSignalAddress}`);
    console.log(`  Market: ${config.polymarketConditionId}`);
    console.log(`  Thresholds: Green < ${config.thresholdGreenMax}, Amber < ${config.thresholdAmberMax}`);
    console.log(`  Poll interval: ${config.pollIntervalMs}ms`);

    const runOnce = process.argv.includes("--once");

    // Run first cycle immediately
    await cycle(config, publisher);

    if (runOnce) {
        console.log("Single run complete (--once mode)");
        return;
    }

    // Poll loop
    setInterval(() => cycle(config, publisher), config.pollIntervalMs);
}

main().catch((err) => {
    console.error("Fatal error:", err);
    process.exit(1);
});
