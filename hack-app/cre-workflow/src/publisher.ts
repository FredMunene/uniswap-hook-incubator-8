import { ethers } from "ethers";

const RISK_SIGNAL_ABI = [
    "function setTier(uint8 tier, uint16 confidence) external",
    "function getEffectiveTier() external view returns (uint8 tier, bool isStale)",
    "function getTier() external view returns (uint8 tier, uint64 updatedAt, uint16 confidence)",
];

export interface PublishResult {
    txHash: string;
    gasUsed: bigint;
}

export class RiskSignalPublisher {
    private contract: ethers.Contract;
    private wallet: ethers.Wallet;

    constructor(rpcUrl: string, privateKey: string, contractAddress: string) {
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        this.wallet = new ethers.Wallet(privateKey, provider);
        this.contract = new ethers.Contract(contractAddress, RISK_SIGNAL_ABI, this.wallet);
    }

    /// Publish a tier update to RiskSignal.
    async publish(tier: number, confidence: number): Promise<PublishResult> {
        const tx = await this.contract.setTier(tier, confidence, { gasLimit: 100_000 });
        const receipt = await tx.wait();
        return {
            txHash: receipt.hash,
            gasUsed: receipt.gasUsed,
        };
    }

    /// Read the current effective tier from the contract.
    async readEffectiveTier(): Promise<{ tier: number; isStale: boolean }> {
        const [tier, isStale] = await this.contract.getEffectiveTier();
        return { tier: Number(tier), isStale };
    }

    get address(): string {
        return this.wallet.address;
    }
}
