// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface VmP22 {
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);
    function store(address target, bytes32 slot, bytes32 value) external;
}

interface IERC20P22 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUSDeP22 {
    function balanceOf(address account) external view returns (uint256);
}

interface IEthenaMintingP22 {
    enum SignatureType { EIP712, EIP1271 }
    enum OrderType { MINT, REDEEM }
    enum DelegatedSignerStatus { REJECTED, PENDING, ACCEPTED }

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

    function owner() external view returns (address);

    function addWhitelistedBenefactor(address benefactor) external;

    function setDelegatedSigner(address delegateTo) external;

    function confirmDelegatedSigner(address delegatedBy) external;

    function removeDelegatedSigner(address removedSigner) external;

    function delegatedSigner(
        address delegateSigner,
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

    function verifyRoute(
        Route calldata route
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

contract P22DelegatedBenefactor {

    address public immutable target;

    constructor(address target_) {
        target = target_;
    }

    function setDelegate(address delegate) external {
        IEthenaMintingP22(target)
            .setDelegatedSigner(delegate);
    }

    function removeDelegate(address delegate) external {
        IEthenaMintingP22(target)
            .removeDelegatedSigner(delegate);
    }

    function approveToken(
        address token,
        address spender,
        uint256 amount
    )
        external
    {
        (bool ok,) =
            token.call(
                abi.encodeWithSelector(
                    IERC20P22.approve.selector,
                    spender,
                    amount
                )
            );

        require(
            ok,
            "approve failed"
        );
    }
}

contract MintingV2P22DelegatedSignerFullPathTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    uint256 constant DELEGATE_PRIVATE_KEY = 1;

    VmP22 constant vm =
        VmP22(
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

    IEthenaMintingP22 constant target =
        IEthenaMintingP22(
            MINTING
        );

    IERC20P22 constant usdc =
        IERC20P22(
            USDC
        );

    IUSDeP22 constant usde =
        IUSDeP22(
            USDE
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

    function _authorize(
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

    function _fundAndApprove(
        P22DelegatedBenefactor benefactor,
        uint256 amount
    )
        internal
    {
        bytes32 slot =
            keccak256(
                abi.encode(
                    address(benefactor),
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
                address(benefactor)
            ),
            amount,
            "benefactor USDC funding failed"
        );

        benefactor.approveToken(
            USDC,
            MINTING,
            type(uint256).max
        );
    }

    function _order(
        address benefactor,
        uint128 nonce,
        string memory orderId
    )
        internal
        view
        returns (
            IEthenaMintingP22.Order memory o
        )
    {
        o =
            IEthenaMintingP22.Order({

                order_id:
                    orderId,

                order_type:
                    IEthenaMintingP22.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp +
                        1 days
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
                    999_900_001,

                usde_amount:
                    1_000e18
            });
    }

    function _route()
        internal
        pure
        returns (
            IEthenaMintingP22.Route memory r
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
            IEthenaMintingP22.Route({
                addresses:
                    addresses,

                ratios:
                    ratios
            });
    }

    function _delegateSignature(
        IEthenaMintingP22.Order memory order
    )
        internal
        returns (
            IEthenaMintingP22.Signature memory s
        )
    {
        bytes32 digest =
            target.hashOrder(
                order
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 ss
        ) =
            vm.sign(
                DELEGATE_PRIVATE_KEY,
                digest
            );

        s =
            IEthenaMintingP22.Signature({

                signature_type:
                    IEthenaMintingP22.SignatureType.EIP712,

                signature_bytes:
                    abi.encodePacked(
                        r,
                        ss,
                        v
                    )
            });
    }

    function _acceptDelegate(
        P22DelegatedBenefactor benefactor,
        address delegate
    )
        internal
    {
        benefactor.setDelegate(
            delegate
        );

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
                IEthenaMintingP22
                    .DelegatedSignerStatus
                    .ACCEPTED
            ),
            "delegate was not accepted"
        );
    }

    /*
     * ============================================================
     * TEST 1
     * ============================================================
     *
     * Actual full mint path:
     *
     * Benefactor
     *   ->
     * delegated signer
     *   ->
     * EIP-712 signature
     *   ->
     * verifyOrder
     *   ->
     * MINTER
     *   ->
     * mint()
     *   ->
     * USDC transferred
     *   ->
     * USDe minted
     */
    function test_P22_delegated_signer_full_mint_succeeds()
        external
    {
        P22DelegatedBenefactor benefactor =
            new P22DelegatedBenefactor(
                MINTING
            );

        address delegate =
            vm.addr(
                DELEGATE_PRIVATE_KEY
            );

        _authorize(
            address(benefactor)
        );

        _acceptDelegate(
            benefactor,
            delegate
        );

        uint256 collateral =
            999_900_001;

        _fundAndApprove(
            benefactor,
            collateral
        );

        IEthenaMintingP22.Order memory order =
            _order(
                address(benefactor),
                22001001,
                "P22-DELEGATE-FULL-MINT"
            );

        IEthenaMintingP22.Signature memory sig =
            _delegateSignature(
                order
            );

        IEthenaMintingP22.Route memory route =
            _route();

        assertTrue(
            target.verifyRoute(
                route
            ),
            "valid custodian route rejected"
        );

        target.verifyOrder(
            order,
            sig
        );

        uint256 usdeBefore =
            usde.balanceOf(
                address(benefactor)
            );

        vm.startPrank(
            MINTER
        );

        target.mint(
            order,
            route,
            sig
        );

        vm.stopPrank();

        assertEq(
            usdc.balanceOf(
                address(benefactor)
            ),
            0,
            "delegated full mint did not consume collateral"
        );

        assertEq(
            usde.balanceOf(
                address(benefactor)
            ),
            usdeBefore +
            1_000e18,
            "delegated full mint did not mint USDe"
        );
    }

    /*
     * ============================================================
     * TEST 2
     * ============================================================
     *
     * Sign while delegation is valid.
     * Revoke delegation.
     * Try the SAME signed order through mint().
     *
     * It must fail before collateral movement.
     */
    function test_P22_revoked_delegate_cannot_execute_full_mint()
        external
    {
        P22DelegatedBenefactor benefactor =
            new P22DelegatedBenefactor(
                MINTING
            );

        address delegate =
            vm.addr(
                DELEGATE_PRIVATE_KEY
            );

        _authorize(
            address(benefactor)
        );

        _acceptDelegate(
            benefactor,
            delegate
        );

        uint256 collateral =
            999_900_001;

        _fundAndApprove(
            benefactor,
            collateral
        );

        IEthenaMintingP22.Order memory order =
            _order(
                address(benefactor),
                22001002,
                "P22-DELEGATE-REVOKED"
            );

        IEthenaMintingP22.Signature memory sig =
            _delegateSignature(
                order
            );

        IEthenaMintingP22.Route memory route =
            _route();

        /*
         * Revoke AFTER signature creation.
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
                IEthenaMintingP22
                    .DelegatedSignerStatus
                    .REJECTED
            ),
            "delegate was not revoked"
        );

        vm.startPrank(
            MINTER
        );

        (
            bool ok,
        ) =
            MINTING.call(
                abi.encodeWithSelector(
                    target.mint.selector,
                    order,
                    route,
                    sig
                )
            );

        vm.stopPrank();

        assertTrue(
            !ok,
            "revoked delegate reached full mint"
        );

        assertEq(
            usdc.balanceOf(
                address(benefactor)
            ),
            collateral,
            "collateral changed after revoked delegate rejection"
        );
    }

    /*
     * ============================================================
     * TEST 3
     * ============================================================
     *
     * Delegate is accepted ONLY for Benefactor A.
     *
     * Signature is created for A.
     * The order is then mutated to Benefactor B.
     *
     * The delegate must NOT cross the benefactor boundary.
     */
    function test_P22_delegate_is_bound_to_its_benefactor()
        external
    {
        P22DelegatedBenefactor benefactorA =
            new P22DelegatedBenefactor(
                MINTING
            );

        P22DelegatedBenefactor benefactorB =
            new P22DelegatedBenefactor(
                MINTING
            );

        address delegate =
            vm.addr(
                DELEGATE_PRIVATE_KEY
            );

        _authorize(
            address(benefactorA)
        );

        _authorize(
            address(benefactorB)
        );

        _acceptDelegate(
            benefactorA,
            delegate
        );

        uint256 collateral =
            999_900_001;

        _fundAndApprove(
            benefactorB,
            collateral
        );

        /*
         * Signature is genuinely for Benefactor A.
         */
        IEthenaMintingP22.Order memory signedForA =
            _order(
                address(benefactorA),
                22001003,
                "P22-CROSS-BEFACTOR"
            );

        IEthenaMintingP22.Signature memory sig =
            _delegateSignature(
                signedForA
            );

        /*
         * Mutate ONLY the benefactor/beneficiary.
         */
        IEthenaMintingP22.Order memory mutatedForB =
            signedForA;

        mutatedForB.benefactor =
            address(benefactorB);

        mutatedForB.beneficiary =
            address(benefactorB);

        IEthenaMintingP22.Route memory route =
            _route();

        vm.startPrank(
            MINTER
        );

        (
            bool ok,
        ) =
            MINTING.call(
                abi.encodeWithSelector(
                    target.mint.selector,
                    mutatedForB,
                    route,
                    sig
                )
            );

        vm.stopPrank();

        assertTrue(
            !ok,
            "delegate signature crossed benefactor boundary"
        );

        assertEq(
            usdc.balanceOf(
                address(benefactorB)
            ),
            collateral,
            "benefactor B collateral changed after rejection"
        );
    }
}
