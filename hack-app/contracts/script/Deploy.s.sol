// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

import {RiskSignal} from "../src/RiskSignal.sol";
import {PredictionHook} from "../src/PredictionHook.sol";
import {PredictionRouter} from "../src/PredictionRouter.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

/// @title Deploy
/// @notice Deploys RiskSignal, PredictionHook (mined address), initializes pool, and deploys PredictionRouter.
contract Deploy is Script {
    // ── Arbitrum Sepolia addresses ─────────────────────────────────────────
    address constant POOL_MANAGER = 0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317;
    address constant WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
    address constant USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    // ── Config ─────────────────────────────────────────────────────────────
    uint64 constant STALE_WINDOW = 300; // 5 minutes
    int24 constant TICK_SPACING = 60;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address updater = vm.envOr("UPDATER_ADDRESS", deployer);

        console.log("Deployer:", deployer);
        console.log("Updater:", updater);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy RiskSignal
        RiskSignal riskSignal = new RiskSignal(updater, STALE_WINDOW);
        console.log("RiskSignal deployed at:", address(riskSignal));

        // 2. Mine hook address and deploy PredictionHook
        IPoolManager poolManager = IPoolManager(POOL_MANAGER);
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory constructorArgs = abi.encode(poolManager, riskSignal);

        (address hookAddress, bytes32 salt) =
            HookMiner.find(deployer, flags, type(PredictionHook).creationCode, constructorArgs);
        console.log("Mining hook address:", hookAddress);

        PredictionHook hook = new PredictionHook{salt: salt}(poolManager, riskSignal);
        require(address(hook) == hookAddress, "Hook address mismatch");
        console.log("PredictionHook deployed at:", address(hook));

        // 3. Initialize pool with dynamic fee flag
        // Token ordering: currency0 < currency1 by address
        (address token0, address token1) = WETH < USDC ? (WETH, USDC) : (USDC, WETH);

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });

        // Initialize at 1:1 price (tick 0). Adjust sqrtPriceX96 for actual ETH/USDC ratio if needed.
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);
        poolManager.initialize(poolKey, sqrtPriceX96);
        console.log("Pool initialized with dynamic fee flag");

        // 4. Deploy PredictionRouter
        PredictionRouter router = new PredictionRouter(poolManager, poolKey);
        console.log("PredictionRouter deployed at:", address(router));

        vm.stopBroadcast();

        // Summary
        console.log("--- Deployment Summary ---");
        console.log("RiskSignal:      ", address(riskSignal));
        console.log("PredictionHook:  ", address(hook));
        console.log("PredictionRouter:", address(router));
        console.log("Pool token0:     ", token0);
        console.log("Pool token1:     ", token1);
    }
}
