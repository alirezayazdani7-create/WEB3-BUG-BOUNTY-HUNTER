
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);

    function prank(address msgSender) external;

    function store(address target, bytes32 slot, bytes32 value) external;
}

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUSDeMinimal is IERC20Minimal {
    function totalSupply() external view returns (uint256);
}

interface IEthenaMintingP14 {
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

    function usde() external view returns (address);
    function hashOrder(Order calldata order) external view returns (bytes32);
    function verifyOrder(Order calldata order, Signature calldata signature)
        external
        view
        returns (bytes32);

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

contract MintingV2P14FullPathTest {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    // Local test key only; never use this key on Mainnet.
    uint256 constant MINTER_PRIVATE_KEY = 1;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    Vm constant vm = Vm(
        address(
            uint160(
                uint256(
                    keccak256("hevm cheat code")
                )
            )
        )
    );

    IEthenaMintingP14 constant target =
        IEthenaMintingP14(MINTING);

    IERC20Minimal constant usdc = IERC20Minimal(USDC);

    function assertTrue(bool value, string memory reason)
        internal
        pure
    {
        require(value, reason);
    }

    function assertEq(uint256 a, uint256 b, string memory reason)
        internal
        pure
    {
        require(a == b, reason);
    }

    function _sign(IEthenaMintingP14.Order memory order)
        internal
        returns (IEthenaMintingP14.Signature memory sig, bytes32 digest)
    {
        digest = target.hashOrder(order);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(MINTER_PRIVATE_KEY, digest);

        sig = IEthenaMintingP14.Signature({
            signature_type: IEthenaMintingP14.SignatureType.EIP712,
            signature_bytes: abi.encodePacked(r, s, v)
        });
    }

    function _route()
        internal
        pure
        returns (IEthenaMintingP14.Route memory route)
    {
        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        route = IEthenaMintingP14.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function test_P14_01_full_mint_accepts_99_unit_gap()
        external
    {
        // This storage write affects only the local Anvil fork.
        // Verify the USDC storage layout before relying on this setup.
        bytes32 usdcBalanceSlot =
            keccak256(abi.encode(MINTER, uint256(9)));

        vm.store(
            USDC,
            usdcBalanceSlot,
            bytes32(uint256(1_000_000))
        );

        assertEq(
            usdc.balanceOf(MINTER),
            1_000_000,
            "local USDC balance injection failed"
        );

        vm.prank(MINTER);
        bool approvalOk = usdc.approve(MINTING, type(uint256).max);

        assertTrue(approvalOk, "local USDC approval failed");

        address usdeAddress = target.usde();

        uint256 usdeBefore =
            IUSDeMinimal(usdeAddress).balanceOf(MINTER);

        uint256 supplyBefore =
            IUSDeMinimal(usdeAddress).totalSupply();

        uint256 benefactorUsdcBefore = usdc.balanceOf(MINTER);
        uint256 custodianUsdcBefore = usdc.balanceOf(CUSTODIAN);

        IEthenaMintingP14.Order memory order =
            IEthenaMintingP14.Order({
                order_id: "P14-99-UNIT-GAP",
                order_type: IEthenaMintingP14.OrderType.MINT,
                expiry: uint120(block.timestamp + 1 days),
                nonce: 14_990_001,
                benefactor: MINTER,
                beneficiary: MINTER,
                collateral_asset: USDC,
                collateral_amount: 999_901,
                usde_amount: 1e18
            });

        IEthenaMintingP14.Route memory route = _route();

        assertTrue(target.verifyRoute(route), "P14 route rejected");

        assertTrue(
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                order.collateral_asset,
                order.order_type
            ),
            "99-unit gap rejected by stable guard"
        );

        (IEthenaMintingP14.Signature memory sig, bytes32 digest) =
            _sign(order);

        bytes32 verifiedDigest = target.verifyOrder(order, sig);

        assertTrue(
            verifiedDigest == digest,
            "signed order digest mismatch"
        );

        vm.prank(MINTER);
        target.mint(order, route, sig);

        uint256 usdeAfter =
            IUSDeMinimal(usdeAddress).balanceOf(MINTER);

        uint256 supplyAfter =
            IUSDeMinimal(usdeAddress).totalSupply();

        uint256 benefactorUsdcAfter = usdc.balanceOf(MINTER);
        uint256 custodianUsdcAfter = usdc.balanceOf(CUSTODIAN);

        assertEq(
            usdeAfter - usdeBefore,
            1e18,
            "beneficiary USDe delta mismatch"
        );

        assertEq(
            supplyAfter - supplyBefore,
            1e18,
            "USDe total supply delta mismatch"
        );

        assertEq(
            benefactorUsdcBefore - benefactorUsdcAfter,
            999_901,
            "benefactor USDC debit mismatch"
        );

        assertEq(
            custodianUsdcAfter - custodianUsdcBefore,
            999_901,
            "custodian USDC credit mismatch"
        );

        assertEq(
            1_000_000 - order.collateral_amount,
            99,
            "P14 economic gap is not 99"
        );
    }

    function test_P14_02_full_mint_rejects_100_unit_gap()
        external
    {
        IEthenaMintingP14.Order memory order =
            IEthenaMintingP14.Order({
                order_id: "P14-100-UNIT-GAP",
                order_type: IEthenaMintingP14.OrderType.MINT,
                expiry: uint120(block.timestamp + 1 days),
                nonce: 14_990_002,
                benefactor: MINTER,
                beneficiary: MINTER,
                collateral_asset: USDC,
                collateral_amount: 999_900,
                usde_amount: 1e18
            });

        IEthenaMintingP14.Route memory route = _route();

        bool stableAccepted = target.verifyStablesLimit(
            order.collateral_amount,
            order.usde_amount,
            order.collateral_asset,
            order.order_type
        );

        assertTrue(
            !stableAccepted,
            "100-unit gap unexpectedly accepted"
        );

        (IEthenaMintingP14.Signature memory sig, bytes32 digest) =
            _sign(order);

        assertTrue(digest != bytes32(0), "100-gap order digest is zero");

        vm.prank(MINTER);

        (bool ok, bytes memory revertData) =
            address(target).call(
                abi.encodeWithSelector(
                    IEthenaMintingP14.mint.selector,
                    order,
                    route,
                    sig
                )
            );

        assertTrue(!ok, "full mint path accepted 100-unit gap");

        assertTrue(
            revertData.length >= 4,
            "revert data is missing an error selector"
        );

        bytes4 actualError;

        assembly {
            actualError := mload(add(revertData, 32))
        }

        bytes4 expectedError =
            bytes4(keccak256("InvalidStablePrice()"));

        require(
            actualError == expectedError,
            "unexpected revert selector: expected InvalidStablePrice()"
        );
    }
}
