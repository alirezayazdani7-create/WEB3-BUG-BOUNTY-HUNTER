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


/*
 * Minimal ERC-1271 wallet used only inside the
 * local Anvil fork.
 *
 * It accepts exactly one approved EIP-712 digest.
 */
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
        return
            keccak256(
                "MINTER_ROLE"
            );
    }


    /*
     * Add the test ERC-1271 wallet to the
     * Ethena benefactor whitelist.
     */
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


    /*
     * Fund the local ERC-1271 wallet by directly
     * writing its USDC balance in the local fork.
     *
     * This never touches Mainnet.
     */
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


    /*
     * Construct a MINT order.
     */
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

                benefactor:
                    wallet,

                beneficiary:
                    wallet,

                collateral_asset:
                    USDC,

                collateral_amount:
                    collateral,

                usde_amount:
                    usdeAmount
            });
    }


    /*
     * Valid local route:
     * 100% to the known Ethena custodian.
     */
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
                addresses:
                    addresses,

                ratios:
                    ratios
            });
    }


    /*
     * Dummy ERC-1271 signature bytes.
     *
     * The local wallet validates by digest, not by
     * cryptographic signature bytes.
     */
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


    /*
     * A successful staticcall means the nonce is
     * currently considered available.
     *
     * After consumption, verifyNonce reverts.
     */
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
     * P19 TEST 1
     * ============================================================
     *
     * 1. Create valid ERC-1271 wallet.
     * 2. Whitelist wallet.
     * 3. Fund wallet.
     * 4. Create valid order with nonce N.
     * 5. Approve exact order digest.
     * 6. Execute valid mint.
     * 7. Confirm nonce is consumed.
     * 8. Create DIFFERENT order with SAME nonce N.
     * 9. Approve NEW valid ERC-1271 digest.
     * 10. Call mint() directly.
     * 11. Require InvalidNonce().
     * 12. Confirm no second collateral transfer.
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
         * Approve exact digest for first order.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                first
            )
        );


        assertTrue(
            target.hasRole(
                _minterRole(),
                MINTER
            ),
            "MINTER_ROLE missing"
        );


        /*
         * Nonce must initially be available.
         */
        assertTrue(
            _nonceAvailable(
                address(wallet),
                nonce
            ),
            "fresh nonce was not available"
        );


        /*
         * Baseline verification must succeed.
         */
        target.verifyOrder(
            first,
            sig
        );


        /*
         * Execute first legitimate mint.
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
         * Successful mint must consume nonce.
         */
        assertTrue(
            !_nonceAvailable(
                address(wallet),
                nonce
            ),
            "nonce remained available after successful mint"
        );


        uint256 remainingAfterFirst =
            usdc.balanceOf(
                address(wallet)
            );


        assertEq(
            remainingAfterFirst,
            secondCollateral,
            "first mint transferred unexpected collateral"
        );


        /*
         * Create a DIFFERENT order with the
         * SAME nonce.
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
         * NEW valid ERC-1271 digest.
         *
         * This is important:
         * the replay attempt is not using
         * the original digest.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                second
            )
        );


        /*
         * DO NOT call verifyOrder(second).
         *
         * verifyOrder itself is expected to reject
         * the consumed nonce.
         *
         * We want to test the actual mint() path.
         */


        /*
         * mint() MUST revert with InvalidNonce().
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
         * If the expected revert occurred,
         * execution reaches here.
         *
         * Confirm no second collateral transfer.
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
     * P19 TEST 2
     * ============================================================
     *
     * Stronger variant:
     *
     * Same nonce
     * +
     * different order
     * +
     * different USDe amount
     * +
     * NEW valid ERC-1271 digest
     *
     * must still fail at mint().
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
         * First order.
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
         * Second order:
         * SAME nonce,
         * DIFFERENT order ID,
         * DIFFERENT USDe amount.
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
         * First valid ERC-1271 digest.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                first
            )
        );


        /*
         * Baseline order verification.
         */
        target.verifyOrder(
            first,
            sig
        );


        /*
         * First legitimate mint.
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
         * NEW order + NEW valid ERC-1271 digest,
         * but SAME already-consumed nonce.
         */
        wallet.setApprovedDigest(
            target.hashOrder(
                second
            )
        );


        /*
         * Confirm nonce is still consumed.
         */
        assertTrue(
            !_nonceAvailable(
                address(wallet),
                nonce
            ),
            "consumed nonce became available again"
        );


        /*
         * Direct mint() replay attempt.
         *
         * Expected result:
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
         * No second transfer.
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
