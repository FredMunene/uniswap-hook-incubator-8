import {
    bytesToHex,
    ConsensusAggregationByFields,
    type CronPayload,
    CronCapability,
    handler,
    hexToBase64,
    median,
    Runner,
    type Runtime,
    TxStatus,
    EVMClient,
    HTTPClient,
    encodeCallMsg,
    getNetwork,
} from "@chainlink/cre-sdk";
import { encodeFunctionData } from "viem";

import { configSchema, type Config } from "./src/config";
import { fetchMarket } from "./src/polymarket";
import { classifyTier, TIER_LABELS } from "./src/classify";

const RISK_SIGNAL_ABI = [
    {
        type: "function",
        name: "setTier",
        inputs: [
            { name: "tier", type: "uint8" },
            { name: "confidence", type: "uint16" },
        ],
        outputs: [],
    },
] as const;

const onCronTrigger = (runtime: Runtime<Config>, _payload: CronPayload): string => {
    const httpClient = new HTTPClient();
    const market = httpClient
        .sendRequest(
            runtime,
            fetchMarket,
            ConsensusAggregationByFields({
                probability: median,
                active: median,
            }),
        )(runtime.config)
        .result();

    if (market.active < 0.5) {
        runtime.log("Market inactive or resolved. Skipping update.");
        return "skipped";
    }

    const { tier, confidence } = classifyTier(
        market.probability,
        runtime.config.thresholdGreenMax,
        runtime.config.thresholdAmberMax,
    );

    const network = getNetwork({
        chainFamily: "evm",
        chainSelectorName: runtime.config.chainSelectorName,
        isTestnet: true,
    });

    if (!network) {
        throw new Error(`Network not found: ${runtime.config.chainSelectorName}`);
    }

    const evmClient = new EVMClient(network.chainSelector.selector);

    const callData = encodeFunctionData({
        abi: RISK_SIGNAL_ABI,
        functionName: "setTier",
        args: [tier, confidence],
    });

    const report = runtime
        .report({
            encodedPayload: hexToBase64(callData),
            encoderName: "evm",
            signingAlgo: "ecdsa",
            hashingAlgo: "keccak256",
        })
        .result();

    const resp = evmClient
        .writeReport(runtime, {
            receiver: runtime.config.riskSignalAddress,
            report,
            gasConfig: { gasLimit: runtime.config.gasLimit },
        })
        .result();

    if (resp.txStatus !== TxStatus.SUCCESS) {
        throw new Error(`writeReport failed: ${resp.errorMessage || resp.txStatus}`);
    }

    const txHash = bytesToHex(resp.txHash || new Uint8Array(32));

    runtime.log(
        `Tier=${TIER_LABELS[tier]} probability=${market.probability} confidence=${confidence} tx=${txHash}`,
    );

    return txHash;
};

const initWorkflow = (config: Config) => {
    const cronTrigger = new CronCapability();

    return [
        handler(
            cronTrigger.trigger({
                schedule: config.schedule,
            }),
            onCronTrigger,
        ),
    ];
};

export async function main() {
    const runner = await Runner.newRunner<Config>({
        configSchema,
    });

    await runner.run(initWorkflow);
}

main().catch((err) => {
    // eslint-disable-next-line no-console
    console.error(err);
    process.exit(1);
});
