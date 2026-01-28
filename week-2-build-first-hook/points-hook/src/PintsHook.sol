// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
 
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";
 
// import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
 
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
 
import {Hooks} from "v4-core/libraries/Hooks.sol";
 

//  when we are making a tx, if our hook wants to campture the "sender" then we have
//  user -> router -> uniswap v4 -> hook
//  msg.sender - uniswap v4                    X
//  tx.origin - User                           Multisig won'r be correctly attributed
//  'sender' parameter - Router                X
//  IMsgSender(sender).msgSender() - User      This is only supported by some routers
//  hookData - Could be anyone


//  1. make sure this is an ETH - TOKEN pool
//  2. make sure this swap is to buy TOKEN in exchange for ETH
//  3. mint points equal to 20% of amount of ETH being swapped in

contract PointsHook is BaseHook, ERC1155 {
    constructor(
        IPoolManager _manager ) BaseHook(_manager) {}
 
	// Set up hook permissions to return `true`
	// for the two hook functions we are using
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }
 
    // Implement the ERC1155 `uri` function
    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }
 
	// Stub implementation of `afterSwap`
    // hookData =  abi.encode(0x123....);
	function _afterSwap(
        address,
        PoolKey calldata key,
        // SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
		// ZeroForOne 
        //  currency0 is ETH 
        //  currency1 is TOKEN
        //  (True) swapping ETH for TOKEN 
        //  (False) swapping TOKEN for ETH

        //  TODO :  check TOKEN  address

        //  amountSpecified
        //  if amountSpecified < 0 
        //  "exact input for output" swap 
        //  amountSpecified : -10
        //  (True) : user is swapping 10 TOKEN for _x_ ETH
        //  (FALSE) : user is  swapping 10 ETH for _x_ TOKEN

        //  amountSpecified > 0 
        //  "exact output for input" swap
        //  amountSpecified : 10
        //  (True) : user is swapping x_ TOKEN for 10 ETH
        //  (False) : user is swapping x_ ETH for 10 TOKEN




        //  validate that it is  ETH/TOKEN pool
        if (!key.currency0.isAddressZero()){
            return (this.afterSwap.selector, 0);
        }

        //  Mint points equal to 20 % of the amount of ETH they spent
        //  zeroFor One swap (give eth)
        //  if amountSpecified  < 0:
        //      this is an exact input for output
        //      amount of ETH spend is equal to 'amountSpecified'
        //  if amountSpecified > 0:
        //      this is exact output for input
        //      the amount of ETH they spent is equal to BalanceDelta.amount0()

        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 pointsForSwap = ethSpendAmount * 20 / 100;

        // Mint the pints being assigned
        _assignPoints(key.toId(), hookData, pointsForSwap);


		return (this.afterSwap.selector, 0);
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 points
    ) internal {
        //  if no hookData is passed in, no points will be assigned to the user
        if (hookData.length == 0) return;

        //  extract the user address from the hookData
        address user = abi.decode(hookData, (address));
        // if there is hookdataData but not in expected data, or set to zero address, nobody gets any points

        if (user == address(0)) return;
        
        //  Mint the points to the user
        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));

        //  for pool 0 ( a speicific byte32  - 5000 POINTS)
        _mint(user, poolIdUint, points,'');
    }
}