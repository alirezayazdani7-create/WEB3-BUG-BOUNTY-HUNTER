// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;

    function store(
        address target,
        bytes32 slot,
        bytes32 value
    ) external;

    function expectRevert(
        bytes4 revertData
    ) external;
}

interface IERC20P19 {
    function balanceOf(
        address account
    ) external view returns (uint256);

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
}

interface IEthenaMintingP19 {
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

    function verifyNonce(
        address sender,
        uint256 nonce
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function mint(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    )
        external;
}


contract P19Valid1271Wallet {

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
        approvedDigest = digest;
    }

    function execute(
        address target,
        bytes calldata data
    )
        external
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) =
            target.call(data);

        require(
            ok,
            "wallet execute failed"
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
        return
            hash == approvedDigest
                ? MAGICVALUE
                : FAILVALUE;
    }
}


contract MintingV2P19NonceReplayTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

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

    IEthenaMintingP19 constant target =
        IEthenaMintingP19(MINTING);

    IERC20P19 constant usdc =
        IERC20P19(USDC);


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
        return keccak256(
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


    function _fundAndApprove(
        P19Valid1271Wallet wallet,
        uint256 amount
    )
        internal
    {
        bytes32 slot =
            keccak256(
                abi.encode(
                    address(wallet),
                    uint256(9)
                )
            );

        vm.store(
            USDC,
            slot,
            bytes32(amount)
        );

        assertEq(
            usdc.balanceOf(
                address(wallet)
            ),
            amount,
            "wallet funding failed"
        );

        wallet.execute(
            USDC,
            abi.encodeWithSelector(
                IERC20P19.approve.selector,
                MINTING,
                type(uint256).max
            )
        );
    }


    function _order(
        address wallet,
        uint128 nonce,
        string memory orderId,
        uint128 collateral,
        uint128 usdeAmount
    )
        internal
        view
        returns (
            IEthenaMintingP19.Order memory o
        )
    {
        o =
            IEthenaMintingP19.Order({
                order_id: orderId,

                order_type:
                    IEthenaMintingP19.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp + 1 days
                    ),

                nonce: nonce,

                benefactor: wallet,

                beneficiary: wallet,

                collateral_asset: USDC,

                collateral_amount:
                    collateral,

                usde_amount:
                    usdeAmount
            });
    }


    function _route()
        internal
        pure
        returns (
            IEthenaMintingP19.Route memory r
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
            IEthenaMintingP19.Route({
                addresses: addresses,
                ratios: ratios
            });
    }


    function _sig()
        internal
        pure
        returns (
            IEthenaMintingP19.Signature memory s
        )
    {
        s =
            IEthenaMintingP19.Signature({
                signature_type:
                    IEthenaMintingP19.SignatureType.EIP1271,

                signature_bytes:
                    hex"5031392d5245504c4159"
            });
    }


    function _nonceAvailable(
        address sender,
        uint256 nonce
    )
        internal
        view
        returns (bool)
    {
        (
            bool ok,
        ) =
            MINTING.staticcall(
                abi.encodeWithSelector(
                    target.verifyNonce.selector,
                    sender,
                    nonce
                )
            );

        return ok;
    }


    /*
     * ============================================================
     * TEST 1
     * ============================================================
     *
     * Valid ERC-1271 mint succeeds.
     *
     * The same nonce is then reused with:
     *
     * - different order_id
     * - new valid ERC-1271 digest
     *
     * Direct mint() must revert with InvalidNonce().
     */
    function test_P19_same_nonce_cannot_execute_twice()
        external
    {
        P19Valid1271Wallet wallet =
            new P19Valid1271Wallet();

        _authorize(
            address(wallet)
        );


        uint128 nonce =
            19001001;

        uint256 firstCollateral =
            999_900_001;

        uint256 secondCollateral =
            999_900_001;


        _fundAndApprove(
            wallet,
            firstCollateral +
            secondCollateral
        );


        IEthenaMintingP19.Order memory first =
            _order(
                address(wallet),
                nonce,
                "P19-FIRST",
                uint128(
                    firstCollateral
                ),
                uint128(
                    1_000e18
                )
            );


        IEthenaMintingP19.Route memory route =
            _route();

        IEthenaMintingP19.Signature memory sig =
            _sig();


        /*
         * Confirm the local MINTER authorization exists.
         */
        assertTrue(
            target.hasRole(
                _minterRole(),
                MINTER
            ),
            "MINTER_ROLE missing"
        );


        /*
         * Approve exact digest for first order.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                first
            )
        );


        /*
         * Baseline authorization.
         */
        target.verifyOrder(
            first,
            sig
        );


        /*
         * FIRST legitimate mint.
         */
        vm.startPrank(
            MINTER
        );

        target.mint(
            first,
            route,
            sig
        );

        vm.stopPrank();


        /*
         * Nonce must now be consumed.
         */
        assertTrue(
            !_nonceAvailable(
                address(wallet),
                nonce
            ),
            "nonce was not consumed after first mint"
        );


        uint256 remainingAfterFirst =
            usdc.balanceOf(
                address(wallet)
            );


        assertEq(
            remainingAfterFirst,
            secondCollateral,
            "unexpected collateral after first mint"
        );


        /*
         * SECOND order:
         *
         * Same nonce.
         * Different order ID.
         * New EIP-1271 digest.
         */
        IEthenaMintingP19.Order memory second =
            _order(
                address(wallet),
                nonce,
                "P19-SECOND-SAME-NONCE",
                uint128(
                    secondCollateral
                ),
                uint128(
                    1_000e18
                )
            );


        /*
         * New valid ERC-1271 authorization.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                second
            )
        );


        /*
         * IMPORTANT:
         *
         * We intentionally do NOT call verifyOrder(second).
         *
         * That helper is expected to reject a consumed nonce.
         *
         * The security property we want is:
         * direct mint() cannot execute a consumed nonce.
         */


        vm.expectRevert(
            bytes4(
                keccak256(
                    "InvalidNonce()"
                )
            )
        );


        vm.startPrank(
            MINTER
        );

        target.mint(
            second,
            route,
            sig
        );

        vm.stopPrank();


        /*
         * No second collateral transfer.
         */
        assertEq(
            usdc.balanceOf(
                address(wallet)
            ),
            remainingAfterFirst,
            "replay changed collateral balance"
        );
    }


    /*
     * ============================================================
     * TEST 2
     * ============================================================
     *
     * Same nonce + NEW valid ERC-1271 digest.
     *
     * Also changes usde_amount.
     *
     * This confirms that changing the signed order does not
     * bypass nonce consumption.
     */
    function test_P19_same_nonce_with_new_valid_1271_digest_is_rejected()
        external
    {
        P19Valid1271Wallet wallet =
            new P19Valid1271Wallet();

        _authorize(
            address(wallet)
        );


        uint128 nonce =
            19001002;

        uint256 collateral =
            999_900_001;


        _fundAndApprove(
            wallet,
            collateral * 2
        );


        /*
         * FIRST order.
         */
        IEthenaMintingP19.Order memory first =
            _order(
                address(wallet),
                nonce,
                "P19-A",
                uint128(
                    collateral
                ),
                uint128(
                    1_000e18
                )
            );


        /*
         * SECOND order:
         * same nonce,
         * different order ID,
         * different USDe amount.
         */
        IEthenaMintingP19.Order memory second =
            _order(
                address(wallet),
                nonce,
                "P19-B",
                uint128(
                    collateral
                ),
                uint128(
                    999e18
                )
            );


        IEthenaMintingP19.Route memory route =
            _route();

        IEthenaMintingP19.Signature memory sig =
            _sig();


        /*
         * Approve first digest.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                first
            )
        );


        /*
         * Baseline verification.
         */
        target.verifyOrder(
            first,
            sig
        );


        /*
         * FIRST legitimate mint.
         */
        vm.startPrank(
            MINTER
        );

        target.mint(
            first,
            route,
            sig
        );

        vm.stopPrank();


        uint256 remaining =
            usdc.balanceOf(
                address(wallet)
            );


        assertEq(
            remaining,
            collateral,
            "baseline mint balance mismatch"
        );


        /*
         * Approve a completely NEW valid digest
         * for the second order.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                second
            )
        );


        /*
         * Confirm nonce remains consumed.
         */
        assertTrue(
            !_nonceAvailable(
                address(wallet),
                nonce
            ),
            "consumed nonce became available again"
        );


        /*
         * Direct replay attempt.
         *
         * Expected:
         * InvalidNonce()
         */
        vm.expectRevert(
            bytes4(
                keccak256(
                    "InvalidNonce()"
                )
            )
        );


        vm.startPrank(
            MINTER
        );

        target.mint(
            second,
            route,
            sig
        );

        vm.stopPrank();


        /*
         * No second collateral transfer.
         */
        assertEq(
            usdc.balanceOf(
                address(wallet)
            ),
            remaining,
            "same-nonce second order changed collateral"
        );
    }
}
