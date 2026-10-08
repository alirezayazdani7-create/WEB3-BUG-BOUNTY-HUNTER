// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IUSDtbMintingS08 {
    struct TokenConfig {
        uint8 tokenType;
        bool isActive;
        uint128 maxMintPerBlock;
        uint128 maxRedeemPerBlock;
    }

    function owner() external view returns (address);

    function tokenConfig(address asset) external view returns (
        uint8 tokenType,
        bool isActive,
        uint128 maxMintPerBlock,
        uint128 maxRedeemPerBlock
    );

    function isSupportedAsset(address asset) external view returns (bool);

    function removeSupportedAsset(address asset) external;

    function addSupportedAsset(
        address asset,
        TokenConfig calldata cfg
    ) external;

    function totalPerBlock(uint256 blockNumber)
        external
        view
        returns (uint128 minted, uint128 redeemed);

    function totalPerBlockPerAsset(
        uint256 blockNumber,
        address asset
    )
        external
        view
        returns (uint128 minted, uint128 redeemed);
}

contract EthenaS08TokenConfigLifecycle is Test {

    address constant USDtb_MINTING =
        0xa3DDBf92077b850E29C4805Df0a2459Ae048416a;

    function test_S08_RemoveReadd_StateTransition() external {

        string memory rpc = vm.envString("ETHENA_FORK_RPC");

        uint256 forkId = vm.createFork(rpc);
        vm.selectFork(forkId);

        IUSDtbMintingS08 target =
            IUSDtbMintingS08(USDtb_MINTING);

        address asset =
            vm.envAddress("S08_ASSET");

        require(
            asset.code.length > 0,
            "S08: asset has no bytecode"
        );

        require(
            address(target).code.length > 0,
            "S08: target has no bytecode"
        );

        (
            uint8 tokenTypeBefore,
            bool activeBefore,
            uint128 maxMintBefore,
            uint128 maxRedeemBefore
        ) = target.tokenConfig(asset);

        bool supportedBefore =
            target.isSupportedAsset(asset);

        address admin = target.owner();

        require(
            supportedBefore,
            "S08: selected asset is not currently supported"
        );

        emit log_named_address(
            "S08 target",
            address(target)
        );

        emit log_named_address(
            "S08 asset",
            asset
        );

        emit log_named_address(
            "S08 owner",
            admin
        );

        emit log_named_uint(
            "S08 tokenType before",
            tokenTypeBefore
        );

        emit log_named_uint(
            "S08 active before",
            activeBefore ? 1 : 0
        );

        emit log_named_uint(
            "S08 maxMint before",
            maxMintBefore
        );

        emit log_named_uint(
            "S08 maxRedeem before",
            maxRedeemBefore
        );

        uint256 blockBefore = block.number;

        (
            uint128 globalMintBefore,
            uint128 globalRedeemBefore
        ) = target.totalPerBlock(blockBefore);

        (
            uint128 assetMintBefore,
            uint128 assetRedeemBefore
        ) = target.totalPerBlockPerAsset(
            blockBefore,
            asset
        );

        // Isolated fork only.
        // No mainnet transaction is performed.

        vm.prank(admin);

        target.removeSupportedAsset(asset);

        bool supportedRemoved =
            target.isSupportedAsset(asset);

        (
            uint8 tokenTypeRemoved,
            bool activeRemoved,
            uint128 maxMintRemoved,
            uint128 maxRedeemRemoved
        ) = target.tokenConfig(asset);

        emit log_named_uint(
            "S08 supported after remove",
            supportedRemoved ? 1 : 0
        );

        emit log_named_uint(
            "S08 tokenType after remove",
            tokenTypeRemoved
        );

        emit log_named_uint(
            "S08 active after remove",
            activeRemoved ? 1 : 0
        );

        emit log_named_uint(
            "S08 maxMint after remove",
            maxMintRemoved
        );

        emit log_named_uint(
            "S08 maxRedeem after remove",
            maxRedeemRemoved
        );

        IUSDtbMintingS08.TokenConfig memory originalConfig =
            IUSDtbMintingS08.TokenConfig({
                tokenType: tokenTypeBefore,
                isActive: activeBefore,
                maxMintPerBlock: maxMintBefore,
                maxRedeemPerBlock: maxRedeemBefore
            });

        vm.prank(admin);

        target.addSupportedAsset(
            asset,
            originalConfig
        );

        (
            uint8 tokenTypeAfter,
            bool activeAfter,
            uint128 maxMintAfter,
            uint128 maxRedeemAfter
        ) = target.tokenConfig(asset);

        bool supportedAfter =
            target.isSupportedAsset(asset);

        (
            uint128 globalMintAfter,
            uint128 globalRedeemAfter
        ) = target.totalPerBlock(blockBefore);

        (
            uint128 assetMintAfter,
            uint128 assetRedeemAfter
        ) = target.totalPerBlockPerAsset(
            blockBefore,
            asset
        );

        emit log_named_uint(
            "S08 supported after re-add",
            supportedAfter ? 1 : 0
        );

        emit log_named_uint(
            "S08 tokenType after re-add",
            tokenTypeAfter
        );

        emit log_named_uint(
            "S08 active after re-add",
            activeAfter ? 1 : 0
        );

        emit log_named_uint(
            "S08 maxMint after re-add",
            maxMintAfter
        );

        emit log_named_uint(
            "S08 maxRedeem after re-add",
            maxRedeemAfter
        );

        emit log_named_uint(
            "S08 global mint counter delta",
            uint256(globalMintAfter)
                - uint256(globalMintBefore)
        );

        emit log_named_uint(
            "S08 global redeem counter delta",
            uint256(globalRedeemAfter)
                - uint256(globalRedeemBefore)
        );

        emit log_named_uint(
            "S08 asset mint counter delta",
            uint256(assetMintAfter)
                - uint256(assetMintBefore)
        );

        emit log_named_uint(
            "S08 asset redeem counter delta",
            uint256(assetRedeemAfter)
                - uint256(assetRedeemBefore)
        );

        require(
            supportedAfter,
            "S08: asset failed to re-add"
        );

        require(
            tokenTypeAfter == tokenTypeBefore,
            "S08: token type changed"
        );

        require(
            activeAfter == activeBefore,
            "S08: active state changed"
        );

        require(
            maxMintAfter == maxMintBefore,
            "S08: mint limit changed"
        );

        require(
            maxRedeemAfter == maxRedeemBefore,
            "S08: redeem limit changed"
        );

        emit log(
            "S08 STATUS: STATE-TRANSITION OBSERVATION ONLY; PERMISSIONLESS IMPACT NOT DEMONSTRATED"
        );
    }
}
