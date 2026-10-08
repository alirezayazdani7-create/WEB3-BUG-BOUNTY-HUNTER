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
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9eb0cE3606eB48;

    address constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant DAI =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

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

        uint256 supportedCount;

        for (uint256 i; i < assets.length; i++) {
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
