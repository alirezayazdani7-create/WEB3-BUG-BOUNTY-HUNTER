// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function addr(uint256 privateKey) external returns (address);

    function prank(address msgSender) external;

    function startPrank(address msgSender) external;

    function stopPrank() external;

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

    function store(
        address target,
        bytes32 slot,
        bytes32 value
    )
        external;
}

interface IERC20P26 {
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

    function transfer(
        address to,
        uint256 amount
    )
        external
        returns (bool);
}

interface IEthenaP26 {

    enum OrderType {
        MINT,
        REDEEM
    }

    enum SignatureType {
        EIP712,
        EIP1271
    }

    enum DelegatedSignerStatus {
        REJECTED,
        PENDING,
        ACCEPTED
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

    struct Signature {
        SignatureType signature_type;
        bytes signature_bytes;
    }

    function owner()
        external
        view
        returns (address);

    function addWhitelistedBenefactor(
        address benefactor
    )
        external;

    function grantRole(
        bytes32 role,
        address account
    )
        external;

    function setDelegatedSigner(
        address delegateTo
    )
        external;

    function confirmDelegatedSigner(
        address delegatedBy
    )
        external;

    function removeDelegatedSigner(
        address removedSigner
    )
        external;

    function delegatedSigner(
        address signer,
        address delegator
    )
        external
        view
        returns (DelegatedSignerStatus);

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

    function redeem(
        Order calldata order,
        Signature calldata signature
    )
        external;
}


contract MintingV2P26DelegatedRedeemLifecycleTest {

    /*
     * Ethena Minting V2
     */
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    /*
     * USDe
     */
    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    /*
     * USDC
     */
    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /*
     * USDe-rich holder.
     *
     * IMPORTANT:
     * Written as uint160 conversion to avoid
     * Solidity checksum-literal compilation errors.
     */
    address constant HOLDER =
        address(
            uint160(
                0xA469b399df1c7b4bd8569048d889f131329dffa1
            )
        );

    /*
     * Foundry VM cheat-code address.
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

    IEthenaP26 constant target =
        IEthenaP26(MINTING);

    IERC20P26 constant usde =
        IERC20P26(USDE);

    IERC20P26 constant usdc =
        IERC20P26(USDC);


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


    /*
     * REDEEMER_ROLE
     */
    function _redeemerRole()
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            "REDEEMER_ROLE"
        );
    }


    /*
     * Transfer USDe from the known rich holder
     * to our local fork benefactor.
     */
    function _fundBenefactor(
        address benefactor,
        uint256 amount
    )
        internal
    {
        vm.startPrank(
            HOLDER
        );

        require(
            usde.transfer(
                benefactor,
                amount
            ),
            "USDe transfer failed"
        );

        vm.stopPrank();


        vm.startPrank(
            benefactor
        );

        require(
            usde.approve(
                MINTING,
                type(uint256).max
            ),
            "USDe approve failed"
        );

        vm.stopPrank();
    }


    /*
     * Fund Minting V2 with USDC on the
     * isolated Anvil fork.
     *
     * This is ONLY local fork state manipulation.
     */
    function _fundMintingUSDC(
        uint256 amount
    )
        internal
    {
        bytes32 balanceSlot =
            keccak256(
                abi.encode(
                    MINTING,
                    uint256(9)
                )
            );

        vm.store(
            USDC,
            balanceSlot,
            bytes32(amount)
        );

        assertEq(
            usdc.balanceOf(
                MINTING
            ),
            amount,
            "Minting USDC funding failed"
        );
    }


    /*
     * Build a valid REDEEM order.
     */
    function _order(
        address benefactor,
        uint128 nonce
    )
        internal
        view
        returns (
            IEthenaP26.Order memory order
        )
    {
        order =
            IEthenaP26.Order({
                order_id:
                    "P26-DELEGATED-REDEEM",

                order_type:
                    IEthenaP26.OrderType.REDEEM,

                expiry:
                    uint120(
                        block.timestamp + 1 days
                    ),

                nonce:
                    nonce,

                benefactor:
                    benefactor,

                beneficiary:
                    benefactor,

                collateral_asset:
                    USDC,

                collateral_amount:
                    999900001,

                usde_amount:
                    1e18
            });
    }


    /*
     * Create EIP-712 signature using
     * the delegated signer's private key.
     */
    function _signature(
        uint256 delegatePrivateKey,
        bytes32 digest
    )
        internal
        returns (
            IEthenaP26.Signature memory signature
        )
    {
        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                delegatePrivateKey,
                digest
            );

        signature =
            IEthenaP26.Signature({
                signature_type:
                    IEthenaP26.SignatureType.EIP712,

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
     * P26
     * Delegated Signer -> Full Redeem -> Removal
     * ============================================================
     *
     * Expected lifecycle:
     *
     * 1. Benefactor sets delegate.
     * 2. Delegate confirms.
     * 3. Delegate signs REDEEM order.
     * 4. Full redeem succeeds.
     * 5. Benefactor removes delegate.
     * 6. Removed delegate can no longer authorize.
     */
    function test_P26_delegate_can_redeem_then_removal_invalidates_old_authority()
        external
    {
        /*
         * Anvil private key #1.
         */
        address benefactor =
            vm.addr(1);

        /*
         * Anvil private key #2.
         */
        address delegate =
            vm.addr(2);

        uint256 usdeAmount =
            1e18;

        uint256 collateralAmount =
            999900001;


        /*
         * --------------------------------------------------------
         * SETUP
         * --------------------------------------------------------
         */

        /*
         * Whitelist benefactor.
         */
        vm.prank(
            target.owner()
        );

        target.addWhitelistedBenefactor(
            benefactor
        );


        /*
         * Give benefactor REDEEMER_ROLE
         * for the isolated local-fork test.
         */
        vm.prank(
            target.owner()
        );

        target.grantRole(
            _redeemerRole(),
            benefactor
        );


        /*
         * Fund benefactor with USDe.
         */
        _fundBenefactor(
            benefactor,
            usdeAmount
        );


        /*
         * Fund Minting V2 with USDC.
         */
        _fundMintingUSDC(
            collateralAmount
        );


        /*
         * --------------------------------------------------------
         * STEP 1
         * Benefactor initiates delegation.
         * --------------------------------------------------------
         */

        vm.prank(
            benefactor
        );

        target.setDelegatedSigner(
            delegate
        );


        assertTrue(
            uint8(
                target.delegatedSigner(
                    delegate,
                    benefactor
                )
            )
            ==
            uint8(
                IEthenaP26
                    .DelegatedSignerStatus
                    .PENDING
            ),
            "delegation did not enter PENDING"
        );


        /*
         * --------------------------------------------------------
         * STEP 2
         * Delegate confirms delegation.
         * --------------------------------------------------------
         */

        vm.prank(
            delegate
        );

        target.confirmDelegatedSigner(
            benefactor
        );


        assertTrue(
            uint8(
                target.delegatedSigner(
                    delegate,
                    benefactor
                )
            )
            ==
            uint8(
                IEthenaP26
                    .DelegatedSignerStatus
                    .ACCEPTED
            ),
            "delegation did not enter ACCEPTED"
        );


        /*
         * --------------------------------------------------------
         * STEP 3
         * Delegate signs REDEEM order.
         * --------------------------------------------------------
         */

        IEthenaP26.Order memory order =
            _order(
                benefactor,
                26001001
            );


        IEthenaP26.Signature memory signature =
            _signature(
                2,
                target.hashOrder(
                    order
                )
            );


        /*
         * Authorization must succeed.
         */
        target.verifyOrder(
            order,
            signature
        );


        uint256 usdeBefore =
            usde.balanceOf(
                benefactor
            );

        uint256 usdcBefore =
            usdc.balanceOf(
                benefactor
            );


        /*
         * --------------------------------------------------------
         * STEP 4
         * Execute FULL redeem path.
         * --------------------------------------------------------
         */

        vm.prank(
            benefactor
        );

        target.redeem(
            order,
            signature
        );


        /*
         * Verify USDe was burned.
         */
        assertEq(
            usde.balanceOf(
                benefactor
            ),
            usdeBefore - usdeAmount,
            "USDe was not burned"
        );


        /*
         * Verify USDC collateral was received.
         */
        assertEq(
            usdc.balanceOf(
                benefactor
            ),
            usdcBefore + collateralAmount,
            "collateral was not redeemed"
        );


        /*
         * --------------------------------------------------------
         * STEP 5
         * Benefactor removes delegate.
         * --------------------------------------------------------
         */

        vm.prank(
            benefactor
        );

        target.removeDelegatedSigner(
            delegate
        );


        assertTrue(
            uint8(
                target.delegatedSigner(
                    delegate,
                    benefactor
                )
            )
            ==
            uint8(
                IEthenaP26
                    .DelegatedSignerStatus
                    .REJECTED
            ),
            "delegation was not rejected"
        );


        /*
         * --------------------------------------------------------
         * STEP 6
         * Removed delegate must no longer authorize.
         * --------------------------------------------------------
         *
         * We use a NEW nonce and NEW signature.
         * This isolates delegation removal from nonce replay.
         */

        IEthenaP26.Order memory staleOrder =
            _order(
                benefactor,
                26001002
            );


        IEthenaP26.Signature memory staleSignature =
            _signature(
                2,
                target.hashOrder(
                    staleOrder
                )
            );


        (
            bool authorized,
        ) =
            MINTING.staticcall(
                abi.encodeWithSelector(
                    target.verifyOrder.selector,
                    staleOrder,
                    staleSignature
                )
            );


        assertTrue(
            !authorized,
            "removed delegate still authorized a new order"
        );
    }


    /*
     * ============================================================
     * P26 SECOND TEST
     *
     * Delegated signer must remain scoped to the benefactor
     * that accepted the delegation.
     * ============================================================
     */
    function test_P26_delegate_is_scoped_to_one_benefactor()
        external
    {
        address benefactorA =
            vm.addr(3);

        address benefactorB =
            vm.addr(4);

        address delegate =
            vm.addr(5);


        /*
         * Whitelist benefactor A.
         */
        vm.prank(
            target.owner()
        );

        target.addWhitelistedBenefactor(
            benefactorA
        );


        /*
         * Whitelist benefactor B.
         */
        vm.prank(
            target.owner()
        );

        target.addWhitelistedBenefactor(
            benefactorB
        );


        /*
         * Delegate is authorized ONLY by A.
         */
        vm.prank(
            benefactorA
        );

        target.setDelegatedSigner(
            delegate
        );


        /*
         * Delegate confirms only for A.
         */
        vm.prank(
            delegate
        );

        target.confirmDelegatedSigner(
            benefactorA
        );


        /*
         * Construct an order belonging to B.
         */
        IEthenaP26.Order memory orderB =
            _order(
                benefactorB,
                26001003
            );


        /*
         * Same delegate signs B's order.
         */
        IEthenaP26.Signature memory signatureB =
            _signature(
                5,
                target.hashOrder(
                    orderB
                )
            );


        /*
         * Authorization must fail because
         * delegate is not authorized by B.
         */
        (
            bool authorized,
        ) =
            MINTING.staticcall(
                abi.encodeWithSelector(
                    target.verifyOrder.selector,
                    orderB,
                    signatureB
                )
            );


        assertTrue(
            !authorized,
            "delegate crossed benefactor boundary"
        );
    }
}
