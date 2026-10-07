// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);

    function prank(address msgSender) external;
}

interface IEthenaMintingP16 {
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

    function hashOrder(
        Order calldata order
    ) external view returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    ) external view returns (bytes32);

    function verifyRoute(
        Route calldata route
    ) external view returns (bool);

    function mint(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    ) external;
}

contract MintingV2P16SignatureBindingTest {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    uint256 constant MINTER_PRIVATE_KEY = 1;

    Vm constant vm =
        Vm(address(uint160(uint256(
            keccak256("hevm cheat code")
        ))));

    IEthenaMintingP16 constant target =
        IEthenaMintingP16(MINTING);

    function assertTrue(
        bool value,
        string memory reason
    ) internal pure {
        require(value, reason);
    }

    function _baseOrder()
        internal
        view
        returns (IEthenaMintingP16.Order memory o)
    {
        o = IEthenaMintingP16.Order({
            order_id: "P16-BINDING",
            order_type: IEthenaMintingP16.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: 16001001,
            benefactor: MINTER,
            beneficiary: MINTER,
            collateral_asset: USDC,
            collateral_amount: 999_900_001,
            usde_amount: 1_000e18
        });
    }

    function _route(address custodian)
        internal
        pure
        returns (IEthenaMintingP16.Route memory r)
    {
        address[] memory addresses =
            new address[](1);

        uint128[] memory ratios =
            new uint128[](1);

        addresses[0] = custodian;
        ratios[0] = 10_000;

        r = IEthenaMintingP16.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _sign(
        IEthenaMintingP16.Order memory order
    )
        internal
        returns (IEthenaMintingP16.Signature memory sig)
    {
        bytes32 digest =
            target.hashOrder(order);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = vm.sign(
            MINTER_PRIVATE_KEY,
            digest
        );

        sig = IEthenaMintingP16.Signature({
            signature_type:
                IEthenaMintingP16.SignatureType.EIP712,
            signature_bytes:
                abi.encodePacked(r, s, v)
        });
    }

    function _accepts(
        IEthenaMintingP16.Order memory order,
        IEthenaMintingP16.Signature memory sig
    )
        internal
        view
        returns (bool)
    {
        (bool ok,) = MINTING.staticcall(
            abi.encodeWithSelector(
                target.verifyOrder.selector,
                order,
                sig
            )
        );

        return ok;
    }

    function _mutateAndCheck(
        IEthenaMintingP16.Order memory mutated,
        IEthenaMintingP16.Signature memory originalSig,
        string memory reason
    )
        internal
        view
    {
        assertTrue(
            !_accepts(mutated, originalSig),
            reason
        );
    }

    /*
     * P16-01
     *
     * Prove that every economically relevant Order field
     * is bound to the EIP-712 signature.
     */
    function test_P16_order_signature_is_field_bound()
        external
    {
        IEthenaMintingP16.Order memory original =
            _baseOrder();

        IEthenaMintingP16.Signature memory sig =
            _sign(original);

        // Baseline signed order MUST verify.
        target.verifyOrder(
            original,
            sig
        );

        IEthenaMintingP16.Order memory m;

        // order_id
        m = original;
        m.order_id = "P16-MUTATED";

        _mutateAndCheck(
            m,
            sig,
            "order_id is not signature-bound"
        );

        // expiry
        m = original;
        m.expiry = original.expiry + 1;

        _mutateAndCheck(
            m,
            sig,
            "expiry is not signature-bound"
        );

        // nonce
        m = original;
        m.nonce = original.nonce + 1;

        _mutateAndCheck(
            m,
            sig,
            "nonce is not signature-bound"
        );

        // beneficiary
        m = original;
        m.beneficiary =
            address(0xbeef);

        _mutateAndCheck(
            m,
            sig,
            "beneficiary is not signature-bound"
        );

        // benefactor
        m = original;
        m.benefactor =
            address(0xcafe);

        _mutateAndCheck(
            m,
            sig,
            "benefactor is not signature-bound"
        );

        // collateral amount
        m = original;
        m.collateral_amount =
            original.collateral_amount - 1;

        _mutateAndCheck(
            m,
            sig,
            "collateral amount is not signature-bound"
        );

        // USDe amount
        m = original;
        m.usde_amount =
            original.usde_amount + 1;

        _mutateAndCheck(
            m,
            sig,
            "USDe amount is not signature-bound"
        );

        // collateral asset
        m = original;
        m.collateral_asset =
            address(0xd00d);

        _mutateAndCheck(
            m,
            sig,
            "collateral asset is not signature-bound"
        );

        // order type
        m = original;
        m.order_type =
            IEthenaMintingP16.OrderType.REDEEM;

        _mutateAndCheck(
            m,
            sig,
            "order type is not signature-bound"
        );
    }

    /*
     * P16-02
     *
     * Route is supplied separately from the signed Order.
     *
     * This test intentionally observes that separation.
     * It does NOT claim that a mutated route is exploitable.
     */
    function test_P16_route_is_separate_from_order_signature()
        external
    {
        IEthenaMintingP16.Order memory original =
            _baseOrder();

        IEthenaMintingP16.Signature memory sig =
            _sign(original);

        IEthenaMintingP16.Route memory route =
            _route(CUSTODIAN);

        assertTrue(
            target.verifyRoute(route),
            "baseline route rejected"
        );

        target.verifyOrder(
            original,
            sig
        );

        IEthenaMintingP16.Route memory mutated =
            _route(
                address(0xbeef)
            );

        bool mutatedRouteAccepted =
            target.verifyRoute(mutated);

        emit P16RouteObservation(
            mutatedRouteAccepted,
            _accepts(original, sig)
        );
    }

    event P16RouteObservation(
        bool mutatedRouteAcceptedByRouteGuard,
        bool originalOrderSignatureAccepted
    );

    /*
     * P16-03
     *
     * Try to replay a valid signature with a reduced
     * collateral amount.
     *
     * If mint rejects, the precision-loss condition cannot
     * be turned into a caller-side collateral reduction
     * through Order mutation.
     */
    function test_P16_signed_order_cannot_be_replayed_with_mutated_order()
        external
    {
        IEthenaMintingP16.Order memory original =
            _baseOrder();

        IEthenaMintingP16.Signature memory sig =
            _sign(original);

        IEthenaMintingP16.Route memory route =
            _route(CUSTODIAN);

        assertTrue(
            target.verifyRoute(route),
            "baseline route rejected"
        );

        target.verifyOrder(
            original,
            sig
        );

        IEthenaMintingP16.Order memory mutated =
            original;

        mutated.collateral_amount =
            original.collateral_amount - 99_999;

        (bool ok,) =
            MINTING.call(
                abi.encodeWithSelector(
                    target.mint.selector,
                    mutated,
                    route,
                    sig
                )
            );

        assertTrue(
            !ok,
            "mutated signed order reached mint"
        );
    }
}
