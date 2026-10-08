// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IERC20View {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/*
 * U03 — USDtbMinting <-> USDtb PSM Cross-Contract Invariant Probe
 *
 * PURPOSE:
 *   Local-fork-only diagnostic harness.
 *   This test does NOT claim a vulnerability.
 *
 * REQUIRED ENV VARS:
 *   ETHENA_FORK_RPC
 *   U03_PSM
 *   U03_USDTB
 *   U03_COLLATERAL
 *   U03_SWAP_CALL
 *
 * SAFETY:
 *   - No broadcast.
 *   - No live transaction.
 *   - Execution occurs only inside a Foundry local fork.
 *   - Do not point this at a live execution/broadcast path.
 *
 * IMPORTANT:
 *   The current USDtb PSM ABI has not been independently established
 *   in this repository. Therefore the test deliberately accepts generic
 *   ABI-encoded calldata instead of inventing a function signature.
 */

contract U03CrossContractInvariantProbe is Test {

    function test_U03_LocalFork_PSMAccountingProbe() external {

        string memory rpc = vm.envString("ETHENA_FORK_RPC");

        address psm =
            vm.envAddress("U03_PSM");

        address usdtb =
            vm.envAddress("U03_USDTB");

        address collateral =
            vm.envAddress("U03_COLLATERAL");

        bytes memory callData =
            vm.envBytes("U03_SWAP_CALL");

        require(
            psm.code.length > 0,
            "U03: PSM has no bytecode"
        );

        require(
            usdtb.code.length > 0,
            "U03: USDtb has no bytecode"
        );

        require(
            collateral.code.length > 0,
            "U03: collateral has no bytecode"
        );

        require(
            callData.length >= 4,
            "U03: missing calldata"
        );

        /*
         * Create an isolated local fork.
         *
         * Nothing here broadcasts a transaction.
         */
        uint256 forkId =
            vm.createFork(rpc);

        vm.selectFork(forkId);

        /*
         * Capture state BEFORE the simulated PSM call.
         */
        uint256 supplyBefore =
            IERC20View(usdtb).totalSupply();

        uint256 psmUsdTbBefore =
            IERC20View(usdtb).balanceOf(psm);

        uint256 psmCollateralBefore =
            IERC20View(collateral).balanceOf(psm);

        emit log_named_uint(
            "U03 supplyBefore",
            supplyBefore
        );

        emit log_named_uint(
            "U03 psmUsdTbBefore",
            psmUsdTbBefore
        );

        emit log_named_uint(
            "U03 psmCollateralBefore",
            psmCollateralBefore
        );

        /*
         * Execute the supplied PSM call ONLY inside the local fork.
         */
        (bool ok, bytes memory ret) =
            psm.call(callData);

        /*
         * Revert is not automatically a vulnerability.
         * We simply record it as a failed transition.
         */
        if (!ok) {

            emit log(
                "U03 RESULT: supplied PSM call reverted on local fork"
            );

            emit log_bytes(ret);

            return;
        }

        /*
         * Capture state AFTER the simulated transition.
         */
        uint256 supplyAfter =
            IERC20View(usdtb).totalSupply();

        uint256 psmUsdTbAfter =
            IERC20View(usdtb).balanceOf(psm);

        uint256 psmCollateralAfter =
            IERC20View(collateral).balanceOf(psm);

        emit log_named_uint(
            "U03 supplyAfter",
            supplyAfter
        );

        emit log_named_uint(
            "U03 psmUsdTbAfter",
            psmUsdTbAfter
        );

        emit log_named_uint(
            "U03 psmCollateralAfter",
            psmCollateralAfter
        );

        /*
         * Core diagnostic invariant:
         *
         * If the PSM increases USDtb total supply,
         * there should be a corresponding collateral-side
         * accounting transition.
         *
         * This is only a diagnostic invariant.
         * It is NOT by itself sufficient to establish
         * a bounty-eligible vulnerability.
         */
        if (supplyAfter > supplyBefore) {

            uint256 supplyDelta =
                supplyAfter - supplyBefore;

            uint256 collateralIncrease = 0;

            if (
                psmCollateralAfter >
                psmCollateralBefore
            ) {

                collateralIncrease =
                    psmCollateralAfter -
                    psmCollateralBefore;
            }

            emit log_named_uint(
                "U03 supplyDelta",
                supplyDelta
            );

            emit log_named_uint(
                "U03 collateralIncrease",
                collateralIncrease
            );

            /*
             * If this fails, investigate the exact transition.
             *
             * It is NOT yet a confirmed vulnerability.
             */
            assertGt(
                collateralIncrease,
                0,
                "U03 ALERT: USDtb supply increased without PSM collateral increase"
            );
        }

        emit log(
            "U03 RESULT: local-fork accounting transition completed"
        );

        emit log(
            "U03 STATUS: DIAGNOSTIC_ONLY_NOT_A_CONFIRMED_FINDING"
        );
    }
}
