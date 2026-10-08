// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IEthenaMintingS06 {
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

    function totalPerBlock(uint256 blockNumber)
        external
        view
        returns (
            uint128 mintedPerBlock,
            uint128 redeemedPerBlock
        );

    function totalPerBlockPerAsset(
        uint256 blockNumber,
        address asset
    )
        external
        view
        returns (
            uint128 mintedPerBlock,
            uint128 redeemedPerBlock
        );
}

contract MintingV2S06BlockCapTest is Test {

    address constant MINTING =
        address(
            bytes20(
                hex"e3490297a08d6fc8da46edb7b6142e4f461b62d3"
            )
        );

    address constant USDC =
        address(
            bytes20(
                hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
            )
        );

    IEthenaMintingS06 constant target =
        IEthenaMintingS06(MINTING);

    function _fork() internal {
        uint256 forkId =
            vm.createFork(
                vm.envString("ETHENA_FORK_RPC")
            );

        vm.selectFork(forkId);

        require(
            MINTING.code.length > 0,
            "S06: Minting contract has no bytecode"
        );

        require(
            USDC.code.length > 0,
            "S06: USDC has no bytecode"
        );
    }

    function test_S06_ReadLiveCapConfiguration()
        external
    {
        _fork();

        (
            uint8 tokenType,
            bool active,
            uint128 assetMintCap,
            uint128 assetRedeemCap
        ) = target.tokenConfig(USDC);

        (
            uint128 globalMintCap,
            uint128 globalRedeemCap
        ) = target.globalConfig();

        emit log_named_uint(
            "S06 tokenType",
            uint256(tokenType)
        );

        emit log_named_uint(
            "S06 assetMintCap",
            uint256(assetMintCap)
        );

        emit log_named_uint(
            "S06 assetRedeemCap",
            uint256(assetRedeemCap)
        );

        emit log_named_uint(
            "S06 globalMintCap",
            uint256(globalMintCap)
        );

        emit log_named_uint(
            "S06 globalRedeemCap",
            uint256(globalRedeemCap)
        );

        assertTrue(
            active,
            "S06: USDC token configuration inactive"
        );

        assertGt(
            assetMintCap,
            0,
            "S06: USDC mint cap is zero"
        );

        assertGt(
            globalMintCap,
            0,
            "S06: global mint cap is zero"
        );
    }

    function test_S06_CurrentBlockAccounting()
        external
    {
        _fork();

        uint256 currentBlock = block.number;

        (
            uint128 globalMinted,
            uint128 globalRedeemed
        ) = target.totalPerBlock(currentBlock);

        (
            uint128 assetMinted,
            uint128 assetRedeemed
        ) = target.totalPerBlockPerAsset(
            currentBlock,
            USDC
        );

        (
            uint8 tokenType,
            bool active,
            uint128 assetMintCap,
            uint128 assetRedeemCap
        ) = target.tokenConfig(USDC);

        (
            uint128 globalMintCap,
            uint128 globalRedeemCap
        ) = target.globalConfig();

        emit log_named_uint(
            "S06 current block",
            currentBlock
        );

        emit log_named_uint(
            "S06 global minted",
            uint256(globalMinted)
        );

        emit log_named_uint(
            "S06 global redeemed",
            uint256(globalRedeemed)
        );

        emit log_named_uint(
            "S06 asset minted",
            uint256(assetMinted)
        );

        emit log_named_uint(
            "S06 asset redeemed",
            uint256(assetRedeemed)
        );

        emit log_named_uint(
            "S06 asset mint cap",
            uint256(assetMintCap)
        );

        emit log_named_uint(
            "S06 global mint cap",
            uint256(globalMintCap)
        );

        assertTrue(
            active,
            "S06: asset inactive"
        );

        assertLe(
            assetMinted,
            assetMintCap,
            "S06: asset mint accounting exceeds cap"
        );

        assertLe(
            globalMinted,
            globalMintCap,
            "S06: global mint accounting exceeds cap"
        );

        assertLe(
            assetRedeemed,
            assetRedeemCap,
            "S06: asset redeem accounting exceeds cap"
        );

        assertLe(
            globalRedeemed,
            globalRedeemCap,
            "S06: global redeem accounting exceeds cap"
        );
    }

    function test_S06_BlockBoundaryAccounting()
        external
    {
        _fork();

        uint256 beforeBlock = block.number;
        uint256 nextBlock = beforeBlock + 1;

        (
            uint128 globalMintBefore,
            uint128 globalRedeemBefore
        ) = target.totalPerBlock(beforeBlock);

        (
            uint128 assetMintBefore,
            uint128 assetRedeemBefore
        ) = target.totalPerBlockPerAsset(
            beforeBlock,
            USDC
        );

        emit log_named_uint(
            "S06 previous block",
            beforeBlock
        );

        emit log_named_uint(
            "S06 previous global mint",
            uint256(globalMintBefore)
        );

        emit log_named_uint(
            "S06 previous asset mint",
            uint256(assetMintBefore)
        );

        vm.roll(nextBlock);

        (
            uint128 globalMintAfter,
            uint128 globalRedeemAfter
        ) = target.totalPerBlock(nextBlock);

        (
            uint128 assetMintAfter,
            uint128 assetRedeemAfter
        ) = target.totalPerBlockPerAsset(
            nextBlock,
            USDC
        );

        emit log_named_uint(
            "S06 new block",
            nextBlock
        );

        emit log_named_uint(
            "S06 new global mint",
            uint256(globalMintAfter)
        );

        emit log_named_uint(
            "S06 new asset mint",
            uint256(assetMintAfter)
        );

        assertEq(
            globalMintAfter,
            0,
            "S06: global mint carried into next block"
        );

        assertEq(
            globalRedeemAfter,
            0,
            "S06: global redeem carried into next block"
        );

        assertEq(
            assetMintAfter,
            0,
            "S06: asset mint carried into next block"
        );

        assertEq(
            assetRedeemAfter,
            0,
            "S06: asset redeem carried into next block"
        );
    }

    function test_S06_CapArithmeticCannotSilentlyWrap()
        external
    {
        _fork();

        (
            uint8 tokenType,
            bool active,
            uint128 assetMintCap,
            uint128 assetRedeemCap
        ) = target.tokenConfig(USDC);

        (
            uint128 globalMintCap,
            uint128 globalRedeemCap
        ) = target.globalConfig();

        emit log_named_uint(
            "S06 asset mint cap",
            uint256(assetMintCap)
        );

        emit log_named_uint(
            "S06 asset redeem cap",
            uint256(assetRedeemCap)
        );

        emit log_named_uint(
            "S06 global mint cap",
            uint256(globalMintCap)
        );

        emit log_named_uint(
            "S06 global redeem cap",
            uint256(globalRedeemCap)
        );

        assertLe(
            uint256(assetMintCap),
            uint256(type(uint128).max),
            "S06: asset mint cap outside uint128"
        );

        assertLe(
            uint256(assetRedeemCap),
            uint256(type(uint128).max),
            "S06: asset redeem cap outside uint128"
        );

        assertLe(
            uint256(globalMintCap),
            uint256(type(uint128).max),
            "S06: global mint cap outside uint128"
        );

        assertLe(
            uint256(globalRedeemCap),
            uint256(type(uint128).max),
            "S06: global redeem cap outside uint128"
        );

        assertTrue(
            active,
            "S06: USDC inactive"
        );
    }
}
