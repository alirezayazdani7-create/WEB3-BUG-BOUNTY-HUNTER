// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function sign(
        uint256 privateKey,
        bytes32 digest
    )
        external
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        );

    function prank(address msgSender) external;

    function store(
        address target,
        bytes32 slot,
        bytes32 value
    ) external;
}


interface IERC20Minimal {

    function balanceOf(
        address account
    )
        external
        view
        returns (uint256);

    function approve(
        address spender,
        uint256 amount
    )
        external
        returns (bool);
}


interface IUSDeMinimal is IERC20Minimal {

    function totalSupply()
        external
        view
        returns (uint256);
}


interface IEthenaMintingP15 {

    enum SignatureType {
        EIP712,
        EIP1271
    }

    enum OrderType {
        MINT,
        REDEEM
    }

    struct Order {
        string order_id;
        OrderType order_type;
        uint120 expiry;
        uint128 nonce;
        address benefactor;
        address beneficiary;
        address collateral_asset;
        uint128 collateral_amount;
        uint128 usde_amount;
    }

    struct Route {
        address[] addresses;
        uint128[] ratios;
    }

    struct Signature {
        SignatureType signature_type;
        bytes signature_bytes;
    }

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

    function usde()
        external
        view
        returns (address);

    function stablesDeltaLimit()
        external
        view
        returns (uint128);

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

    function hashOrder(Order calldata order)
        external
        view
        returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    )
        external
        view
        returns (bytes32);

    function verifyRoute(Route calldata route)
        external
        view
        returns (bool);

    function verifyStablesLimit(
        uint128 collateralAmount,
        uint128 usdeAmount,
        address collateralAsset,
        OrderType orderType
    )
        external
        view
        returns (bool);

    function mint(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    )
        external;
}


contract MintingV2P15ScalingTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    /*
     * Standard Anvil local key.
     *
     * 0x01 derives exactly to MINTER.
     *
     * LOCAL FORK ONLY.
     */
    uint256 constant MINTER_PRIVATE_KEY = 1;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;


    Vm constant vm =
        Vm(
            address(
                uint160(
                    uint256(
                        keccak256(
                            "hevm cheat code"
                        )
                    )
                )
            )
        );


    IEthenaMintingP15 constant target =
        IEthenaMintingP15(MINTING);


    IERC20Minimal constant usdc =
        IERC20Minimal(USDC);


    function assertTrue(
        bool value,
        string memory reason
    )
        internal
        pure
    {
        require(value, reason);
    }


    function assertEq(
        uint256 a,
        uint256 b,
        string memory reason
    )
        internal
        pure
    {
        require(a == b, reason);
    }


    /*
     * ------------------------------------------------------------
     * LOCAL USDC STORAGE
     * ------------------------------------------------------------
     *
     * Circle USDC storage:
     *
     * balanceAndBlacklistStates = slot 9
     *
     * Mapping:
     *
     * keccak256(abi.encode(account, 9))
     *
     * LOCAL FORK ONLY.
     */

    function _setUsdcBalance(
        uint256 amount
    )
        internal
    {

        bytes32 slot =
            keccak256(
                abi.encode(
                    MINTER,
                    uint256(9)
                )
            );


        vm.store(
            USDC,
            slot,
            bytes32(amount)
        );


        assertEq(
            usdc.balanceOf(MINTER),
            amount,
            "USDC local balance injection failed"
        );
    }


    /*
     * ------------------------------------------------------------
     * SIGN
     * ------------------------------------------------------------
     */

    function _sign(
        IEthenaMintingP15.Order memory order
    )
        internal
        returns (
            IEthenaMintingP15.Signature memory sig,
            bytes32 digest
        )
    {

        digest =
            target.hashOrder(order);


        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                MINTER_PRIVATE_KEY,
                digest
            );


        sig =
            IEthenaMintingP15.Signature({
                signature_type:
                    IEthenaMintingP15.SignatureType.EIP712,

                signature_bytes:
                    abi.encodePacked(
                        r,
                        s,
                        v
                    )
            });
    }


    /*
     * ------------------------------------------------------------
     * ROUTE
     * ------------------------------------------------------------
     */

    function _route()
        internal
        pure
        returns (
            IEthenaMintingP15.Route memory route
        )
    {

        address[] memory addresses =
            new address[](1);

        uint128[] memory ratios =
            new uint128[](1);


        addresses[0] =
            CUSTODIAN;

        ratios[0] =
            10_000;


        route =
            IEthenaMintingP15.Route({
                addresses: addresses,
                ratios: ratios
            });
    }


    /*
     * ------------------------------------------------------------
     * CALCULATE MAXIMUM ACCEPTED DEFICIT
     * ------------------------------------------------------------
     *
     * stablesDeltaLimit = 0
     *
     * The deployed contract calculates:
     *
     * differenceInBps =
     *     (difference * 10000) / usdeAmount
     *
     * Therefore with limit 0:
     *
     * difference * 10000 < usdeAmount
     *
     * Maximum accepted difference:
     *
     * floor((usdeAmount - 1) / 10000)
     *
     * The result here is expressed in USDe base units.
     */

    function _maxAcceptedDifference(
        uint128 usdeAmount
    )
        internal
        pure
        returns (uint128)
    {

        return
            uint128(
                (uint256(usdeAmount) - 1) /
                10_000
            );
    }


    /*
     * ------------------------------------------------------------
     * CONVERT USDe BASE DIFFERENCE TO USDC MICRO UNITS
     * ------------------------------------------------------------
     *
     * USDe = 18 decimals
     * USDC = 6 decimals
     *
     * 1 USDC micro-unit =
     * 1e12 USDe base units.
     */

    function _deficitInUsdcUnits(
        uint128 usdeAmount
    )
        internal
        pure
        returns (uint128)
    {

        return
            uint128(
                uint256(
                    _maxAcceptedDifference(
                        usdeAmount
                    )
                ) /
                1e12
            );
    }


    /*
     * ------------------------------------------------------------
     * BOUNDARY MATRIX
     * ------------------------------------------------------------
     */

    function test_P15_scaling_boundaries()
        external
    {

        uint128[4] memory amounts = [
            uint128(1e18),
            uint128(10e18),
            uint128(100e18),
            uint128(1000e18)
        ];


        uint128[4] memory expectedDeficits = [
            uint128(99),
            uint128(999),
            uint128(9999),
            uint128(99999)
        ];


        for (uint256 i = 0; i < amounts.length; ++i) {

            uint128 usdeAmount =
                amounts[i];


            uint128 deficit =
                _deficitInUsdcUnits(
                    usdeAmount
                );


            assertEq(
                deficit,
                expectedDeficits[i],
                "unexpected scaling deficit"
            );


            uint128 parityCollateral =
                uint128(
                    uint256(usdeAmount) /
                    1e12
                );


            uint128 acceptedCollateral =
                parityCollateral -
                deficit;


            bool accepted =
                target.verifyStablesLimit(
                    acceptedCollateral,
                    usdeAmount,
                    USDC,
                    IEthenaMintingP15.OrderType.MINT
                );


            assertTrue(
                accepted,
                "scaled boundary should be accepted"
            );


            bool rejected =
                target.verifyStablesLimit(
                    acceptedCollateral - 1,
                    usdeAmount,
                    USDC,
                    IEthenaMintingP15.OrderType.MINT
                );


            assertTrue(
                !rejected,
                "one-unit-below boundary should reject"
            );
        }
    }


    /*
     * ------------------------------------------------------------
     * FULL ECONOMIC TEST
     *
     * 1,000 USDe
     *
     * Parity:
     *
     * 1,000 USDC
     *
     * Maximum accepted deficit:
     *
     * 99,999 micro-USDC
     *
     * Therefore:
     *
     * collateral =
     * 999.900001 USDC
     *
     * USDe minted:
     * 1,000 USDe
     *
     * ------------------------------------------------------------
     */

    function test_P15_full_mint_1000_usde()
        external
    {

        uint128 usdeAmount =
            1000e18;


        uint128 maxAcceptedDeficit =
            _deficitInUsdcUnits(
                usdeAmount
            );


        assertEq(
            maxAcceptedDeficit,
            99_999,
            "unexpected 1000-USDe deficit"
        );


        uint128 parityCollateral =
            uint128(
                uint256(usdeAmount) /
                1e12
            );


        uint128 collateralAmount =
            parityCollateral -
            maxAcceptedDeficit;


        /*
         * 1,000,000,000 micro-USDC
         * - 99,999 micro-USDC
         *
         * = 999,900,001 micro-USDC
         */

        assertEq(
            collateralAmount,
            999_900_001,
            "unexpected scaled collateral"
        );


        /*
         * Check configured limits before execution.
         */

        (
            ,
            bool assetActive,
            uint128 maxMintPerBlock,
            
        ) =
            target.tokenConfig(
                USDC
            );


        (
            uint128 globalMaxMintPerBlock,
            
        ) =
            target.globalConfig();


        assertTrue(
            assetActive,
            "USDC is not active"
        );


        assertTrue(
            maxMintPerBlock >= usdeAmount,
            "USDC per-block limit below P15 size"
        );


        assertTrue(
            globalMaxMintPerBlock >= usdeAmount,
            "global per-block limit below P15 size"
        );


        /*
         * Stable boundary.
         */

        assertTrue(
            target.verifyStablesLimit(
                collateralAmount,
                usdeAmount,
                USDC,
                IEthenaMintingP15.OrderType.MINT
            ),
            "1000-USDe scaled boundary rejected"
        );


        assertTrue(
            !target.verifyStablesLimit(
                collateralAmount - 1,
                usdeAmount,
                USDC,
                IEthenaMintingP15.OrderType.MINT
            ),
            "1000-USDe boundary accepted one unit further"
        );


        /*
         * Fund exact collateral on local fork.
         */

        _setUsdcBalance(
            collateralAmount
        );


        vm.prank(
            MINTER
        );


        bool approvalOk =
            usdc.approve(
                MINTING,
                type(uint256).max
            );


        assertTrue(
            approvalOk,
            "USDC approval failed"
        );


        address usdeAddress =
            target.usde();


        uint256 usdeBefore =
            IUSDeMinimal(
                usdeAddress
            ).balanceOf(
                MINTER
            );


        uint256 supplyBefore =
            IUSDeMinimal(
                usdeAddress
            ).totalSupply();


        uint256 usdcBefore =
            usdc.balanceOf(
                MINTER
            );


        /*
         * Build signed order.
         */

        IEthenaMintingP15.Order memory order =
            IEthenaMintingP15.Order({

                order_id:
                    "P15-1000-USDE-SCALE",

                order_type:
                    IEthenaMintingP15.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp + 1 days
                    ),

                nonce:
                    15_001_000,

                benefactor:
                    MINTER,

                beneficiary:
                    MINTER,

                collateral_asset:
                    USDC,

                collateral_amount:
                    collateralAmount,

                usde_amount:
                    usdeAmount
            });


        IEthenaMintingP15.Route memory route =
            _route();


        assertTrue(
            target.verifyRoute(route),
            "P15 route rejected"
        );


        (
            IEthenaMintingP15.Signature memory sig,
            
        ) =
            _sign(order);


        /*
         * Full deployed signature validation.
         */

        target.verifyOrder(
            order,
            sig
        );


        /*
         * Full deployed mint.
         */

        vm.prank(
            MINTER
        );


        target.mint(
            order,
            route,
            sig
        );


        /*
         * Accounting.
         */

        uint256 usdeAfter =
            IUSDeMinimal(
                usdeAddress
            ).balanceOf(
                MINTER
            );


        uint256 supplyAfter =
            IUSDeMinimal(
                usdeAddress
            ).totalSupply();


        uint256 usdcAfter =
            usdc.balanceOf(
                MINTER
            );


        assertEq(
            usdeAfter - usdeBefore,
            usdeAmount,
            "USDe beneficiary delta mismatch"
        );


        assertEq(
            supplyAfter - supplyBefore,
            usdeAmount,
            "USDe supply delta mismatch"
        );


        assertEq(
            usdcBefore - usdcAfter,
            collateralAmount,
            "USDC collateral debit mismatch"
        );


        /*
         * Economic shortfall.
         */

        uint256 theoreticalParity =
            uint256(usdeAmount) /
            1e12;


        uint256 actualCollateral =
            collateralAmount;


        uint256 economicShortfall =
            theoreticalParity -
            actualCollateral;


        assertEq(
            economicShortfall,
            99_999,
            "economic shortfall mismatch"
        );
    }
}
