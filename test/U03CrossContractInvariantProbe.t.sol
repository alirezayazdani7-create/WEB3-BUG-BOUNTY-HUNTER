// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IERC20U03 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IPSMU03 {
    struct Order {
        bool isSwapForAsset;
        uint120 expiry;
        uint128 nonce;
        uint256 chainId;
        address benefactor;
        address beneficiary;
        address collateral;
        uint128 amountIn;
        uint128 minAmountOut;
    }

    function getBenefactorConfig(address)
        external
        view
        returns (
            bool,
            uint128,
            uint128,
            uint128,
            uint128
        );

    function swap(Order calldata) external;
}

contract U03CrossContractInvariantProbe is Test {

    address constant PSM =
        address(
            bytes20(
                hex"73E35C5c35A274E34AdE6EB13cC7f62aEE323728"
            )
        );

    address constant USDTB =
        address(
            bytes20(
                hex"c139190f447e929f090edb554d95abb8b18ac1c"
            )
        );

    address constant USDC =
        address(
            bytes20(
                hex"A0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
            )
        );


    function _fork() internal {

        uint256 forkId =
            vm.createFork(
                vm.envString("ETHENA_FORK_RPC")
            );

        vm.selectFork(forkId);

        require(
            PSM.code.length > 0,
            "U03: PSM has no bytecode"
        );

        require(
            USDTB.code.length > 0,
            "U03: USDtb has no bytecode"
        );

        require(
            USDC.code.length > 0,
            "U03: USDC has no bytecode"
        );
    }


    function test_U03_PSMAuthorizationAndStateIsolation()
        external
    {
        _fork();

        IPSMU03 psm =
            IPSMU03(PSM);

        address attacker =
            address(0xCAFE1234);

        address benefactor =
            address(0xABCD1234);

        address beneficiary =
            address(0xBEEF5678);


        (
            bool active,
            ,
            ,
            ,
            
        ) =
            psm.getBenefactorConfig(
                benefactor
            );


        require(
            !active,
            "U03 fixture collision"
        );


        uint256 supplyBefore =
            IERC20U03(USDTB).totalSupply();

        uint256 psmUsdtbBefore =
            IERC20U03(USDTB).balanceOf(PSM);

        uint256 psmUsdcBefore =
            IERC20U03(USDC).balanceOf(PSM);


        IPSMU03.Order memory order =
            IPSMU03.Order(
                true,
                uint120(
                    block.timestamp + 1 days
                ),
                777,
                block.chainid,
                benefactor,
                beneficiary,
                USDC,
                1,
                1
            );


        vm.prank(attacker);

        vm.expectRevert();

        psm.swap(order);


        uint256 supplyAfter =
            IERC20U03(USDTB).totalSupply();

        uint256 psmUsdtbAfter =
            IERC20U03(USDTB).balanceOf(PSM);

        uint256 psmUsdcAfter =
            IERC20U03(USDC).balanceOf(PSM);


        require(
            supplyAfter == supplyBefore,
            "U03 ALERT: unauthorized path changed USDtb supply"
        );

        require(
            psmUsdtbAfter == psmUsdtbBefore,
            "U03 ALERT: unauthorized path changed PSM USDtb balance"
        );

        require(
            psmUsdcAfter == psmUsdcBefore,
            "U03 ALERT: unauthorized path changed PSM collateral balance"
        );


        emit log(
            "U03 STATUS: UNAUTHORIZED CROSS-CONTRACT STATE TRANSITION BLOCKED"
        );

        emit log_named_uint(
            "U03 USDtb supply delta",
            supplyAfter - supplyBefore
        );

        emit log_named_uint(
            "U03 PSM USDtb balance delta",
            psmUsdtbAfter - psmUsdtbBefore
        );

        emit log_named_uint(
            "U03 PSM USDC balance delta",
            psmUsdcAfter - psmUsdcBefore
        );
    }
}
