
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IP301AssetCheck {
    function isSupportedAsset(address asset)
        external
        view
        returns (bool);
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

    function test_P301_Diagnostic_SupportedAssets()
        external
    {
        uint256 forkId =
            vm.createFork(vm.envString("ETHENA_FORK_RPC"));

        vm.selectFork(forkId);

        require(
            MINTING.code.length > 0,
            "Minting contract bytecode missing"
        );

        IP301AssetCheck target =
            IP301AssetCheck(MINTING);

        address[5] memory assets = [
            WETH,
            USDC,
            USDT,
            DAI,
            USDE
        ];

        string[5] memory names = [
            "WETH",
            "USDC",
            "USDT",
            "DAI",
            "USDe"
        ];

        uint256 supportedCount = 0;

        for (uint256 i = 0; i < assets.length; i++) {
            bool supported =
                target.isSupportedAsset(assets[i]);

            emit log_string(names[i]);
            emit log_named_address("Asset", assets[i]);

            emit log_named_uint(
                "Supported (1=yes, 0=no)",
                supported ? 1 : 0
            );

            if (supported) {
                supportedCount++;
            }
        }

        emit log_named_uint(
            "Supported candidates",
            supportedCount
        );

        emit log_string(
            "DIAGNOSTIC ONLY: no mint attempted"
        );
    }
}
