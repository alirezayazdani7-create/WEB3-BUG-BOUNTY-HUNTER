
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IEthenaReadOnlyDiagnostic {
    function tokenConfig(address)
        external view returns (uint8, bool, uint128, uint128);

    function globalConfig()
        external view returns (uint128, uint128);

    function totalPerBlock(uint256)
        external view returns (uint128, uint128);

    function totalPerBlockPerAsset(uint256, address)
        external view returns (uint128, uint128);

    function isWhitelistedBenefactor(address)
        external view returns (bool);

    function isApprovedBeneficiary(address, address)
        external view returns (bool);

    function hasRole(bytes32, address)
        external view returns (bool);
}

contract EthenaS06ReadOnlyStateDiagnosticTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    bytes32 constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    IEthenaReadOnlyDiagnostic target =
        IEthenaReadOnlyDiagnostic(MINTING);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
    }

    function test_ReportRealForkStateWithoutMutation() external view {
        uint256 currentBlock = block.number;

        (uint128 globalMintCap, uint128 globalRedeemCap) =
            target.globalConfig();

        (
            uint8 decimals,
            bool active,
            uint128 assetMintCap,
            uint128 assetRedeemCap
        ) = target.tokenConfig(USDC);

        (uint128 globalMinted, uint128 globalRedeemed) =
            target.totalPerBlock(currentBlock);

        (
            uint128 assetMinted,
            uint128 assetRedeemed
        ) = target.totalPerBlockPerAsset(currentBlock, USDC);

        emit log_string("=== READ ONLY FORK DIAGNOSTIC ===");
        emit log_named_uint("Fork block", currentBlock);
        emit log_named_address("Minting contract", MINTING);
        emit log_named_address("USDC", USDC);

        emit log_named_uint("Global mint cap", globalMintCap);
        emit log_named_uint("Global redeem cap", globalRedeemCap);

        emit log_named_uint("USDC decimals", decimals);
        emit log_named_uint("USDC active (1=true)", active ? 1 : 0);
        emit log_named_uint("USDC mint cap", assetMintCap);
        emit log_named_uint("USDC redeem cap", assetRedeemCap);

        emit log_named_uint("Global minted this block", globalMinted);
        emit log_named_uint("Global redeemed this block", globalRedeemed);
        emit log_named_uint("USDC minted this block", assetMinted);
        emit log_named_uint("USDC redeemed this block", assetRedeemed);

        emit log_named_uint(
            "Diagnostic minter whitelisted",
            target.isWhitelistedBenefactor(MINTER) ? 1 : 0
        );

        emit log_named_uint(
            "Minter approved as own beneficiary",
            target.isApprovedBeneficiary(MINTER, MINTER) ? 1 : 0
        );

        emit log_named_uint(
            "Minter has MINTER_ROLE",
            target.hasRole(MINTER_ROLE, MINTER) ? 1 : 0
        );

        emit log_string(
            "READ ONLY: no vm.store, no mint, no transaction"
        );
    }
}
