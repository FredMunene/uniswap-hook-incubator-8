// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Hooks} from "v4-core/libraries/Hooks.sol";

/// @title HookMiner
/// @notice Minimal library for mining hook addresses with desired permission flags via CREATE2.
library HookMiner {
    uint160 constant FLAG_MASK = Hooks.ALL_HOOK_MASK;
    uint256 constant MAX_LOOP = 160_444;

    /// @notice Find a salt that produces a hook address with the desired `flags`.
    /// @param deployer The address deploying the hook. In tests: `address(this)`. In scripts: CREATE2 Deployer Proxy.
    /// @param flags The desired permission flags, e.g. `uint160(Hooks.BEFORE_SWAP_FLAG)`.
    /// @param creationCode The hook contract creation code, e.g. `type(PredictionHook).creationCode`.
    /// @param constructorArgs The encoded constructor arguments.
    /// @return hookAddress The address the hook will deploy to.
    /// @return salt The salt to use with `new Hook{salt: salt}(...)`.
    function find(address deployer, uint160 flags, bytes memory creationCode, bytes memory constructorArgs)
        internal
        view
        returns (address hookAddress, bytes32 salt)
    {
        flags = flags & FLAG_MASK;
        bytes memory creationCodeWithArgs = abi.encodePacked(creationCode, constructorArgs);

        for (uint256 s; s < MAX_LOOP; s++) {
            hookAddress = computeAddress(deployer, s, creationCodeWithArgs);
            if (uint160(hookAddress) & FLAG_MASK == flags && hookAddress.code.length == 0) {
                return (hookAddress, bytes32(s));
            }
        }
        revert("HookMiner: could not find salt");
    }

    /// @notice Precompute a CREATE2 address.
    function computeAddress(address deployer, uint256 salt, bytes memory creationCodeWithArgs)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xFF), deployer, salt, keccak256(creationCodeWithArgs)))))
        );
    }
}
