// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IEthenaS06CapTarget {
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

contract EthenaS06USDCMintCapForkTest is Test {
address internal constant MINTING =
0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

address internal constant USDC =
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

IEthenaS06CapTarget internal target =
    IEthenaS06CapTarget(MINTING);

function _fork() internal {
    uint256 forkId = vm.createFork(
        vm.envString("ETHENA_FORK_RPC")
    );
    vm.selectFork(forkId);

    assertGt(MINTING.code.length, 0, "Minting bytecode missing");
    assertGt(USDC.code.length, 0, "USDC bytecode missing");
}

function test_S06_ReadAndCalculateEffectiveMintHeadroom()
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

    uint256 currentBlock = block.number;

    (
        uint128 globalMinted,
        uint128 globalRedeemed
    ) = target.totalPerBlock(currentBlock);

    (
        uint128 assetMinted,
        uint128 assetRedeemed
    ) = target.totalPerBlockPerAsset(currentBlock, USDC);

    emit log_named_uint("block.number", currentBlock);
    emit log_named_uint("USDC.tokenType", tokenType);
    emit log_named_uint("USDC.active", active ? 1 : 0);

    emit log_named_uint("USDC.mintCap", assetMintCap);
    emit log_named_uint("Global.mintCap", globalMintCap);

    emit log_named_uint("USDC.mintedThisBlock", assetMinted);
    emit log_named_uint("Global.mintedThisBlock", globalMinted);

    emit log_named_uint("USDC.redeemCap", assetRedeemCap);
    emit log_named_uint("Global.redeemCap", globalRedeemCap);

    emit log_named_uint("USDC.redeemedThisBlock", assetRedeemed);
    emit log_named_uint("Global.redeemedThisBlock", globalRedeemed);

    assertTrue(active, "USDC configuration is inactive");
    assertGt(assetMintCap, 0, "USDC mint cap is zero");
    assertGt(globalMintCap, 0, "Global mint cap is zero");

    assertLe(
        assetMinted,
        assetMintCap,
        "USDC mint accounting exceeds configured cap"
    );

    assertLe(
        globalMinted,
        globalMintCap,
        "Global mint accounting exceeds configured cap"
    );

    assertLe(
        assetRedeemed,
        assetRedeemCap,
        "USDC redeem accounting exceeds configured cap"
    );

    assertLe(
        globalRedeemed,
        globalRedeemCap,
        "Global redeem accounting exceeds configured cap"
    );

    uint256 assetHeadroom =
        uint256(assetMintCap) - uint256(assetMinted);

    uint256 globalHeadroom =
        uint256(globalMintCap) - uint256(globalMinted);

    uint256 effectiveHeadroom =
        assetHeadroom < globalHeadroom
            ? assetHeadroom
            : globalHeadroom;

    emit log_named_uint("USDC.mintHeadroom", assetHeadroom);
    emit log_named_uint("Global.mintHeadroom", globalHeadroom);
    emit log_named_uint("Effective.mintHeadroom", effectiveHeadroom);
}

function test_S06_BlockAccountingStartsAtZeroAfterRoll()
    external
{
    _fork();

    uint256 nextBlock = block.number + 1;
    vm.roll(nextBlock);

    (
        uint128 globalMinted,
        uint128 globalRedeemed
    ) = target.totalPerBlock(nextBlock);

    (
        uint128 assetMinted,
        uint128 assetRedeemed
    ) = target.totalPerBlockPerAsset(nextBlock, USDC);

    emit log_named_uint("NewBlock", nextBlock);
    emit log_named_uint("GlobalMinted", globalMinted);
    emit log_named_uint("AssetMinted", assetMinted);

    assertEq(globalMinted, 0, "Global mint counter did not reset");
    assertEq(globalRedeemed, 0, "Global redeem counter did not reset");
    assertEq(assetMinted, 0, "USDC mint counter did not reset");
    assertEq(assetRedeemed, 0, "USDC redeem counter did not reset");
}

}
