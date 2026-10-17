
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface VmP14Large {
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);

    function prank(address msgSender) external;
    function store(address target, bytes32 slot, bytes32 value) external;
}

interface IERC20P14Large {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUSDeP14Large is IERC20P14Large {
    function totalSupply() external view returns (uint256);
}

interface IEthenaMintingP14Large {
    enum SignatureType { EIP712, EIP1271 }
    enum OrderType { MINT, REDEEM }

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

    function usde() external view returns (address);
    function hashOrder(Order calldata order) external view returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    ) external view returns (bytes32);

    function verifyRoute(Route calldata route) external view returns (bool);

    function verifyStablesLimit(
        uint128 collateralAmount,
        uint128 usdeAmount,
        address collateralAsset,
        OrderType orderType
    ) external view returns (bool);

    function mint(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    ) external;
}

contract MintingV2P14LargeAmountFullPathTest {
    address internal constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address internal constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address internal constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    uint256 internal constant MINTER_PRIVATE_KEY = 1;

    address internal constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    VmP14Large internal constant vm = VmP14Large(
        address(uint160(uint256(keccak256("hevm cheat code"))))
    );

    IEthenaMintingP14Large internal constant target =
        IEthenaMintingP14Large(MINTING);

    IERC20P14Large internal constant usdc = IERC20P14Large(USDC);

    uint128 internal constant ORDER_USDE = 1_000_000e18;

    // $999,900.01 collateral for a $1,000,000 order.
    uint128 internal constant COLLATERAL_SUB_1_BPS =
        999_900_010_000;

    // $999,900.00 collateral: exactly 1 basis point short.
    uint128 internal constant COLLATERAL_EXACT_1_BPS =
        999_900_000_000;

    function _assertTrue(bool condition, string memory reason)
        internal
        pure
    {
        require(condition, reason);
    }

    function _assertEq(
        uint256 actual,
        uint256 expected,
        string memory reason
    ) internal pure {
        require(actual == expected, reason);
    }

    function _sign(IEthenaMintingP14Large.Order memory order)
        internal
        returns (
            IEthenaMintingP14Large.Signature memory sig,
            bytes32 digest
        )
    {
        digest = target.hashOrder(order);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(MINTER_PRIVATE_KEY, digest);

        sig = IEthenaMintingP14Large.Signature({
            signature_type: IEthenaMintingP14Large.SignatureType.EIP712,
            signature_bytes: abi.encodePacked(r, s, v)
        });
    }

    function _route()
        internal
        pure
        returns (IEthenaMintingP14Large.Route memory route)
    {
        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        route = IEthenaMintingP14Large.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _order(
        string memory orderId,
        uint128 collateralAmount,
        uint128 usdeAmount,
        uint128 nonce
    )
        internal
        view
        returns (IEthenaMintingP14Large.Order memory order)
    {
        order = IEthenaMintingP14Large.Order({
            order_id: orderId,
            order_type: IEthenaMintingP14Large.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: nonce,
            benefactor: MINTER,
            beneficiary: MINTER,
            collateral_asset: USDC,
            collateral_amount: collateralAmount,
            usde_amount: usdeAmount
        });
    }

    function test_large_mint_accepts_sub_one_bps_gap() external {
        // Local-fork-only balance setup; USDC balance mapping slot 9.
        bytes32 balanceSlot = keccak256(abi.encode(MINTER, uint256(9)));

        vm.store(
            USDC,
            balanceSlot,
            bytes32(uint256(1_000_000_000_000))
        );

        _assertEq(
            usdc.balanceOf(MINTER),
            1_000_000_000_000,
            "local USDC balance setup failed"
        );

        vm.prank(MINTER);
        bool approved = usdc.approve(MINTING, type(uint256).max);
        _assertTrue(approved, "USDC approval failed");

        IUSDeP14Large usde = IUSDeP14Large(target.usde());

        uint256 usdeBefore = usde.balanceOf(MINTER);
        uint256 supplyBefore = usde.totalSupply();
        uint256 minterUsdcBefore = usdc.balanceOf(MINTER);
        uint256 custodianUsdcBefore = usdc.balanceOf(CUSTODIAN);

        IEthenaMintingP14Large.Order memory order = _order(
            "P14-LARGE-SUB-1-BPS",
            COLLATERAL_SUB_1_BPS,
            ORDER_USDE,
            14990001
        );

        IEthenaMintingP14Large.Route memory route = _route();

        _assertTrue(target.verifyRoute(route), "route rejected");

        _assertTrue(
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                order.collateral_asset,
                order.order_type
            ),
            "sub-1-bps gap rejected by guard"
        );

        (
            IEthenaMintingP14Large.Signature memory sig,
            bytes32 digest
        ) = _sign(order);

        _assertTrue(
            target.verifyOrder(order, sig) == digest,
            "order signature verification failed"
        );

        vm.prank(MINTER);
        target.mint(order, route, sig);

        _assertEq(
            usde.balanceOf(MINTER) - usdeBefore,
            ORDER_USDE,
            "unexpected beneficiary USDe increase"
        );

        _assertEq(
            usde.totalSupply() - supplyBefore,
            ORDER_USDE,
            "unexpected USDe supply increase"
        );

        _assertEq(
            minterUsdcBefore - usdc.balanceOf(MINTER),
            COLLATERAL_SUB_1_BPS,
            "unexpected minter USDC debit"
        );

        _assertEq(
            usdc.balanceOf(CUSTODIAN) - custodianUsdcBefore,
            COLLATERAL_SUB_1_BPS,
            "unexpected custodian USDC credit"
        );
    }

    function test_large_mint_rejects_exact_one_bps_gap() external {
        IEthenaMintingP14Large.Order memory order = _order(
            "P14-LARGE-EXACT-1-BPS",
            COLLATERAL_EXACT_1_BPS,
            ORDER_USDE,
            14990002
        );

        IEthenaMintingP14Large.Route memory route = _route();

        _assertTrue(
            !target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                order.collateral_asset,
                order.order_type
            ),
            "exact-1-bps gap unexpectedly accepted"
        );

        (
            IEthenaMintingP14Large.Signature memory sig,
            bytes32 digest
        ) = _sign(order);

        _assertTrue(digest != bytes32(0), "order digest is zero");

        vm.prank(MINTER);

        (bool success, bytes memory revertData) = address(target).call(
            abi.encodeWithSelector(
                IEthenaMintingP14Large.mint.selector,
                order,
                route,
                sig
            )
        );

        _assertTrue(!success, "exact-1-bps mint unexpectedly succeeded");
        _assertTrue(revertData.length >= 4, "missing revert selector");

        bytes4 actualError;
        assembly {
            actualError := mload(add(revertData, 32))
        }

        _assertTrue(
            actualError == bytes4(keccak256("InvalidStablePrice()")),
            "unexpected revert reason"
        );
    }

    function test_unprivileged_caller_cannot_mint_even_with_valid_order_signature()
        external
    {
        address unprivileged = address(0xBEEF);

        IEthenaMintingP14Large.Order memory order = _order(
            "P14-UNPRIVILEGED-CALLER",
            COLLATERAL_SUB_1_BPS,
            ORDER_USDE,
            14990003
        );

        IEthenaMintingP14Large.Route memory route = _route();

        (
            IEthenaMintingP14Large.Signature memory sig,
            bytes32 digest
        ) = _sign(order);

        _assertTrue(digest != bytes32(0), "order digest is zero");

        _assertTrue(
            target.verifyOrder(order, sig) == digest,
            "signed order should be valid before caller authorization check"
        );

        vm.prank(unprivileged);

        (bool success, bytes memory revertData) = address(target).call(
            abi.encodeWithSelector(
                IEthenaMintingP14Large.mint.selector,
                order,
                route,
                sig
            )
        );

        _assertTrue(!success, "unprivileged caller unexpectedly minted");
        _assertTrue(
            revertData.length >= 4,
            "missing authorization revert selector"
        );

        bytes4 actualError;
        assembly {
            actualError := mload(add(revertData, 32))
        }

        _assertTrue(
            actualError ==
                bytes4(
                    keccak256(
                        "AccessControlUnauthorizedAccount(address,bytes32)"
                    )
                ),
            "mint failed for a reason other than missing caller role"
        );
    }
}
