// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEthenaMinting {
    function usde() external view returns (address);

    function verifyNonce(
        address sender,
        uint128 nonce
    ) external view returns (
        uint128,
        uint256,
        uint256
    );

    function verifyRoute(
        address[] calldata custodians,
        uint256[] calldata ratios
    ) external view returns (bool);

    function verifyStablesLimit(
        uint128 collateralAmount,
        uint128 usdeAmount,
        address collateralAsset,
        uint8 orderType
    ) external view returns (bool);

    function tokenConfig(
        address asset
    ) external view returns (
        uint8 tokenType,
        bool isActive,
        uint128 maxMintPerBlock,
        uint128 maxRedeemPerBlock
    );

    function isSupportedAsset(
        address asset
    ) external view returns (bool);

    function stablesDeltaLimit()
        external
        view
        returns (uint128);
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

contract MintingV2TransitionTest {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    // Mainnet USDC
    address constant USDC =
        0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;

    // Mainnet USDT
    address constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    IEthenaMinting target =
        IEthenaMinting(MINTING);

    function assertTrue(
        bool value,
        string memory reason
    ) internal pure {
        require(value, reason);
    }

    function assertEq(
        address a,
        address b,
        string memory reason
    ) internal pure {
        require(a == b, reason);
    }

    function test_P01_usde_binding()
        external
    {
        assertEq(
            target.usde(),
            USDE,
            "USDe binding mismatch"
        );
    }

    function test_P02_nonce_boundary()
        external
    {
        address sender =
            address(0x1111);

        (
            uint128 slotA,
            uint256 invalidatorA,
            uint256 bitA
        ) = target.verifyNonce(
            sender,
            uint128(0x1234)
        );

        (
            uint128 slotB,
            uint256 invalidatorB,
            uint256 bitB
        ) = target.verifyNonce(
            sender,
            uint128(
                uint256(0x1234)
                + (uint256(1) << 64)
            )
        );

        /*
         * Measurement only.
         *
         * These two uint128 nonce values should collide
         * under the uint64 slot calculation.
         *
         * This is NOT treated as a vulnerability by itself.
         */
        assertTrue(
            slotA == slotB,
            "expected nonce slot collision not observed"
        );

        assertTrue(
            bitA == bitB,
            "expected nonce bit collision not observed"
        );

        assertTrue(
            invalidatorA == invalidatorB,
            "unexpected bitmap state difference"
        );
    }

    function test_P03_non_custodian_route_rejected()
        external
    {
        address[] memory custodians =
            new address[](2);

        uint256[] memory ratios =
            new uint256[](2);

        custodians[0] = address(1);
        custodians[1] = address(2);

        ratios[0] = 5000;
        ratios[1] = 5000;

        (bool ok,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyRoute.selector,
                    custodians,
                    ratios
                )
            );

        assertTrue(
            !ok,
            "non-custodian route accepted"
        );
    }

    function test_P04_empty_route_rejected()
        external
    {
        address[] memory custodians =
            new address[](0);

        uint256[] memory ratios =
            new uint256[](0);

        (bool ok,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyRoute.selector,
                    custodians,
                    ratios
                )
            );

        assertTrue(
            !ok,
            "empty route accepted"
        );
    }

    function test_P05_usdc_configuration()
        external
    {
        bool supported =
            target.isSupportedAsset(USDC);

        if (!supported) {
            return;
        }

        (
            uint8 tokenType,
            bool active,
            uint128 maxMint,
            uint128 maxRedeem
        ) = target.tokenConfig(USDC);

        assertTrue(
            active,
            "USDC configured but inactive"
        );

        assertTrue(
            maxMint > 0,
            "USDC max mint is zero"
        );

        assertTrue(
            maxRedeem > 0,
            "USDC max redeem is zero"
        );

        tokenType;
    }

    function test_P06_usdt_configuration()
        external
    {
        bool supported =
            target.isSupportedAsset(USDT);

        if (!supported) {
            return;
        }

        (
            uint8 tokenType,
            bool active,
            uint128 maxMint,
            uint128 maxRedeem
        ) = target.tokenConfig(USDT);

        assertTrue(
            active,
            "USDT configured but inactive"
        );

        assertTrue(
            maxMint > 0,
            "USDT max mint is zero"
        );

        assertTrue(
            maxRedeem > 0,
            "USDT max redeem is zero"
        );

        tokenType;
    }

    /*
     * CRITICAL BOUNDARY TEST
     *
     * USDC has 6 decimals while USDe has 18.
     *
     * 1 USDC = 1e6
     * 1 USDe = 1e18
     *
     * We test a 1-unit collateral shortfall:
     *
     * 1,000,000 USDC units
     * versus
     * 1 USDe
     *
     * then:
     *
     * 999,999 USDC units
     * versus
     * 1 USDe
     *
     * The second case is deliberately one micro-USDC
     * below parity.
     *
     * We only record the contract's actual result.
     */
    function test_P07_usdc_one_unit_boundary()
        external
    {
        if (!target.isSupportedAsset(USDC)) {
            return;
        }

        uint128 oneUSDC =
            1_000_000;

        uint128 oneUSDe =
            1e18;

        uint128 deltaLimit =
            target.stablesDeltaLimit();

        bool exact =
            target.verifyStablesLimit(
                oneUSDC,
                oneUSDe,
                USDC,
                0
            );

        bool oneUnitShort =
            target.verifyStablesLimit(
                oneUSDC - 1,
                oneUSDe,
                USDC,
                0
            );

        /*
         * Exact parity must pass.
         */
        assertTrue(
            exact,
            "exact USDC/USDe parity rejected"
        );

        /*
         * Do not assert the shortfall result.
         *
         * We are measuring whether integer rounding permits
         * a one-unit collateral discrepancy under the live
         * stablesDeltaLimit.
         */
        deltaLimit;
        oneUnitShort;
    }

    function test_P08_usdt_one_unit_boundary()
        external
    {
        if (!target.isSupportedAsset(USDT)) {
            return;
        }

        uint128 oneUSDT =
            1_000_000;

        uint128 oneUSDe =
            1e18;

        bool exact =
            target.verifyStablesLimit(
                oneUSDT,
                oneUSDe,
                USDT,
                0
            );

        bool oneUnitShort =
            target.verifyStablesLimit(
                oneUSDT - 1,
                oneUSDe,
                USDT,
                0
            );

        assertTrue(
            exact,
            "exact USDT/USDe parity rejected"
        );

        oneUnitShort;
    }

    function test_P09_zero_delta_configuration()
        external
        view
    {
        uint128 limit =
            target.stablesDeltaLimit();

        /*
         * Observation only.
         *
         * A zero limit means the pricing check is expected
         * to enforce exact parity subject to implementation
         * rounding.
         */
        limit;
    }
}
