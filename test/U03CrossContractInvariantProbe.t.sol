// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IERC20U03 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IPSMU03 {
    struct Order {
        bool isSwapForAsset;
        uint120 expiry;
        uint128 nonce;
        uint256 chainId;
        address benefactor;
        address beneficiary;
        address collateral;
        uint128 amountIn;
        uint128 minAmountOut;
    }

    function getBenefactorConfig(address benefactor)
        external
        view
        returns (
            bool active,
            uint128 maxSwapForAssetPerEpoch,
            uint128 maxSwapForCollateralPerEpoch,
            uint128 maxSwapForAssetPerPeriod,
            uint128 maxSwapForCollateralPerPeriod
        );

    function swap(Order calldata order) external;
}

contract U03CrossContractInvariantProbe is Test {

    // Ethena USDtb PSM
    address constant PSM =
        address(bytes20(hex"73E35C5c35A274E34AdE6EB13cC7f62aEE323728"));

    // USDtb — CORRECT ADDRESS
    address constant USDTB =
        address(bytes20(hex"c139190f447e929f090edeb554d95abb8b18ac1c"));

    // Ethereum USDC
    address constant USDC =
        address(bytes20(hex"A0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));

    function _fork() internal {
        uint256 forkId = vm.createFork(
            vm.envString("ETHENA_FORK_RPC")
        );

        vm.selectFork(forkId);

        require(
            address(PSM).code.length > 0,
            "U03: PSM bytecode missing"
        );

        require(
            address(USDTB).code.length > 0,
            "U03: USDtb bytecode missing"
        );

        require(
            address(USDC).code.length > 0,
            "U03: USDC bytecode missing"
        );
    }

    function test_U03_PSMAuthorizationAndStateIsolation() external {

        _fork();

        IPSMU03 psm = IPSMU03(PSM);

        // Completely unprivileged attacker
        address attacker = address(0xCAFE1234);

        // Arbitrary benefactor used only as a clean fixture
        address benefactor = address(0xABCD1234);

        address beneficiary = address(0xBEEF5678);

        // Make sure the fixture address is not already an approved benefactor.
        (
            bool active,
            ,
            ,
            ,
        ) = psm.getBenefactorConfig(benefactor);

        require(
            !active,
            "U03: fixture benefactor already active"
        );

        // Snapshot global/cross-contract state.
        uint256 supplyBefore =
            IERC20U03(USDTB).totalSupply();

        uint256 psmUsdtbBefore =
            IERC20U03(USDTB).balanceOf(PSM);

        uint256 psmUsdcBefore =
            IERC20U03(USDC).balanceOf(PSM);

        // Construct an intentionally unauthorized order.
        IPSMU03.Order memory order =
            IPSMU03.Order({
                isSwapForAsset: true,
                expiry: uint120(block.timestamp + 1 hours),
                nonce: uint128(1),
                chainId: block.chainid,
                benefactor: benefactor,
                beneficiary: beneficiary,
                collateral: USDC,
                amountIn: uint128(1e6),
                minAmountOut: uint128(1)
            });

        // Execute only as an unprivileged attacker.
        vm.prank(attacker);

        vm.expectRevert();

        psm.swap(order);

        // Read state after the rejected call.
        uint256 supplyAfter =
            IERC20U03(USDTB).totalSupply();

        uint256 psmUsdtbAfter =
            IERC20U03(USDTB).balanceOf(PSM);

        uint256 psmUsdcAfter =
            IERC20U03(USDC).balanceOf(PSM);

        // The failed unauthorized operation must not mutate
        // cross-contract accounting state.

        require(
            supplyAfter == supplyBefore,
            "U03 ALERT: USDtb supply changed"
        );

        require(
            psmUsdtbAfter == psmUsdtbBefore,
            "U03 ALERT: PSM USDtb balance changed"
        );

        require(
            psmUsdcAfter == psmUsdcBefore,
            "U03 ALERT: PSM USDC balance changed"
        );

        emit log_string(
            "U03 STATUS: UNAUTHORIZED PSM SWAP REVERTED; CROSS-CONTRACT STATE UNCHANGED"
        );

        emit log_named_uint(
            "USDtb supply before",
            supplyBefore
        );

        emit log_named_uint(
            "USDtb supply after",
            supplyAfter
        );

        emit log_named_uint(
            "PSM USDtb before",
            psmUsdtbBefore
        );

        emit log_named_uint(
            "PSM USDtb after",
            psmUsdtbAfter
        );

        emit log_named_uint(
            "PSM USDC before",
            psmUsdcBefore
        );

        emit log_named_uint(
            "PSM USDC after",
            psmUsdcAfter
        );
    }
}
