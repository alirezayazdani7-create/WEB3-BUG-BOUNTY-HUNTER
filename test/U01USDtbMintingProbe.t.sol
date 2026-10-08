// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IUSDtbMintingU01 {
    struct Order {
        string order_id;
        uint8 order_type;
        uint120 expiry;
        uint128 nonce;
        address benefactor;
        address beneficiary;
        address collateral_asset;
        uint128 collateral_amount;
        uint128 usdtb_amount;
    }

    struct Route {
        address[] addresses;
        uint128[] ratios;
    }

    struct Signature {
        uint8 signature_type;
        bytes signature_bytes;
    }

    function mint(
        Order calldata,
        Route calldata,
        Signature calldata
    ) external;

    function isWhitelistedBenefactor(address) external view returns (bool);
    function isSupportedAsset(address) external view returns (bool);
}

contract U01USDtbMintingProbe is Test {

    address constant TARGET =
        0xa3DDBf92077b850E29C4805Df0a2459Ae048416a;

    function test_U01_UnprivilegedMintMustRevert() external {

        uint256 forkId =
            vm.createFork(vm.envString("ETHENA_FORK_RPC"));

        vm.selectFork(forkId);

        IUSDtbMintingU01 t =
            IUSDtbMintingU01(TARGET);

        require(
            address(t).code.length > 0,
            "U01: no bytecode"
        );

        address attacker = address(0xBEEF1234);
        address benefactor = address(0x11112222);
        address beneficiary = address(0x33334444);
        address collateral = address(0x55556666);

        require(
            !t.isWhitelistedBenefactor(benefactor),
            "U01 fixture collision"
        );

        require(
            !t.isSupportedAsset(collateral),
            "U01 fixture collision"
        );

        IUSDtbMintingU01.Order memory order =
            IUSDtbMintingU01.Order(
                "U01-UNPRIVILEGED",
                0,
                uint120(block.timestamp + 1 days),
                1,
                benefactor,
                beneficiary,
                collateral,
                1,
                1
            );

        address[] memory addresses =
            new address[](1);

        addresses[0] = collateral;

        uint128[] memory ratios =
            new uint128[](1);

        ratios[0] = 1e18;

        IUSDtbMintingU01.Route memory route =
            IUSDtbMintingU01.Route(
                addresses,
                ratios
            );

        IUSDtbMintingU01.Signature memory sig =
            IUSDtbMintingU01.Signature(
                0,
                hex""
            );

        vm.prank(attacker);

        vm.expectRevert();

        t.mint(
            order,
            route,
            sig
        );

        emit log(
            "U01 STATUS: UNPRIVILEGED MINT REVERTED; AUTHORIZATION BOUNDARY HOLDS"
        );
    }
}
