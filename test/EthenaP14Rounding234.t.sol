// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Read-only rounding tests for Ethena's deployed stable delta guard.
/// @dev Intended for an isolated local Anvil fork only.
/// @dev Does not submit Mainnet transactions.

interface IEthenaMintingRoundingProbe {
    enum OrderType {
        MINT,
        REDEEM
    }

    function verifyStablesLimit(
        uint128 collateralAmount,
        uint128 usdeAmount,
        address collateralAsset,
        OrderType orderType
    ) external view returns (bool);

    function stablesDeltaLimit()
        external
        view
        returns (uint128);
}

contract EthenaP14Rounding234Test {
    address internal constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address internal constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IEthenaMintingRoundingProbe internal constant target =
        IEthenaMintingRoundingProbe(MINTING);

    function _accepted(
        uint128 collateral
    ) internal view returns (bool) {
        return target.verifyStablesLimit(
            collateral,
            uint128(1e18),
            USDC,
            IEthenaMintingRoundingProbe.OrderType.MINT
        );
    }

    function test_reportConfiguredLimit()
        external
        view
    {
        target.stablesDeltaLimit();
    }

    function test_gap2_roundingBoundary()
        external
        view
    {
        // 999,998 micro-USDC for 1 USDe.
        require(
            _accepted(999_998),
            "gap 2 was not accepted"
        );
    }

    function test_gap3_roundingBoundary()
        external
        view
    {
        // 999,997 micro-USDC for 1 USDe.
        require(
            _accepted(999_997),
            "gap 3 was not accepted"
        );
    }

    function test_gap4_roundingBoundary()
        external
        view
    {
        // 999,996 micro-USDC for 1 USDe.
        require(
            _accepted(999_996),
            "gap 4 was not accepted"
        );
    }

    function test_gap100_boundaryControl()
        external
        view
    {
        // 999,900 micro-USDC for 1 USDe.
        require(
            !_accepted(999_900),
            "gap 100 unexpectedly accepted"
        );
    }
}
