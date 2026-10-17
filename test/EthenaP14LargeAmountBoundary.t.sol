// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEthenaMintingLargeBoundary {
    enum OrderType {
        MINT,
        REDEEM
    }

    function stablesDeltaLimit() external view returns (uint128);

    function verifyStablesLimit(
        uint128 collateralAmount,
        uint128 usdeAmount,
        address collateralAsset,
        OrderType orderType
    ) external view returns (bool);
}

contract EthenaP14LargeAmountBoundaryTest {
    address internal constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address internal constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IEthenaMintingLargeBoundary internal constant target =
        IEthenaMintingLargeBoundary(MINTING);

    function test_largeOrder_gapJustBelowOneBps_isAcceptedAtZeroLimit()
        external
        view
    {
        require(
            target.stablesDeltaLimit() == 0,
            "delta limit is not zero"
        );

        bool accepted = target.verifyStablesLimit(
            999_900_010_000,
            1_000_000 * 1e18,
            USDC,
            IEthenaMintingLargeBoundary.OrderType.MINT
        );

        require(
            accepted,
            "expected sub-1-bps gap to pass"
        );
    }

    function test_largeOrder_gapAtOneBps_isRejectedAtZeroLimit()
        external
        view
    {
        require(
            target.stablesDeltaLimit() == 0,
            "delta limit is not zero"
        );

        bool accepted = target.verifyStablesLimit(
            999_900_000_000,
            1_000_000 * 1e18,
            USDC,
            IEthenaMintingLargeBoundary.OrderType.MINT
        );

        require(
            !accepted,
            "1-bps gap unexpectedly accepted"
        );
    }

    function test_tenMillionOrder_gapJustBelowOneBps_isAcceptedAtZeroLimit()
        external
        view
    {
        require(
            target.stablesDeltaLimit() == 0,
            "delta limit is not zero"
        );

        bool accepted = target.verifyStablesLimit(
            9_999_000_010_000,
            10_000_000 * 1e18,
            USDC,
            IEthenaMintingLargeBoundary.OrderType.MINT
        );

        require(
            accepted,
            "expected sub-1-bps gap to pass"
        );
    }

    function test_tenMillionOrder_gapAtOneBps_isRejectedAtZeroLimit()
        external
        view
    {
        require(
            target.stablesDeltaLimit() == 0,
            "delta limit is not zero"
        );

        bool accepted = target.verifyStablesLimit(
            9_999_000_000_000,
            10_000_000 * 1e18,
            USDC,
            IEthenaMintingLargeBoundary.OrderType.MINT
        );

        require(
            !accepted,
            "1-bps gap unexpectedly accepted"
        );
    }
}
