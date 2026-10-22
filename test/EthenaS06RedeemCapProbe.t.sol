
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IEthenaS06RedeemCapProbe {
    function tokenConfig(address asset)
        external view
        returns (
            uint8 tokenType,
            bool isActive,
            uint128 maxMintPerBlock,
            uint128 maxRedeemPerBlock
        );

    function globalConfig()
        external view
        returns (
            uint128 globalMaxMintPerBlock,
            uint128 globalMaxRedeemPerBlock
        );

    function totalPerBlock(uint256 blockNumber)
        external view
        returns (uint128 minted, uint128 redeemed);

    function totalPerBlockPerAsset(uint256 blockNumber, address asset)
        external view
        returns (uint128 minted, uint128 redeemed);
}

contract EthenaS06RedeemCapProbeTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    IEthenaS06RedeemCapProbe target =
        IEthenaS06RedeemCapProbe(MINTING);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
    }

    function test_ReadRedemptionCapsAndCounters() external {
        assertGt(MINTING.code.length, 0, "Minting contract missing");
        assertGt(USDC.code.length, 0, "USDC code missing");
        assertGt(USDT.code.length, 0, "USDT code missing");

        (, uint128 globalRedeemCap) = target.globalConfig();

        (, bool usdcActive,, uint128 usdcRedeemCap) =
            target.tokenConfig(USDC);

        (, bool usdtActive,, uint128 usdtRedeemCap) =
            target.tokenConfig(USDT);

        (, uint128 globalRedeemed) =
            target.totalPerBlock(block.number);

        (, uint128 usdcRedeemed) =
            target.totalPerBlockPerAsset(block.number, USDC);

        (, uint128 usdtRedeemed) =
            target.totalPerBlockPerAsset(block.number, USDT);

        emit log_named_uint("Fork block", block.number);
        emit log_named_uint("Global redeem cap", globalRedeemCap);
        emit log_named_uint("Global redeemed this block", globalRedeemed);

        emit log_named_uint("USDC active", usdcActive ? 1 : 0);
        emit log_named_uint("USDC redeem cap", usdcRedeemCap);
        emit log_named_uint("USDC redeemed this block", usdcRedeemed);

        emit log_named_uint("USDT active", usdtActive ? 1 : 0);
        emit log_named_uint("USDT redeem cap", usdtRedeemCap);
        emit log_named_uint("USDT redeemed this block", usdtRedeemed);

        assertGt(globalRedeemCap, 0, "Global redeem cap is zero");
        assertGt(usdcRedeemCap, 0, "USDC redeem cap is zero");
        assertGt(usdtRedeemCap, 0, "USDT redeem cap is zero");
    }
}
