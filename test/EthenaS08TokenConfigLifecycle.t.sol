// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract EthenaS08TokenConfigLifecycle is Test {
    address constant ATTACKER = address(0xA11CE);

    /*
     * S08 OBJECTIVE
     *
     * Test remove -> re-add / configuration lifecycle on an isolated fork.
     *
     * We are NOT testing:
     * - known FULL_RESTRICTED approval bypass
     * - known benefactor re-add resurrection
     * - known unsafe downcast
     * - live/mainnet execution
     *
     * We are looking specifically for a NEW invariant break where:
     *
     *   removeSupportedAsset(asset)
     *          ->
     *   addSupportedAsset(asset)
     *
     * leaves stale state that an UNPRIVILEGED attacker can exploit.
     *
     * Candidate stale state:
     * - oracle configuration
     * - mint/redeem limits
     * - fee configuration
     * - custodian mapping
     * - asset enabled state
     * - decimal/scaling configuration
     * - authorization state
     */

    function test_S08_RemoveReadd_StaleStateProbe() external {
        string memory rpc = vm.envString("ETHENA_FORK_RPC");

        address target = vm.envAddress("S08_TARGET");
        address asset = vm.envAddress("S08_ASSET");

        require(target.code.length > 0, "S08: target has no bytecode");
        require(asset.code.length > 0, "S08: asset has no bytecode");

        uint256 forkId = vm.createFork(rpc);
        vm.selectFork(forkId);

        emit log("S08: isolated fork selected");
        emit log_named_address("S08 target", target);
        emit log_named_address("S08 asset", asset);

        /*
         * Snapshot state before attempting any lifecycle transition.
         */
        uint256 supplyBefore = IERC20Like(asset).totalSupply();
        uint256 attackerBefore = IERC20Like(asset).balanceOf(ATTACKER);

        emit log_named_uint("S08 asset supply before", supplyBefore);
        emit log_named_uint("S08 attacker balance before", attackerBefore);

        /*
         * IMPORTANT:
         *
         * We intentionally do NOT impersonate an admin here.
         *
         * The first question is whether an unprivileged caller can
         * directly trigger a lifecycle transition or otherwise reach
         * stale configuration.
         */
        vm.prank(ATTACKER);

        (bool ok, bytes memory ret) =
            target.call(
                abi.encodeWithSignature(
                    "removeSupportedAsset(address)",
                    asset
                )
            );

        if (ok) {
            emit log(
                "S08 ALERT: unprivileged caller reached removeSupportedAsset"
            );
        } else {
            emit log(
                "S08: removeSupportedAsset correctly rejected unprivileged caller"
            );
            emit log_bytes(ret);
        }

        /*
         * No vulnerability is claimed merely because the call succeeds
         * or fails. We need a complete permissionless value-impact path.
         */
        uint256 supplyAfter = IERC20Like(asset).totalSupply();
        uint256 attackerAfter = IERC20Like(asset).balanceOf(ATTACKER);

        emit log_named_uint(
            "S08 asset supply after",
            supplyAfter
        );

        emit log_named_uint(
            "S08 attacker balance after",
            attackerAfter
        );

        if (attackerAfter > attackerBefore) {
            emit log(
                "S08 ALERT: attacker balance increased"
            );
        }

        if (supplyAfter != supplyBefore) {
            emit log(
                "S08: token supply changed during lifecycle probe"
            );
        }

        emit log(
            "S08 STATUS: TRIAGE_ONLY — EXACT CURRENT ABI/STATE TRANSITION REQUIRED"
        );
    }
}
