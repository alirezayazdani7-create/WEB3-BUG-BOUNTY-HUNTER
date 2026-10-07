// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEthenaMintingP20Diag {
    function isSupportedAsset(
        address asset
    )
        external
        view
        returns (bool);

    function tokenConfig(
        address asset
    )
        external
        view
        returns (
            uint8 tokenType,
            bool isActive,
            uint128 maxMintPerBlock,
            uint128 maxRedeemPerBlock
        );

    function globalConfig()
        external
        view
        returns (
            uint128 globalMaxMintPerBlock,
            uint128 globalMaxRedeemPerBlock
        );
}

contract MintingV2P20WETHDiagnosticTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;


    IEthenaMintingP20Diag constant target =
        IEthenaMintingP20Diag(
            MINTING
        );


    function assertTrue(
        bool value,
        string memory reason
    )
        internal
        pure
    {
        require(
            value,
            reason
        );
    }


    event Diagnostic(
        bool supported,
        uint8 tokenType,
        bool active,
        uint128 maxMintPerBlock,
        uint128 maxRedeemPerBlock,
        uint128 globalMaxMintPerBlock,
        uint128 globalMaxRedeemPerBlock
    );


    function test_P20_WETH_production_state_diagnostic()
        external
    {
        bool supported =
            target.isSupportedAsset(
                WETH
            );


        (
            uint8 tokenType,
            bool active,
            uint128 maxMintPerBlock,
            uint128 maxRedeemPerBlock
        ) =
            target.tokenConfig(
                WETH
            );


        (
            uint128 globalMaxMintPerBlock,
            uint128 globalMaxRedeemPerBlock
        ) =
            target.globalConfig();


        emit Diagnostic(
            supported,
            tokenType,
            active,
            maxMintPerBlock,
            maxRedeemPerBlock,
            globalMaxMintPerBlock,
            globalMaxRedeemPerBlock
        );


        /*
         * Expected production state:
         *
         * WETH is present in the asset configuration,
         * but is NOT active for minting.
         *
         * Therefore mintWETH() must revert with
         * UnsupportedAsset().
         */
        assertTrue(
            !supported,
            "EXPECTED STATE CHANGED: WETH is supported"
        );


        assertTrue(
            !active,
            "EXPECTED STATE CHANGED: WETH tokenConfig is active"
        );


        /*
         * WETH must remain an ASSET-type token.
         */
        assertTrue(
            tokenType == 1,
            "Unexpected WETH token type"
        );
    }
}
