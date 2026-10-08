// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function prank(address msgSender) external;
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);
    function store(
        address target,
        bytes32 slot,
        bytes32 value
    ) external;
}

interface IERC20P27 {
    function balanceOf(address account)
        external
        view
        returns (uint256);
}

interface IUSDeP27 {
    function balanceOf(address account)
        external
        view
        returns (uint256);

    function approve(
        address spender,
        uint256 amount
    )
        external
        returns (bool);

    function mint(
        address to,
        uint256 amount
    )
        external;

    function minter()
        external
        view
        returns (address);
}

interface IEthenaP27 {

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

    function redeem(
        Order calldata order,
        Signature calldata signature
    )
        external;
}


contract MintingV2P27DelegatedReaddResurrectionTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

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


    IEthenaP27 constant target =
        IEthenaP27(
            MINTING
        );


    IUSDeP27 constant usde =
        IUSDeP27(
            USDE
        );


    IERC20P27 constant usdc =
        IERC20P27(
            USDC
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


    function _redeemerRole()
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            "REDEEMER_ROLE"
        );
    }


    function _fundBenefactor(
        address benefactor,
        uint256 amount
    )
        internal
    {
        address usdeMinter =
            usde.minter();

        vm.prank(
            usdeMinter
        );

        usde.mint(
            benefactor,
            amount
        );

        assertEq(
            usde.balanceOf(
                benefactor
            ),
            amount,
            "USDe local mint failed"
        );


        vm.prank(
            benefactor
        );

        require(
            usde.approve(
                MINTING,
                type(uint256).max
            ),
            "USDe approve failed"
        );
    }


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
            "USDC funding failed"
        );
    }


    function _order(
        address benefactor,
        uint128 nonce
    )
        internal
        view
        returns (
            IEthenaP27.Order memory order
        )
    {
        order =
            IEthenaP27.Order({
                order_id:
                    "P27-STALE-DELEGATE",

                order_type:
                    IEthenaP27.OrderType.REDEEM,

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
                    999900,

                usde_amount:
                    1e18
            });
    }


    function _signature(
        uint256 delegatePrivateKey,
        bytes32 digest
    )
        internal
        returns (
            IEthenaP27.Signature memory signature
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
            IEthenaP27.Signature({
                signature_type:
                    IEthenaP27.SignatureType.EIP712,

                signature_bytes:
                    abi.encodePacked(
                        r,
                        s,
                        v
                    )
            });
    }


    function _assertVerifyFails(
        IEthenaP27.Order memory order,
        IEthenaP27.Signature memory signature,
        string memory reason
    )
        internal
        view
    {
        (
            bool ok,
        ) =
            MINTING.staticcall(
                abi.encodeWithSelector(
                    target.verifyOrder.selector,
                    order,
                    signature
                )
            );

        assertTrue(
            !ok,
            reason
        );
    }


    /*
     * P27 CORE HYPOTHESIS
     *
     * Delegate signs an UNUSED order.
     *
     * Benefactor removes the delegate.
     *
     * The old signature must become invalid.
     *
     * Benefactor re-adds and reconfirms the SAME delegate.
     *
     * No new signature is created.
     *
     * We test whether the EXACT OLD SIGNATURE
     * becomes valid again.
     */
    function test_P27_removed_delegate_old_unused_signature_resurrects_after_readd()
        external
    {
        address benefactor =
            vm.addr(1);

        address delegate =
            vm.addr(2);


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
         * on the isolated fork.
         */
        vm.prank(
            target.owner()
        );

        target.grantRole(
            _redeemerRole(),
            benefactor
        );


        /*
         * Give benefactor 1 USDe.
         */
        _fundBenefactor(
            benefactor,
            1e18
        );


        /*
         * Give Minting V2 enough USDC
         * to complete the redeem.
         */
        _fundMintingUSDC(
            999900
        );


        /*
         * STEP 1
         *
         * Benefactor -> Delegate
         */
        vm.prank(
            benefactor
        );

        target.setDelegatedSigner(
            delegate
        );


        /*
         * STEP 2
         *
         * Delegate confirms.
         */
        vm.prank(
            delegate
        );

        target.confirmDelegatedSigner(
            benefactor
        );


        /*
         * STEP 3
         *
         * Delegate signs an UNUSED order.
         */
        IEthenaP27.Order memory oldOrder =
            _order(
                benefactor,
                27001001
            );


        IEthenaP27.Signature memory oldSignature =
            _signature(
                2,
                target.hashOrder(
                    oldOrder
                )
            );


        /*
         * Confirm the original signature
         * is valid before removal.
         */
        target.verifyOrder(
            oldOrder,
            oldSignature
        );


        /*
         * STEP 4
         *
         * Remove delegate.
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
                IEthenaP27
                    .DelegatedSignerStatus
                    .REJECTED
            ),
            "delegate removal failed"
        );


        /*
         * The OLD signature must now fail.
         */
        _assertVerifyFails(
            oldOrder,
            oldSignature,
            "old signature remained valid after removal"
        );


        /*
         * STEP 5
         *
         * Re-add SAME delegate.
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
                IEthenaP27
                    .DelegatedSignerStatus
                    .PENDING
            ),
            "re-add did not enter PENDING"
        );


        /*
         * STEP 6
         *
         * Delegate reconfirms.
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
                IEthenaP27
                    .DelegatedSignerStatus
                    .ACCEPTED
            ),
            "re-add confirmation failed"
        );


        /*
         * CRITICAL STEP
         *
         * NO new signature is generated.
         *
         * We reuse EXACTLY the old signature.
         */
        target.verifyOrder(
            oldOrder,
            oldSignature
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
         * Full redeem using the OLD signature.
         */
        vm.prank(
            benefactor
        );

        target.redeem(
            oldOrder,
            oldSignature
        );


        /*
         * If we reach here, the old authorization
         * was resurrected after re-add.
         */
        assertEq(
            usde.balanceOf(
                benefactor
            ),
            usdeBefore - 1e18,
            "old signature did not execute"
        );

        assertEq(
            usdc.balanceOf(
                benefactor
            ),
            usdcBefore + 999900,
            "collateral did not transfer"
        );
    }


    /*
     * CONTROL TEST
     *
     * Remove delegate.
     *
     * Re-add delegate BUT DO NOT CONFIRM.
     *
     * The old signature must remain invalid.
     */
    function test_P27_readd_without_reconfirm_does_not_resurrect_signature()
        external
    {
        address benefactor =
            vm.addr(3);

        address delegate =
            vm.addr(4);


        vm.prank(
            target.owner()
        );

        target.addWhitelistedBenefactor(
            benefactor
        );


        vm.prank(
            benefactor
        );

        target.setDelegatedSigner(
            delegate
        );


        vm.prank(
            delegate
        );

        target.confirmDelegatedSigner(
            benefactor
        );


        IEthenaP27.Order memory oldOrder =
            _order(
                benefactor,
                27001002
            );


        IEthenaP27.Signature memory oldSignature =
            _signature(
                4,
                target.hashOrder(
                    oldOrder
                )
            );


        vm.prank(
            benefactor
        );

        target.removeDelegatedSigner(
            delegate
        );


        _assertVerifyFails(
            oldOrder,
            oldSignature,
            "signature valid after removal"
        );


        /*
         * Re-add, but leave PENDING.
         */
        vm.prank(
            benefactor
        );

        target.setDelegatedSigner(
            delegate
        );


        /*
         * It must still fail until delegate confirms.
         */
        _assertVerifyFails(
            oldOrder,
            oldSignature,
            "PENDING re-add restored old signature"
        );
    }
}
