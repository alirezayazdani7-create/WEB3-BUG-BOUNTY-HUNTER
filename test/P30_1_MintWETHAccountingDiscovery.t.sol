
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IP301AssetConfig {
    function isSupportedAsset(address asset)
        external
        view
        returns (bool);

    function tokenConfig(address asset)
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

contract P301MintWETHAccountingDiscoveryTest is Test {
    address constant MINTING =
        address(bytes20(hex"e3490297a08d6fc8da46edb7b6142e4f461b62d3"));

    address constant WETH =
        address(bytes20(hex"c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"));

    address constant USDC =
        address(bytes20(hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));

    address constant USDT =
        address(bytes20(hex"dac17f958d2ee523a2206206994597c13d831ec7"));

    address constant DAI =
        address(bytes20(hex"6b175474e89094c44da98b954eedeac495271d0f"));

    address constant USDE =
        address(bytes20(hex"4c9edd5852cd905f086c759e8383e09bff1e68b3"));

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
        require(
            MINTING.code.length > 0,
            "Minting contract bytecode missing"
        );
    }

    function test_P301_Diagnostic_SupportedAssets() external view {
        IP301AssetConfig target = IP301AssetConfig(MINTING);

        address[5] memory assets = [
            WETH, USDC, USDT, DAI, USDE
        ];

        string[5] memory names = [
            "WETH", "USDC", "USDT", "DAI", "USDe"
        ];

        uint256 supportedCount;

        for (uint256 i; i < assets.length; ++i) {
            (
                uint8 tokenType,
                bool active,
                uint128 maxMint,
                uint128 maxRedeem
            ) = target.tokenConfig(assets[i]);

            bool supported = target.isSupportedAsset(assets[i]);

            emit log_string(names[i]);
            emit log_named_address("Asset", assets[i]);
            emit log_named_uint("Token type", tokenType);
            emit log_named_uint("Active (1=yes)", active ? 1 : 0);
            emit log_named_uint("Supported (1=yes)", supported ? 1 : 0);
            emit log_named_uint("Max mint per block", maxMint);
            emit log_named_uint("Max redeem per block", maxRedeem);

            // Check consistency between the public views.
            assertEq(
                supported,
                active,
                "isSupportedAsset/tokenConfig mismatch"
            );

            if (active) {
                supportedCount++;
            } else {
                // Removed/inactive assets should have cleared config.
                assertEq(maxMint, 0, "Inactive asset has mint limit");
                assertEq(maxRedeem, 0, "Inactive asset has redeem limit");
            }
        }

        emit log_named_uint("Supported candidates", supportedCount);
        emit log_string("READ-ONLY DIAGNOSTIC: no mint attempted");
    }

    function test_P301_Diagnostic_GlobalLimits() external view {
        IP301AssetConfig target = IP301AssetConfig(MINTING);

        (
            uint128 globalMint,
            uint128 globalRedeem
        ) = target.globalConfig();

        emit log_named_uint("Global max mint per block", globalMint);
        emit log_named_uint("Global max redeem per block", globalRedeem);

        emit log_string("READ-ONLY DIAGNOSTIC: no state changes");
    }
}
