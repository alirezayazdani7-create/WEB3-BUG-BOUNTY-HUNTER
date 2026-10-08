// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IERC20U03V2 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IPSMU03V2 {
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

    function swap(Order calldata order) external;

    function getBenefactorConfig(address benefactor)
        external
        view
        returns (
            bool active,
            uint128 maxSwapForAssetPerEpoch,
            uint128 maxSwapForCollateralPerEpoch,
            uint128 maxSwapForAssetPerPeriod,
            uint128 maxSwapForCollateralPerPeriod
        );
}

interface IAccessControlU03V2 {
    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);
}

contract U03CrossContractV2Probe is Test {

    // Ethena USDtb PSM
    address constant PSM =
        address(bytes20(hex"73E35C5c35A274E34AdE6EB13cC7f62aEE323728"));

    // Ethena USDtb
    address constant USDTB =
        address(bytes20(hex"c139190f447e929f090edeb554d95abb8b18ac1c"));

    // Ethereum mainnet USDC
    address constant USDC =
        address(bytes20(hex"A0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));

    // Ethena Minting V2
    address constant ETHENA_MINTING_V2 =
        address(bytes20(hex"e3490297a08d6fC8Da46Edb7B6142E4F461b62D3"));

    bytes32 constant MINTER_ROLE =
        keccak256("MINTER_ROLE");

    bytes32 constant REDEEMER_ROLE =
        keccak256("REDEEMER_ROLE");

    function _fork() internal {
        uint256 forkId =
            vm.createFork(vm.envString("ETHENA_FORK_RPC"));

        vm.selectFork(forkId);

        require(
            PSM.code.length > 0,
            "U03V2: PSM bytecode missing"
        );

        require(
            USDTB.code.length > 0,
            "U03V2: USDtb bytecode missing"
        );

        require(
            USDC.code.length > 0,
            "U03V2: USDC bytecode missing"
        );

        require(
            ETHENA_MINTING_V2.code.length > 0,
            "U03V2: Minting V2 bytecode missing"
        );
    }

    function test_U03V2_CrossContractAuthorizationIsolation()
        external
    {
        _fork();

        address attacker = address(0xCAFE1234);
        address benefactor = address(0xABCD1234);
        address beneficiary = address(0xBEEF5678);

        IPSMU03V2 psm = IPSMU03V2(PSM);

        (
            bool active,
            ,
            ,
            ,
        ) = psm.getBenefactorConfig(benefactor);

        require(
            !active,
            "U03V2: unexpected active benefactor fixture"
        );

        uint256 supplyBefore =
            IERC20U03V2(USDTB).totalSupply();

        uint256 psmUsdtbBefore =
            IERC20U03V2(USDTB).balanceOf(PSM);

        uint256 psmUsdcBefore =
            IERC20U03V2(USDC).balanceOf(PSM);

        IPSMU03V2.Order memory order =
            IPSMU03V2.Order({
                isSwapForAsset: true,
                expiry: uint120(block.timestamp + 1 hours),
                nonce: uint128(1),
                chainId: block.chainid,
                benefactor: benefactor,
                beneficiary: beneficiary,
                collateral: USDC,
                amountIn: uint128(1e6),
                minAmountOut: uint128(1)
            });

        vm.prank(attacker);

        vm.expectRevert();

        psm.swap(order);

        uint256 supplyAfter =
            IERC20U03V2(USDTB).totalSupply();

        uint256 psmUsdtbAfter =
            IERC20U03V2(USDTB).balanceOf(PSM);

        uint256 psmUsdcAfter =
            IERC20U03V2(USDC).balanceOf(PSM);

        require(
            supplyAfter == supplyBefore,
            "U03V2 ALERT: USDtb supply changed"
        );

        require(
            psmUsdtbAfter == psmUsdtbBefore,
            "U03V2 ALERT: PSM USDtb balance changed"
        );

        require(
            psmUsdcAfter == psmUsdcBefore,
            "U03V2 ALERT: PSM USDC balance changed"
        );

        emit log_string(
            "U03V2 PASS: unauthorized PSM state transition blocked"
        );
    }

    function test_U03V2_MintingV2RoleIsolation()
        external
    {
        _fork();

        IAccessControlU03V2 minting =
            IAccessControlU03V2(ETHENA_MINTING_V2);

        address attacker =
            address(0xDEAD1234);

        bool attackerMinter =
            minting.hasRole(
                MINTER_ROLE,
                attacker
            );

        bool attackerRedeemer =
            minting.hasRole(
                REDEEMER_ROLE,
                attacker
            );

        require(
            !attackerMinter,
            "U03V2: attacker unexpectedly has MINTER_ROLE"
        );

        require(
            !attackerRedeemer,
            "U03V2: attacker unexpectedly has REDEEMER_ROLE"
        );

        emit log_string(
            "U03V2 PASS: attacker has no Minting V2 privileged role"
        );
    }

    function test_U03V2_CrossContractStateRemainsStable()
        external
    {
        _fork();

        uint256 supplyBefore =
            IERC20U03V2(USDTB).totalSupply();

        uint256 psmUsdtbBefore =
            IERC20U03V2(USDTB).balanceOf(PSM);

        uint256 psmUsdcBefore =
            IERC20U03V2(USDC).balanceOf(PSM);

        address attacker =
            address(0xBADF00D);

        vm.startPrank(attacker);

        IPSMU03V2.Order memory invalidOrder =
            IPSMU03V2.Order({
                isSwapForAsset: true,
                expiry: uint120(block.timestamp + 1 hours),
                nonce: uint128(999),
                chainId: block.chainid,
                benefactor: attacker,
                beneficiary: attacker,
                collateral: USDC,
                amountIn: uint128(1e6),
                minAmountOut: uint128(1)
            });

        vm.expectRevert();

        IPSMU03V2(PSM).swap(invalidOrder);

        vm.stopPrank();

        uint256 supplyAfter =
            IERC20U03V2(USDTB).totalSupply();

        uint256 psmUsdtbAfter =
            IERC20U03V2(USDTB).balanceOf(PSM);

        uint256 psmUsdcAfter =
            IERC20U03V2(USDC).balanceOf(PSM);

        assertEq(
            supplyAfter,
            supplyBefore,
            "U03V2 ALERT: supply changed"
        );

        assertEq(
            psmUsdtbAfter,
            psmUsdtbBefore,
            "U03V2 ALERT: PSM USDtb balance changed"
        );

        assertEq(
            psmUsdcAfter,
            psmUsdcBefore,
            "U03V2 ALERT: PSM USDC balance changed"
        );

        emit log_string(
            "U03V2 PASS: cross-contract state remained unchanged"
        );
    }
}
