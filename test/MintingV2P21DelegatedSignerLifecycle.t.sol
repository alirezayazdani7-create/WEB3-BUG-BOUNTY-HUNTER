// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface VmP21 {
    function prank(address msgSender) external;

    function startPrank(address msgSender) external;

    function stopPrank() external;

    function addr(uint256 privateKey) external returns (address);

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

    function expectRevert(
        bytes4 revertData
    )
        external;
}


interface IEthenaMintingP21 {

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
        address delegateSigner,
        address delegator
    )
        external
        view
        returns (
            DelegatedSignerStatus
        );

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
}


contract P21DelegatingBenefactor {

    address public target;

    constructor(
        address target_
    ) {
        target = target_;
    }

    function setDelegate(
        address delegate
    )
        external
    {
        IEthenaMintingP21(target)
            .setDelegatedSigner(
                delegate
            );
    }

    function removeDelegate(
        address delegate
    )
        external
    {
        IEthenaMintingP21(target)
            .removeDelegatedSigner(
                delegate
            );
    }
}


contract MintingV2P21DelegatedSignerLifecycleTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 constant DELEGATE_PRIVATE_KEY = 1;

    uint256 constant ATTACKER_PRIVATE_KEY = 2;


    VmP21 constant vm =
        VmP21(
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


    IEthenaMintingP21 constant target =
        IEthenaMintingP21(
            MINTING
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


    function _minterOwnerAuthorize(
        address benefactor
    )
        internal
    {
        vm.prank(
            target.owner()
        );

        target.addWhitelistedBenefactor(
            benefactor
        );
    }


    function _order(
        address benefactor
    )
        internal
        view
        returns (
            IEthenaMintingP21.Order memory order
        )
    {
        order =
            IEthenaMintingP21.Order({
                order_id:
                    "P21-DELEGATED-SIGNER",

                order_type:
                    IEthenaMintingP21.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp +
                        1 days
                    ),

                nonce:
                    21001001,

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


    function _delegateSignature(
        IEthenaMintingP21.Order memory order
    )
        internal
        returns (
            IEthenaMintingP21.Signature memory signature
        )
    {
        bytes32 digest =
            target.hashOrder(
                order
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                DELEGATE_PRIVATE_KEY,
                digest
            );

        signature =
            IEthenaMintingP21.Signature({
                signature_type:
                    IEthenaMintingP21.SignatureType.EIP712,

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
     * TEST 1
     * ============================================================
     *
     * Two-step delegation must work:
     *
     * Benefactor
     *      ->
     * setDelegatedSigner()
     *      ->
     * PENDING
     *      ->
     * Delegate
     *      ->
     * confirmDelegatedSigner()
     *      ->
     * ACCEPTED
     *
     * The delegated EOA must then be accepted by verifyOrder().
     */
    function test_P21_delegate_acceptance_authorizes_signature()
        external
    {
        P21DelegatingBenefactor benefactor =
            new P21DelegatingBenefactor(
                MINTING
            );

        address delegate =
            vm.addr(
                DELEGATE_PRIVATE_KEY
            );

        _minterOwnerAuthorize(
            address(benefactor)
        );


        /*
         * Benefactor initiates delegation.
         */
        benefactor.setDelegate(
            delegate
        );


        assertTrue(
            uint256(
                target.delegatedSigner(
                    delegate,
                    address(benefactor)
                )
            ) ==
            uint256(
                IEthenaMintingP21.DelegatedSignerStatus.PENDING
            ),
            "delegation did not enter PENDING"
        );


        /*
         * The delegate confirms the delegation.
         */
        vm.prank(
            delegate
        );

        target.confirmDelegatedSigner(
            address(benefactor)
        );


        assertTrue(
            uint256(
                target.delegatedSigner(
                    delegate,
                    address(benefactor)
                )
            ) ==
            uint256(
                IEthenaMintingP21.DelegatedSignerStatus.ACCEPTED
            ),
            "delegation did not enter ACCEPTED"
        );


        IEthenaMintingP21.Order memory order =
            _order(
                address(benefactor)
            );


        IEthenaMintingP21.Signature memory signature =
            _delegateSignature(
                order
            );


        /*
         * The delegated signer must now authorize
         * the order even though signer != benefactor.
         */
        target.verifyOrder(
            order,
            signature
        );
    }


    /*
     * ============================================================
     * TEST 2
     * ============================================================
     *
     * A third party must not be able to confirm a delegation
     * that was not initiated for it.
     */
    function test_P21_unauthorized_confirmation_rejected()
        external
    {
        P21DelegatingBenefactor benefactor =
            new P21DelegatingBenefactor(
                MINTING
            );

        address delegate =
            vm.addr(
                DELEGATE_PRIVATE_KEY
            );

        address attacker =
            vm.addr(
                ATTACKER_PRIVATE_KEY
            );


        _minterOwnerAuthorize(
            address(benefactor)
        );


        /*
         * Benefactor delegates only to the legitimate delegate.
         */
        benefactor.setDelegate(
            delegate
        );


        /*
         * Attacker tries to confirm as if it were the delegate.
         */
        vm.prank(
            attacker
        );

        vm.expectRevert(
            bytes4(
                keccak256(
                    "DelegationNotInitiated()"
                )
            )
        );

        target.confirmDelegatedSigner(
            address(benefactor)
        );


        /*
         * Legitimate delegate remains PENDING.
         */
        assertTrue(
            uint256(
                target.delegatedSigner(
                    delegate,
                    address(benefactor)
                )
            ) ==
            uint256(
                IEthenaMintingP21.DelegatedSignerStatus.PENDING
            ),
            "attacker changed delegation state"
        );
    }


    /*
     * ============================================================
     * TEST 3
     * ============================================================
     *
     * After removeDelegatedSigner(), an old delegated EIP712
     * signature must no longer authorize the order.
     */
    function test_P21_removed_delegate_signature_rejected()
        external
    {
        P21DelegatingBenefactor benefactor =
            new P21DelegatingBenefactor(
                MINTING
            );

        address delegate =
            vm.addr(
                DELEGATE_PRIVATE_KEY
            );


        _minterOwnerAuthorize(
            address(benefactor)
        );


        /*
         * Establish delegation.
         */
        benefactor.setDelegate(
            delegate
        );


        vm.prank(
            delegate
        );

        target.confirmDelegatedSigner(
            address(benefactor)
        );


        IEthenaMintingP21.Order memory order =
            _order(
                address(benefactor)
            );


        IEthenaMintingP21.Signature memory signature =
            _delegateSignature(
                order
            );


        /*
         * Signature is valid while delegation is ACCEPTED.
         */
        target.verifyOrder(
            order,
            signature
        );


        /*
         * Benefactor removes the delegated signer.
         */
        benefactor.removeDelegate(
            delegate
        );


        assertTrue(
            uint256(
                target.delegatedSigner(
                    delegate,
                    address(benefactor)
                )
            ) ==
            uint256(
                IEthenaMintingP21.DelegatedSignerStatus.REJECTED
            ),
            "delegation was not removed"
        );


        /*
         * The exact same signed order must now fail.
         */
        vm.expectRevert(
            bytes4(
                keccak256(
                    "InvalidEIP712Signature()"
                )
            )
        );

        target.verifyOrder(
            order,
            signature
        );
    }
}
