// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import {Test} from "forge-std/Test.sol";
 
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
 
import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
 
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
 
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
 
import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
 
import "forge-std/console.sol";
import {PointsHook} from "../src/PointsHook.sol";
 
contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {
 
	MockERC20 token; // our token to use in the ETH-TOKEN pool
 
	// Native tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));
	Currency tokenCurrency;
 
	PointsHook hook;
 
    function setUp() public {
        // 1. Deploy an instance of PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // 2. Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency =  Currency.wrap(address(token));

        // 3. Mint a bunch of TOKEN to ourselves and to address(1)
        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);

        // 4. Deploy hook to an address that has proper flag set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo("PointsHook.sol", abi.encode(manager), address(flags));

        // 5. Deploy our hook
        hook = PointsHook(address(flags));

        // 6. Approve router to pull tokens for liquidity
        token.approve(address(modifyLiquidityRouter), type(uint256).max);

        // 7. Initialize the ETH/TOKEN pool and add liquidity
        (key,) = initPoolAndAddLiquidityETH(
            ethCurrency,
            tokenCurrency,
            hook,
            3000,
            SQRT_PRICE_1_1,
            1 ether
        );
    }


    function test_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(
        address(this),
        poolIdUint
    );

    // Set user address in hook data
    bytes memory hookData = abi.encode(address(this));

    // Now we swap
    // We will swap 0.001 ether for tokens
    // We should get 20% of 0.001 * 10**18 points
    // = 2 * 10**14

    swapRouter.swap{value: 0.001 ether}(
        key,
        SwapParams({
            zeroForOne: true,
            amountSpecified: -0.001 ether, // Exact input for output swap
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
    );

    uint256 pointsBalanceAfterSwap = hook.balanceOf(
        address(this),
        poolIdUint
    );
    assertEq(pointsBalanceAfterSwap - pointsBalanceOriginal, 2 * 10 ** 14);

    }
 
}
