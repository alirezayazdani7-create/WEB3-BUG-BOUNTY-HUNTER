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

    /*
     * Foundry ERC20 deal cheatcode.
     *
     * IMPORTANT:
     * This modifies ONLY the local Anvil fork.
     * It does not modify Ethereum Mainnet.
     */
    function deal(
        address token,
        address to,
        uint256 give
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


interface IEthenaMintingP14 {

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


    function usde()
        external
        view
        returns (address);


    function hashOrder(
        Order calldata order
    )
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


    function verifyRoute(
        Route calldata route
    )
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


contract MintingV2P14FullPathTest {

    /*
     * ============================================================
     * DEPLOYED CONTRACTS
     * ============================================================
     */

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;


    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;


    /*
     * ============================================================
     * LOCAL FORK TEST ACTOR
     * ============================================================
     *
     * This is the standard Anvil local test account.
     *
     * It is NOT a Mainnet key.
     */

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;


    uint256 constant MINTER_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


    /*
     * ============================================================
     * CUSTODIAN USED BY P14
     * ============================================================
     */

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;


    /*
     * ============================================================
     * HEVM CHEATCODE
     * ============================================================
     */

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


    IEthenaMintingP14 constant target =
        IEthenaMintingP14(
            MINTING
        );


    IERC20Minimal constant usdc =
        IERC20Minimal(
            USDC
        );


    /*
     * ============================================================
     * ASSERTIONS
     * ============================================================
     */

    function assertTrue(
        bool value,
        string memory reason
    )
        internal
        pure
    {
        require(
            value,
            reason
        );
    }


    function assertEq(
        uint256 a,
        uint256 b,
        string memory reason
    )
        internal
        pure
    {
        require(
            a == b,
            reason
        );
    }


    function assertEqAddress(
        address a,
        address b,
        string memory reason
    )
        internal
        pure
    {
        require(
            a == b,
            reason
        );
    }


    /*
     * ============================================================
     * SIGN ORDER
     * ============================================================
     */

    function _sign(
        IEthenaMintingP14.Order memory order
    )
        internal
        returns (
            IEthenaMintingP14.Signature memory sig,
            bytes32 digest
        )
    {

        /*
         * Ask the deployed contract for the exact
         * EIP-712 order digest.
         */

        digest =
            target.hashOrder(
                order
            );


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
            IEthenaMintingP14.Signature({
                signature_type:
                    IEthenaMintingP14.SignatureType.EIP712,

                signature_bytes:
                    abi.encodePacked(
                        r,
                        s,
                        v
                    )
            });
    }


    /*
     * ============================================================
     * CUSTODIAN ROUTE
     * ============================================================
     */

    function _route()
        internal
        pure
        returns (
            IEthenaMintingP14.Route memory route
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
            IEthenaMintingP14.Route({
                addresses:
                    addresses,

                ratios:
                    ratios
            });
    }


    /*
     * ============================================================
     * P14-01
     *
     * FULL MINT PATH
     *
     * 999,901 micro-USDC
     *          ↓
     * 1 USDe
     *
     * Expected:
     * ACCEPT
     *
     * Difference from exact parity:
     *
     * 1,000,000 - 999,901 = 99
     * ============================================================
     */

    function test_P14_01_full_mint_accepts_99_unit_gap()
        external
    {

        /*
         * --------------------------------------------------------
         * LOCAL FORK FUNDING
         * --------------------------------------------------------
         *
         * Give the local Anvil tester exactly enough USDC
         * for the boundary mint.
         *
         * This changes ONLY the local fork state.
         *
         * No Mainnet transaction is sent.
         */

        vm.deal(
            USDC,
            MINTER,
            1_000_000
        );


        /*
         * --------------------------------------------------------
         * LOCAL USDC APPROVAL
         * --------------------------------------------------------
         */

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
            "local USDC approval failed"
        );


        /*
         * --------------------------------------------------------
         * INITIAL STATE
         * --------------------------------------------------------
         */

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


        uint256 benefactorUsdcBefore =
            usdc.balanceOf(
                MINTER
            );


        uint256 custodianUsdcBefore =
            usdc.balanceOf(
                CUSTODIAN
            );


        /*
         * --------------------------------------------------------
         * ORDER
         * --------------------------------------------------------
         */

        IEthenaMintingP14.Order memory order =
            IEthenaMintingP14.Order({

                order_id:
                    "P14-99-UNIT-GAP",

                order_type:
                    IEthenaMintingP14.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp + 1 days
                    ),

                nonce:
                    14_990_001,

                benefactor:
                    MINTER,

                beneficiary:
                    MINTER,

                collateral_asset:
                    USDC,

                collateral_amount:
                    999_901,

                usde_amount:
                    1e18
            });


        /*
         * --------------------------------------------------------
         * ROUTE
         * --------------------------------------------------------
         */

        IEthenaMintingP14.Route memory route =
            _route();


        /*
         * --------------------------------------------------------
         * CHECK #1
         *
         * ROUTE
         * --------------------------------------------------------
         */

        assertTrue(
            target.verifyRoute(
                route
            ),
            "P14 route rejected"
        );


        /*
         * --------------------------------------------------------
         * CHECK #2
         *
         * STABLE LIMIT
         * --------------------------------------------------------
         */

        bool stableAccepted =
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                order.collateral_asset,
                order.order_type
            );


        assertTrue(
            stableAccepted,
            "99-unit gap rejected by stable guard"
        );


        /*
         * --------------------------------------------------------
         * CHECK #3
         *
         * EIP-712 SIGNATURE
         * --------------------------------------------------------
         */

        (
            IEthenaMintingP14.Signature memory sig,
            bytes32 digest
        ) =
            _sign(
                order
            );


        /*
         * --------------------------------------------------------
         * CHECK #4
         *
         * DEPLOYED SIGNATURE VALIDATION
         * --------------------------------------------------------
         */

        bytes32 verifiedDigest =
            target.verifyOrder(
                order,
                sig
            );


        assertTrue(
            verifiedDigest == digest,
            "signed order digest mismatch"
        );


        /*
         * --------------------------------------------------------
         * CHECK #5
         *
         * FULL MINT
         * --------------------------------------------------------
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
         * --------------------------------------------------------
         * FINAL STATE
         * --------------------------------------------------------
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


        uint256 benefactorUsdcAfter =
            usdc.balanceOf(
                MINTER
            );


        uint256 custodianUsdcAfter =
            usdc.balanceOf(
                CUSTODIAN
            );


        /*
         * --------------------------------------------------------
         * INVARIANT #1
         *
         * BENEFICIARY RECEIVES EXACT USDe
         * --------------------------------------------------------
         */

        assertEq(
            usdeAfter - usdeBefore,
            1e18,
            "beneficiary USDe delta mismatch"
        );


        /*
         * --------------------------------------------------------
         * INVARIANT #2
         *
         * TOTAL SUPPLY
         * --------------------------------------------------------
         */

        assertEq(
            supplyAfter - supplyBefore,
            1e18,
            "USDe total supply delta mismatch"
        );


        /*
         * --------------------------------------------------------
         * INVARIANT #3
         *
         * BENEFACTOR USDC DEBIT
         * --------------------------------------------------------
         */

        assertEq(
            benefactorUsdcBefore -
                benefactorUsdcAfter,
            999_901,
            "benefactor USDC debit mismatch"
        );


        /*
         * --------------------------------------------------------
         * INVARIANT #4
         *
         * CUSTODIAN USDC CREDIT
         * --------------------------------------------------------
         */

        assertEq(
            custodianUsdcAfter -
                custodianUsdcBefore,
            999_901,
            "custodian USDC credit mismatch"
        );


        /*
         * --------------------------------------------------------
         * INVARIANT #5
         *
         * ECONOMIC GAP
         * --------------------------------------------------------
         */

        uint256 economicGap =
            1_000_000 -
            order.collateral_amount;


        assertEq(
            economicGap,
            99,
            "P14 economic gap is not 99"
        );
    }


    /*
     * ============================================================
     * P14-02
     *
     * FULL MINT PATH
     *
     * 999,900 micro-USDC
     *          ↓
     * 1 USDe
     *
     * Expected:
     * REJECT
     *
     * Difference:
     *
     * 1,000,000 - 999,900 = 100
     * ============================================================
     */

    function test_P14_02_full_mint_rejects_100_unit_gap()
        external
    {

        /*
         * No USDC funding is required here.
         *
         * The test must reject at the stable-limit
         * boundary before collateral transfer.
         */

        IEthenaMintingP14.Order memory order =
            IEthenaMintingP14.Order({

                order_id:
                    "P14-100-UNIT-GAP",

                order_type:
                    IEthenaMintingP14.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp + 1 days
                    ),

                nonce:
                    14_990_002,

                benefactor:
                    MINTER,

                beneficiary:
                    MINTER,

                collateral_asset:
                    USDC,

                collateral_amount:
                    999_900,

                usde_amount:
                    1e18
            });


        /*
         * --------------------------------------------------------
         * ROUTE
         * --------------------------------------------------------
         */

        IEthenaMintingP14.Route memory route =
            _route();


        /*
         * --------------------------------------------------------
         * PRECONDITION
         *
         * STABLE GUARD MUST REJECT
         * --------------------------------------------------------
         */

        bool stableAccepted =
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                order.collateral_asset,
                order.order_type
            );


        assertTrue(
            !stableAccepted,
            "100-unit gap unexpectedly accepted"
        );


        /*
         * --------------------------------------------------------
         * SIGN ORDER
         * --------------------------------------------------------
         */

        (
            IEthenaMintingP14.Signature memory sig,
            bytes32 digest
        ) =
            _sign(
                order
            );


        /*
         * --------------------------------------------------------
         * VERIFY SIGNATURE
         * --------------------------------------------------------
         */

        bytes32 verifiedDigest =
            target.verifyOrder(
                order,
                sig
            );


        assertTrue(
            verifiedDigest == digest,
            "100-gap signature verification failed"
        );


        /*
         * --------------------------------------------------------
         * EXECUTE FULL MINT
         *
         * Low-level call converts revert into bool.
         * --------------------------------------------------------
         */

        vm.prank(
            MINTER
        );


        (
            bool ok,
            bytes memory revertData
        ) =
            address(target).call(
                abi.encodeWithSelector(
                    IEthenaMintingP14.mint.selector,
                    order,
                    route,
                    sig
                )
            );


        /*
         * --------------------------------------------------------
         * EXPECT REVERT
         * --------------------------------------------------------
         */

        assertTrue(
            !ok,
            "full mint path accepted 100-unit gap"
        );


        /*
         * Keep diagnostic data referenced.
         */

        revertData;
    }
}
