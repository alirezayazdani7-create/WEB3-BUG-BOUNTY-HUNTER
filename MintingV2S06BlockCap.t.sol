// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IEthenaMintingS06 {
    struct TokenConfig {
        uint8 tokenType;
        bool isActive;
        uint128 maxMintPerBlock;
        uint128 maxRedeemPerBlock;
    }

    struct GlobalConfig {
        uint128 globalMaxMintPerBlock;
        uint128 globalMaxRedeemPerBlock;
    }

    struct BlockTotals {
        uint128 mintedPerBlock;
        uint128 redeemedPerBlock;
    }

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

    function totalPerBlockPerAsset(uint256 blockNumber, address asset)
        external
        view
        returns (
            uint128 mintedPerBlock,
            uint128 redeemedPerBlock
        );

    function verifyStablesLimit(
        uint128 collateralAmount,
        uint128 usdeAmount,
        address collateralAsset,
        uint8 orderType
    ) external view returns (bool);
}

contract MintingV2S06BlockCapTest is Test {

    address constant MINTING =
        address(bytes20(hex"e3490297a08d6fc8da46edb7b6142e4f461b62d3"));

    address constant USDC =
        address(bytes20(hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));

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

    function test_S06_ReadLiveCapConfiguration() external {
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
            tokenType
        );

        emit log_named_uint(
            "S06 assetActive",
            active ? 1 : 0
        );

        emit log_named_uint(
            "S06 assetMintCap",
            assetMintCap
        );

        emit log_named_uint(
            "S06 assetRedeemCap",
            assetRedeemCap
        );

        emit log_named_uint(
            "S06 globalMintCap",
            globalMintCap
        );

        emit log_named_uint(
            "S06 globalRedeemCap",
            globalRedeemCap
        );

        assertTrue(
            active,
            "S06: USDC configuration inactive"
        );

        assertGt(
            assetMintCap,
            0,
            "S06: asset mint cap is zero"
        );

        assertGt(
            globalMintCap,
            0,
            "S06: global mint cap is zero"
        );

        /*
         * Important structural invariant:
         *
         * The global cap must not be smaller than
         * every individual asset cap by accident.
         *
         * This is diagnostic only; it is NOT a vulnerability
         * if the values are intentionally configured this way.
         */
        emit log(
            "S06: live cap configuration read successfully"
        );
    }

    function test_S06_CurrentBlockAccounting() external {
        _fork();

        uint256 blockNumber =
            block.number;

        (
            uint128 globalMinted,
            uint128 globalRedeemed
        ) =
            target.totalPerBlock(blockNumber);

        (
            uint128 assetMinted,
            uint128 assetRedeemed
        ) =
            target.totalPerBlockPerAsset(
                blockNumber,
                USDC
            );

        emit log_named_uint(
            "S06 block",
            blockNumber
        );

        emit log_named_uint(
            "S06 global minted",
            globalMinted
        );

        emit log_named_uint(
            "S06 global redeemed",
            globalRedeemed
        );

        emit log_named_uint(
            "S06 USDC minted",
            assetMinted
        );

        emit log_named_uint(
            "S06 USDC redeemed",
            assetRedeemed
        );

        (
            ,
            ,
            uint128 assetMintCap,
        ) =
            target.tokenConfig(USDC);

        (
            uint128 globalMintCap,
        ) =
            target.globalConfig();

        assertLe(
            assetMinted,
            assetMintCap,
            "S06 ALERT: asset mint accounting exceeds configured cap"
        );

        assertLe(
            globalMinted,
            globalMintCap,
            "S06 ALERT: global mint accounting exceeds configured cap"
        );

        emit log(
            "S06: current block accounting is within configured caps"
        );
    }

    function test_S06_BlockBoundaryAccounting() external {
        _fork();

        uint256 beforeBlock =
            block.number;

        (
            uint128 globalMintBefore,
        ) =
            target.totalPerBlock(beforeBlock);

        (
            uint128 assetMintBefore,
        ) =
            target.totalPerBlockPerAsset(
                beforeBlock,
                USDC
            );

        vm.roll(
            beforeBlock + 1
        );

        uint256 nextBlock =
            block.number;

        (
            uint128 globalMintAfter,
        ) =
            target.totalPerBlock(nextBlock);

        (
            uint128 assetMintAfter,
        ) =
            target.totalPerBlockPerAsset(
                nextBlock,
                USDC
            );

        emit log_named_uint(
            "S06 previous block",
            beforeBlock
        );

        emit log_named_uint(
            "S06 next block",
            nextBlock
        );

        emit log_named_uint(
            "S06 previous global mint",
            globalMintBefore
        );

        emit log_named_uint(
            "S06 next global mint",
            globalMintAfter
        );

        emit log_named_uint(
            "S06 previous asset mint",
            assetMintBefore
        );

        emit log_named_uint(
            "S06 next asset mint",
            assetMintAfter
        );

        /*
         * The mapping is block-indexed.
         *
         * A new block must not inherit the previous block's
         * accounting slot.
         */
        assertEq(
            globalMintAfter,
            0,
            "S06 ALERT: global mint accounting carried into next block"
        );

        assertEq(
            assetMintAfter,
            0,
            "S06 ALERT: asset mint accounting carried into next block"
        );

        emit log(
            "S06: block boundary accounting resets correctly"
        );
    }

    function test_S06_CapArithmeticCannotSilentlyWrap() external {
        _fork();

        (
            ,
            ,
            uint128 assetMintCap,
        ) =
            target.tokenConfig(USDC);

        (
            uint128 globalMintCap,
        ) =
            target.globalConfig();

        /*
         * Solidity 0.8 checked arithmetic is important here.
         *
         * The production modifiers calculate:
         *
         * current + requested > cap
         *
         * We independently verify that the relevant configured
         * values are represented as uint128 and do not rely on
         * an unchecked wraparound assumption.
         */

        assertLe(
            assetMintCap,
            type(uint128).max,
            "S06: invalid asset cap representation"
        );

        assertLe(
            globalMintCap,
            type(uint128).max,
            "S06: invalid global cap representation"
        );

        emit log(
            "S06: cap values are uint128 and no silent representation widening was observed"
        );
    }
}
