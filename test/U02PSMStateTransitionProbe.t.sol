// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IPSMU02 {
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

    function swap(Order calldata) external;

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
}

contract U02PSMStateTransitionProbe is Test {

    address constant PSM =
        0x73E35C5c35A274E34AdE6EB13cC7f62aEE323728;

    address constant USDC =
        0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;

    function test_U02_UnapprovedBenefactorMustRevert() external {

        uint256 forkId =
            vm.createFork(vm.envString("ETHENA_FORK_RPC"));

        vm.selectFork(forkId);

        IPSMU02 t = IPSMU02(PSM);

        require(
            address(t).code.length > 0,
            "U02: no PSM bytecode"
        );

        require(
            USDC.code.length > 0,
            "U02: no USDC bytecode"
        );

        address attacker =
            address(0xCAFE1234);

        address benefactor =
            address(0xABCD1234);

        (
            bool active,
            ,
            ,
            ,
            
        ) = t.getBenefactorConfig(
            benefactor
        );

        require(
            !active,
            "U02 fixture collision"
        );

        IPSMU02.Order memory order =
            IPSMU02.Order(
                true,
                uint120(block.timestamp + 1 days),
                1,
                block.chainid,
                benefactor,
                attacker,
                USDC,
                1,
                1
            );

        vm.prank(attacker);

        vm.expectRevert();

        t.swap(order);

        emit log(
            "U02 STATUS: UNAPPROVED BENEFACTOR SWAP REVERTED; PSM AUTHORIZATION BOUNDARY HOLDS"
        );
    }
}
