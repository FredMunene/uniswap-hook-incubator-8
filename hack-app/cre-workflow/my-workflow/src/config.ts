import { z } from "zod";

export const configSchema = z.object({
    schedule: z.string(),
    polymarketConditionId: z.string(),
    riskSignalAddress: z.string(),
    chainSelectorName: z.string(),
    gasLimit: z.string(),
    thresholdGreenMax: z.number().min(0).max(1),
    thresholdAmberMax: z.number().min(0).max(1),
});

export type Config = z.infer<typeof configSchema>;
