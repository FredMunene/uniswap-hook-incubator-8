// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";

import {PredictionRouter} from "../src/PredictionRouter.sol";

contract MockERC20 is IERC20Minimal {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockPoolManager {
    using CurrencyLibrary for Currency;

    BalanceDelta public nextDelta;
    PoolKey public lastKey;
    SwapParams public lastParams;
    address public lastUnlockCaller;

    Currency public lastSyncCurrency;
    uint256 public lastSettleValue;
    uint256 public settleCount;

    Currency public lastTakeCurrency;
    address public lastTakeTo;
    uint256 public lastTakeAmount;

    function setNextDelta(int128 amount0, int128 amount1) external {
        nextDelta = toBalanceDelta(amount0, amount1);
    }

    function unlock(bytes calldata data) external returns (bytes memory) {
        lastUnlockCaller = msg.sender;
        return IUnlockCallback(msg.sender).unlockCallback(data);
    }

    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata) external returns (BalanceDelta) {
        lastKey = key;
        lastParams = params;
        return nextDelta;
    }

    function sync(Currency currency) external {
        lastSyncCurrency = currency;
    }

    function settle() external payable returns (uint256) {
        lastSettleValue = msg.value;
        settleCount++;
        return msg.value;
    }

    function take(Currency currency, address to, uint256 amount) external {
        lastTakeCurrency = currency;
        lastTakeTo = to;
        lastTakeAmount = amount;

        if (currency.isAddressZero()) {
            payable(to).transfer(amount);
        } else {
            IERC20Minimal(Currency.unwrap(currency)).transfer(to, amount);
        }
    }

    receive() external payable {}
}

contract PredictionRouterTest is Test {
    MockPoolManager private manager;
    MockERC20 private token;
    PredictionRouter private router;

    function setUp() public {
        manager = new MockPoolManager();
        token = new MockERC20();

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(token)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        router = new PredictionRouter(IPoolManager(address(manager)), key);
    }

    function test_swap_revertsOnExpiredDeadline() public {
        vm.expectRevert(PredictionRouter.DeadlineExpired.selector);
        router.swap(true, -1, 0, block.timestamp - 1);
    }

    function test_unlockCallback_revertsIfNotPoolManager() public {
        vm.expectRevert(PredictionRouter.NotPoolManager.selector);
        router.unlockCallback("");
    }

    function test_swap_exactInput_nativeToERC20() public {
        manager.setNextDelta(-int128(1 ether), int128(1000));
        token.mint(address(manager), 1000);

        router.swap{value: 1 ether}(true, -int256(1 ether), 0, block.timestamp + 1);

        assertEq(manager.lastSettleValue(), 1 ether);
        assertEq(token.balanceOf(address(this)), 1000);
        assertEq(manager.lastTakeTo(), address(this));
        assertEq(manager.lastTakeAmount(), 1000);
    }

    function test_swap_exactInput_erc20ToNative() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token)),
            currency1: Currency.wrap(address(0)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        router = new PredictionRouter(IPoolManager(address(manager)), key);

        manager.setNextDelta(-int128(1000), int128(1 ether));
        token.mint(address(this), 1000);
        token.approve(address(router), 1000);
        vm.deal(address(manager), 1 ether);

        uint256 ethBefore = address(this).balance;
        router.swap(true, -int256(1000), 0, block.timestamp + 1);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(manager)), 1000);
        assertEq(Currency.unwrap(manager.lastSyncCurrency()), address(token));
        assertEq(manager.lastSettleValue(), 0);
        assertEq(address(this).balance, ethBefore + 1 ether);
        assertEq(manager.lastTakeTo(), address(this));
        assertEq(manager.lastTakeAmount(), 1 ether);
    }

    function test_swap_refundsExcessEth() public {
        manager.setNextDelta(0, 0);
        vm.deal(address(router), 0.2 ether);

        uint256 before = address(this).balance;
        router.swap{value: 1 ether}(true, -int256(1 ether), 0, block.timestamp + 1);

        assertEq(address(router).balance, 0);
        assertEq(address(this).balance, before + 0.2 ether);
    }

    receive() external payable {}
}
