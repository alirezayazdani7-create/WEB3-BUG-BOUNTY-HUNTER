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

interface IERC20 {
    function balanceOf(address account)
        external
        view
        returns (uint256);

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
}

interface IUSDe {
    function balanceOf(address account)
        external
        view
        returns (uint256);

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);

    function mint(
        address to,
        uint256 amount
    ) external;

    function minter()
        external
        view
        returns (address);
}

interface IEthenaMinting {
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
    ) external;

    function removeWhitelistedBenefactor(
        address benefactor
    ) external;

    function grantRole(
        bytes32 role,
        address account
    ) external;

    function setDelegatedSigner(
        address delegateTo
    ) external;

    function confirmDelegatedSigner(
        address delegatedBy
    ) external;

    function removeDelegatedSigner(
        address removedSigner
    ) external;

    function setApprovedBeneficiary(
        address beneficiary,
        bool status
    ) external;

    function delegatedSigner(
        address signer,
        address benefactor
    )
        external
        view
        returns (DelegatedSignerStatus);

    function isApprovedBeneficiary(
        address benefactor,
        address beneficiary
    )
        external
        view
        returns (bool);

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
    ) external;
}

contract MintingV2P28BenefactorReaddAuthorizationTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    Vm constant vm =
        Vm(address(uint160(uint256(
            keccak256("hevm cheat code")
        ))));

    IEthenaMinting constant target =
        IEthenaMinting(MINTING);

    IUSDe constant usde =
        IUSDe(USDE);

    IERC20 constant usdc =
        IERC20(USDC);

    function assertTrue(
        bool value,
        string memory reason
    ) internal pure {
        require(value, reason);
    }

    function assertEq(
        uint256 a,
        uint256 b,
        string memory reason
    ) internal pure {
        require(a == b, reason);
    }

    function _redeemerRole()
        internal
        pure
        returns (bytes32)
    {
        return keccak256("REDEEMER_ROLE");
    }

    function _fundBenefactor(
        address benefactor,
        uint256 amount
    ) internal {

        vm.prank(usde.minter());

        usde.mint(
            benefactor,
            amount
        );

        assertEq(
            usde.balanceOf(benefactor),
            amount,
            "USDe local mint failed"
        );

        vm.prank(benefactor);

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
    ) internal {

        bytes32 slot =
            keccak256(
                abi.encode(
                    MINTING,
                    uint256(9)
                )
            );

        vm.store(
            USDC,
            slot,
            bytes32(amount)
        );

        assertEq(
            usdc.balanceOf(MINTING),
            amount,
            "USDC funding failed"
        );
    }

    function _order(
        address benefactor,
        address beneficiary,
        uint128 nonce
    )
        internal
        view
        returns (
            IEthenaMinting.Order memory order
        )
    {
        order =
            IEthenaMinting.Order({
                order_id:
                    "P28-BENEFACTOR-READD",

                order_type:
                    IEthenaMinting.OrderType.REDEEM,

                expiry:
                    uint120(
                        block.timestamp + 1 days
                    ),

                nonce:
                    nonce,

                benefactor:
                    benefactor,

                beneficiary:
                    beneficiary,

                collateral_asset:
                    USDC,

                collateral_amount:
                    999900,

                usde_amount:
                    1e18
            });
    }

    function _sig(
        uint256 privateKey,
        bytes32 digest
    )
        internal
        returns (
            IEthenaMinting.Signature memory signature
        )
    {
        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = vm.sign(
            privateKey,
            digest
        );

        signature =
            IEthenaMinting.Signature({
                signature_type:
                    IEthenaMinting.SignatureType.EIP712,

                signature_bytes:
                    abi.encodePacked(
                        r,
                        s,
                        v
                    )
            });
    }

    function _mustFail(
        IEthenaMinting.Order memory order,
        IEthenaMinting.Signature memory signature
    ) internal view {

        (
            bool success,
        ) = MINTING.staticcall(
            abi.encodeWithSelector(
                target.verifyOrder.selector,
                order,
                signature
            )
        );

        assertTrue(
            !success,
            "authorization unexpectedly remained valid"
        );
    }

    function
        test_P28_remove_readd_revives_old_delegate_and_beneficiary_authorization()
        external
    {
        address benefactor =
            vm.addr(10);

        address delegate =
            vm.addr(11);

        address beneficiary =
            vm.addr(12);

        // -------------------------------------------------
        // 1. Initial authorization
        // -------------------------------------------------

        vm.prank(target.owner());

        target.addWhitelistedBenefactor(
            benefactor
        );

        vm.prank(target.owner());

        target.grantRole(
            _redeemerRole(),
            benefactor
        );

        _fundBenefactor(
            benefactor,
            1e18
        );

        _fundMintingUSDC(
            999900
        );

        // -------------------------------------------------
        // 2. Create delegated signer
        // -------------------------------------------------

        vm.prank(benefactor);

        target.setDelegatedSigner(
            delegate
        );

        vm.prank(delegate);

        target.confirmDelegatedSigner(
            benefactor
        );

        // -------------------------------------------------
        // 3. Approve beneficiary
        // -------------------------------------------------

        vm.prank(benefactor);

        target.setApprovedBeneficiary(
            beneficiary,
            true
        );

        // -------------------------------------------------
        // 4. Create OLD authorization
        // -------------------------------------------------

        IEthenaMinting.Order memory oldOrder =
            _order(
                benefactor,
                beneficiary,
                28001001
            );

        IEthenaMinting.Signature memory oldSignature =
            _sig(
                11,
                target.hashOrder(oldOrder)
            );

        // Must work before removal.
        target.verifyOrder(
            oldOrder,
            oldSignature
        );

        // -------------------------------------------------
        // 5. Remove benefactor
        // -------------------------------------------------

        vm.prank(target.owner());

        target.removeWhitelistedBenefactor(
            benefactor
        );

        // Authorization must be blocked
        // while benefactor is removed.
        _mustFail(
            oldOrder,
            oldSignature
        );

        // -------------------------------------------------
        // 6. Re-add SAME benefactor
        // -------------------------------------------------

        vm.prank(target.owner());

        target.addWhitelistedBenefactor(
            benefactor
        );

        // -------------------------------------------------
        // 7. Check whether OLD permissions survived
        // -------------------------------------------------

        assertTrue(
            uint8(
                target.delegatedSigner(
                    delegate,
                    benefactor
                )
            ) ==
            uint8(
                IEthenaMinting
                    .DelegatedSignerStatus
                    .ACCEPTED
            ),
            "delegate state was cleared"
        );

        assertTrue(
            target.isApprovedBeneficiary(
                benefactor,
                beneficiary
            ),
            "beneficiary state was cleared"
        );

        // -------------------------------------------------
        // 8. CRITICAL TEST:
        // OLD signature from BEFORE removal
        // becomes valid again after re-add.
        // -------------------------------------------------

        target.verifyOrder(
            oldOrder,
            oldSignature
        );

        // -------------------------------------------------
        // 9. Execute locally
        // -------------------------------------------------

        uint256 usdeBefore =
            usde.balanceOf(
                benefactor
            );

        uint256 usdcBefore =
            usdc.balanceOf(
                beneficiary
            );

        vm.prank(benefactor);

        target.redeem(
            oldOrder,
            oldSignature
        );

        // -------------------------------------------------
        // 10. Accounting assertions
        // -------------------------------------------------

        assertEq(
            usde.balanceOf(
                benefactor
            ),
            usdeBefore - 1e18,
            "old authorization did not execute"
        );

        assertEq(
            usdc.balanceOf(
                beneficiary
            ),
            usdcBefore + 999900,
            "collateral did not reach old beneficiary"
        );
    }

    function
        test_P28_delegate_removal_still_invalidates_authorization()
        external
    {
        address benefactor =
            vm.addr(20);

        address delegate =
            vm.addr(21);

        // -------------------------------------------------
        // Initial whitelist
        // -------------------------------------------------

        vm.prank(target.owner());

        target.addWhitelistedBenefactor(
            benefactor
        );

        // -------------------------------------------------
        // Add delegated signer
        // -------------------------------------------------

        vm.prank(benefactor);

        target.setDelegatedSigner(
            delegate
        );

        vm.prank(delegate);

        target.confirmDelegatedSigner(
            benefactor
        );

        // -------------------------------------------------
        // Create authorization
        // -------------------------------------------------

        IEthenaMinting.Order memory order =
            _order(
                benefactor,
                benefactor,
                28001002
            );

        IEthenaMinting.Signature memory signature =
            _sig(
                21,
                target.hashOrder(order)
            );

        // Must initially work.
        target.verifyOrder(
            order,
            signature
        );

        // -------------------------------------------------
        // Remove delegated signer
        // -------------------------------------------------

        vm.prank(benefactor);

        target.removeDelegatedSigner(
            delegate
        );

        // -------------------------------------------------
        // Control:
        // removing delegate normally invalidates it.
        // -------------------------------------------------

        _mustFail(
            order,
            signature
        );
    }
}
