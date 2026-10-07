// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;

    function deal(
        address who,
        uint256 newBalance
    ) external;
}

interface IERC20P20 {
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

interface IWETHP20 {
    function deposit()
        external
        payable;

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

interface IUSDeP20 {
    function balanceOf(
        address account
    )
        external
        view
        returns (uint256);
}

interface IEthenaMintingP20 {

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

    function owner()
        external
        view
        returns (address);

    function hasRole(
        bytes32 role,
        address account
    )
        external
        view
        returns (bool);

    function addWhitelistedBenefactor(
        address benefactor
    )
        external;

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

    function mintWETH(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    )
        external;
}


contract P20Valid1271Wallet {

    bytes4 internal constant MAGICVALUE =
        0x1626ba7e;

    bytes4 internal constant FAILVALUE =
        0xffffffff;

    bytes32 public approvedDigest;


    function setApprovedDigest(
        bytes32 digest
    )
        external
    {
        approvedDigest =
            digest;
    }


    function execute(
        address target,
        bytes calldata data
    )
        external
        returns (bytes memory)
    {
        (
            bool ok,
            bytes memory ret
        ) =
            target.call(data);

        require(
            ok,
            "wallet execute failed"
        );

        return ret;
    }


    function executeValue(
        address target,
        bytes calldata data
    )
        external
        payable
        returns (bytes memory)
    {
        (
            bool ok,
            bytes memory ret
        ) =
            target.call{
                value: msg.value
            }(
                data
            );

        require(
            ok,
            "wallet execute value failed"
        );

        return ret;
    }


    function isValidSignature(
        bytes32 hash,
        bytes calldata
    )
        external
        view
        returns (bytes4)
    {
        if (
            hash ==
            approvedDigest
        ) {
            return MAGICVALUE;
        }

        return FAILVALUE;
    }


    receive()
        external
        payable
    {}
}


contract MintingV2P20WETHFullPathTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant USDe =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;


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


    IEthenaMintingP20 constant target =
        IEthenaMintingP20(
            MINTING
        );


    IWETHP20 constant weth =
        IWETHP20(
            WETH
        );


    IUSDeP20 constant usde =
        IUSDeP20(
            USDe
        );


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


    function _minterRole()
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                "MINTER_ROLE"
            );
    }


    function _authorize(
        address wallet
    )
        internal
    {
        vm.prank(
            target.owner()
        );

        target.addWhitelistedBenefactor(
            wallet
        );
    }


    function _fundAndApproveWETH(
        P20Valid1271Wallet wallet,
        uint256 amount
    )
        internal
    {
        /*
         * Give the test wallet native ETH.
         */
        vm.deal(
            address(wallet),
            amount
        );


        /*
         * Wrap ETH -> WETH.
         *
         * This is performed through the wallet so
         * the WETH balance belongs to the benefactor.
         */
        wallet.executeValue{
            value: amount
        }(
            WETH,
            abi.encodeWithSelector(
                IWETHP20.deposit.selector
            )
        );


        /*
         * Confirm WETH was actually created.
         */
        assertEq(
            weth.balanceOf(
                address(wallet)
            ),
            amount,
            "wallet WETH funding failed"
        );


        /*
         * Allow Ethena Minting V2 to pull WETH.
         */
        wallet.execute(
            WETH,
            abi.encodeWithSelector(
                IWETHP20.approve.selector,
                MINTING,
                type(uint256).max
            )
        );
    }


    function _order(
        address wallet,
        uint128 nonce,
        string memory orderId,
        uint128 collateralAmount,
        uint128 usdeAmount
    )
        internal
        view
        returns (
            IEthenaMintingP20.Order memory o
        )
    {
        o =
            IEthenaMintingP20.Order({

                order_id:
                    orderId,

                order_type:
                    IEthenaMintingP20.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp +
                        1 days
                    ),

                nonce:
                    nonce,

                benefactor:
                    wallet,

                beneficiary:
                    wallet,

                collateral_asset:
                    WETH,

                collateral_amount:
                    collateralAmount,

                usde_amount:
                    usdeAmount
            });
    }


    function _route()
        internal
        pure
        returns (
            IEthenaMintingP20.Route memory r
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

        r =
            IEthenaMintingP20.Route({

                addresses:
                    addresses,

                ratios:
                    ratios
            });
    }


    function _sig()
        internal
        pure
        returns (
            IEthenaMintingP20.Signature memory s
        )
    {
        s =
            IEthenaMintingP20.Signature({

                signature_type:
                    IEthenaMintingP20.SignatureType.EIP1271,

                signature_bytes:
                    hex"5032302d57455448"
            });
    }


    /*
     * ============================================================
     * TEST 1
     * ============================================================
     *
     * Full WETH mint path:
     *
     * ETH
     *  ->
     * WETH
     *  ->
     * ERC-1271 authorization
     *  ->
     * mintWETH()
     *  ->
     * WETH collateral
     *  ->
     * ETH custody route
     *  ->
     * USDe mint
     */
    function test_P20_WETH_full_mint_path_passes()
        external
    {
        P20Valid1271Wallet wallet =
            new P20Valid1271Wallet();


        _authorize(
            address(wallet)
        );


        uint256 collateral =
            1 ether;


        uint256 usdeAmount =
            1e18;


        _fundAndApproveWETH(
            wallet,
            collateral
        );


        /*
         * The wallet should now hold WETH,
         * not native ETH.
         */
        assertEq(
            address(wallet).balance,
            0,
            "wallet still holds native ETH"
        );


        assertEq(
            weth.balanceOf(
                address(wallet)
            ),
            collateral,
            "unexpected WETH balance before mint"
        );


        IEthenaMintingP20.Order memory order =
            _order(
                address(wallet),
                20001001,
                "P20-WETH-FULL-PATH",
                uint128(
                    collateral
                ),
                uint128(
                    usdeAmount
                )
            );


        /*
         * ERC-1271 signs exactly this order hash.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                order
            )
        );


        IEthenaMintingP20.Route memory route =
            _route();


        IEthenaMintingP20.Signature memory sig =
            _sig();


        /*
         * Route must be accepted.
         */
        assertTrue(
            target.verifyRoute(
                route
            ),
            "valid WETH custody route rejected"
        );


        /*
         * Order authorization must be accepted.
         */
        target.verifyOrder(
            order,
            sig
        );


        /*
         * Local MINTER authorization must exist.
         */
        assertTrue(
            target.hasRole(
                _minterRole(),
                MINTER
            ),
            "MINTER_ROLE missing"
        );


        uint256 custodianBefore =
            CUSTODIAN.balance;


        uint256 usdeBefore =
            usde.balanceOf(
                address(wallet)
            );


        /*
         * Execute the actual WETH-specific path.
         */
        vm.startPrank(
            MINTER
        );

        target.mintWETH(
            order,
            route,
            sig
        );

        vm.stopPrank();


        /*
         * WETH must have been consumed.
         */
        assertEq(
            weth.balanceOf(
                address(wallet)
            ),
            0,
            "WETH collateral was not consumed"
        );


        /*
         * Native ETH should also not remain
         * in the benefactor wallet.
         */
        assertEq(
            address(wallet).balance,
            0,
            "unexpected native ETH remained in wallet"
        );


        /*
         * Custodian should receive the exact
         * collateral amount through the WETH -> ETH path.
         */
        assertEq(
            CUSTODIAN.balance,
            custodianBefore +
            collateral,
            "custodian ETH amount mismatch"
        );


        /*
         * USDe must be minted to the signed beneficiary.
         */
        assertEq(
            usde.balanceOf(
                address(wallet)
            ),
            usdeBefore +
            usdeAmount,
            "USDe beneficiary balance mismatch"
        );
    }


    /*
     * ============================================================
     * TEST 2
     * ============================================================
     *
     * The WETH-specific execution path must not accept
     * a different collateral asset merely because the
     * authorization is otherwise valid.
     */
    function test_P20_mintWETH_rejects_nonWETH_collateral()
        external
    {
        P20Valid1271Wallet wallet =
            new P20Valid1271Wallet();


        _authorize(
            address(wallet)
        );


        uint256 collateral =
            1 ether;


        _fundAndApproveWETH(
            wallet,
            collateral
        );


        IEthenaMintingP20.Order memory order =
            _order(
                address(wallet),
                20001002,
                "P20-NON-WETH",
                uint128(
                    collateral
                ),
                uint128(
                    1e18
                )
            );


        /*
         * Mutate ONLY the collateral asset.
         *
         * The original signed authorization is for WETH.
         */
        order.collateral_asset =
            USDC;


        wallet.setApprovedDigest(
            target.hashOrder(
                _order(
                    address(wallet),
                    20001002,
                    "P20-NON-WETH",
                    uint128(
                        collateral
                    ),
                    uint128(
                        1e18
                    )
                )
            )
        );


        IEthenaMintingP20.Route memory route =
            _route();


        IEthenaMintingP20.Signature memory sig =
            _sig();


        /*
         * Full-path call must fail.
         *
         * We intentionally do not depend on the exact
         * custom-error selector here; the security property
         * is that mintWETH() cannot process a non-WETH asset.
         */
        vm.startPrank(
            MINTER
        );

        (
            bool ok,
        ) =
            MINTING.call(
                abi.encodeWithSelector(
                    target.mintWETH.selector,
                    order,
                    route,
                    sig
                )
            );

        vm.stopPrank();


        assertTrue(
            !ok,
            "mintWETH accepted non-WETH collateral"
        );


        /*
         * WETH must remain untouched after rejection.
         */
        assertEq(
            weth.balanceOf(
                address(wallet)
            ),
            collateral,
            "WETH changed after rejected non-WETH path"
        );
    }


    /*
     * ============================================================
     * TEST 3
     * ============================================================
     *
     * A valid ERC-1271 WETH order must not allow the caller
     * to redirect collateral through a malicious route.
     */
    function test_P20_mutated_route_cannot_redirect_WETH()
        external
    {
        P20Valid1271Wallet wallet =
            new P20Valid1271Wallet();


        _authorize(
            address(wallet)
        );


        uint256 collateral =
            1 ether;


        _fundAndApproveWETH(
            wallet,
            collateral
        );


        IEthenaMintingP20.Order memory order =
            _order(
                address(wallet),
                20001003,
                "P20-WETH-ROUTE",
                uint128(
                    collateral
                ),
                uint128(
                    1e18
                )
            );


        wallet.setApprovedDigest(
            target.hashOrder(
                order
            )
        );


        /*
         * Malicious destination.
         */
        address[] memory addresses =
            new address[](1);

        uint128[] memory ratios =
            new uint128[](1);

        addresses[0] =
            address(0xbeef);

        ratios[0] =
            10_000;


        IEthenaMintingP20.Route memory malicious =
            IEthenaMintingP20.Route({

                addresses:
                    addresses,

                ratios:
                    ratios
            });


        IEthenaMintingP20.Signature memory sig =
            _sig();


        /*
         * Route must fail validation.
         */
        assertTrue(
            !target.verifyRoute(
                malicious
            ),
            "malicious WETH route unexpectedly passed"
        );


        /*
         * Attempt full execution anyway.
         */
        vm.startPrank(
            MINTER
        );

        (
            bool ok,
        ) =
            MINTING.call(
                abi.encodeWithSelector(
                    target.mintWETH.selector,
                    order,
                    malicious,
                    sig
                )
            );

        vm.stopPrank();


        assertTrue(
            !ok,
            "malicious WETH route reached execution"
        );


        /*
         * Collateral must remain with the benefactor.
         */
        assertEq(
            weth.balanceOf(
                address(wallet)
            ),
            collateral,
            "WETH changed despite rejected route"
        );
    }
}
