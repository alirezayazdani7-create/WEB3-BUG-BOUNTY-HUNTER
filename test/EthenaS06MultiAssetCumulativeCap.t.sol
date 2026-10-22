// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IS06MultiAssetMint {
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

    function tokenConfig(address)
        external
        view
        returns (uint8, bool, uint128, uint128);

    function globalConfig()
        external
        view
        returns (uint128, uint128);

    function totalPerBlock(uint256)
        external
        view
        returns (uint128, uint128);

    function totalPerBlockPerAsset(uint256, address)
        external
        view
        returns (uint128, uint128);

    function hashOrder(Order calldata)
        external
        view
        returns (bytes32);

    function verifyOrder(
        Order calldata,
        Signature calldata
    ) external view returns (bytes32);

    function verifyRoute(Route calldata)
        external
        view
        returns (bool);

    function verifyStablesLimit(
        uint128,
        uint128,
        address,
        OrderType
    ) external view returns (bool);

    function mint(
        Order calldata,
        Route calldata,
        Signature calldata
    ) external;

    function isWhitelistedBenefactor(address)
        external
        view
        returns (bool);

    function isApprovedBeneficiary(address, address)
        external
        view
        returns (bool);

    function hasRole(bytes32, address)
        external
        view
        returns (bool);
}

interface IERC20MultiAssetTest {
    function approve(address spender, uint256 amount)
        external
        returns (bool);
}

contract EthenaS06MultiAssetCumulativeCapTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    uint256 constant PRIVATE_KEY = 1;

    bytes32 constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    uint128 constant UNIT = 1e18;
    uint128 constant COLLATERAL_AMOUNT = 1e6;

    IS06MultiAssetMint target =
        IS06MultiAssetMint(MINTING);

    function setUp() public {
        vm.createSelectFork(
            vm.envString("ETHENA_FORK_RPC")
        );
    }

    function _seedAuthorization() internal {
        vm.store(
            MINTING,
            bytes32(uint256(4)),
            bytes32(uint256(1))
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(uint256(4))),
            bytes32(uint256(uint160(MINTER)))
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(MINTER, uint256(5))),
            bytes32(uint256(1))
        );

        uint256 setBase =
            uint256(keccak256(abi.encode(MINTER, uint256(6))));

        vm.store(
            MINTING,
            bytes32(setBase),
            bytes32(uint256(1))
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(setBase)),
            bytes32(uint256(uint160(MINTER)))
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(MINTER, setBase + 1)),
            bytes32(uint256(1))
        );

        bytes32 roleDataSlot =
            keccak256(abi.encode(MINTER_ROLE, uint256(0)));

        vm.store(
            MINTING,
            keccak256(abi.encode(MINTER, roleDataSlot)),
            bytes32(uint256(1))
        );

        assertTrue(
            target.isWhitelistedBenefactor(MINTER),
            "whitelist setup failed"
        );

        assertTrue(
            target.isApprovedBeneficiary(MINTER, MINTER),
            "beneficiary approval setup failed"
        );

        assertTrue(
            target.hasRole(MINTER_ROLE, MINTER),
            "MINTER_ROLE setup failed"
        );
    }

    function _seedAssetMinted(
        address asset,
        uint128 value
    ) internal {
        bytes32 outer =
            keccak256(abi.encode(block.number, uint256(14)));

        bytes32 slot =
            keccak256(abi.encode(asset, outer));

        vm.store(
            MINTING,
            slot,
            bytes32(uint256(value))
        );

        (uint128 observed,) =
            target.totalPerBlockPerAsset(
                block.number,
                asset
            );

        assertEq(
            observed,
            value,
            "asset counter seed mismatch"
        );
    }

    function _seedGlobalMinted(uint128 value) internal {
        bytes32 slot =
            keccak256(abi.encode(block.number, uint256(13)));

        vm.store(
            MINTING,
            slot,
            bytes32(uint256(value))
        );

        (uint128 observed,) =
            target.totalPerBlock(block.number);

        assertEq(
            observed,
            value,
            "global counter seed mismatch"
        );
    }

    function _order(
        address asset,
        uint128 nonce
    )
        internal
        view
        returns (IS06MultiAssetMint.Order memory)
    {
        return IS06MultiAssetMint.Order({
            order_id: string.concat(
                "S06-MULTI-ASSET-",
                vm.toString(nonce)
            ),
            order_type: IS06MultiAssetMint.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: nonce,
            benefactor: MINTER,
            beneficiary: MINTER,
            collateral_asset: asset,
            collateral_amount: COLLATERAL_AMOUNT,
            usde_amount: UNIT
        });
    }

    function _route()
        internal
        pure
        returns (IS06MultiAssetMint.Route memory route)
    {
        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        route = IS06MultiAssetMint.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _sign(
        IS06MultiAssetMint.Order memory order
    )
        internal
        returns (IS06MultiAssetMint.Signature memory sig)
    {
        bytes32 digest = target.hashOrder(order);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PRIVATE_KEY, digest);

        sig = IS06MultiAssetMint.Signature({
            signature_type:
                IS06MultiAssetMint.SignatureType.EIP712,
            signature_bytes: abi.encodePacked(r, s, v)
        });

        assertEq(
            uint256(target.verifyOrder(order, sig)),
            uint256(digest),
            "order signature verification failed"
        );
    }

    function _attemptMint(
        address asset,
        uint128 nonce
    )
        internal
        returns (bool success, bytes memory data)
    {
        IS06MultiAssetMint.Order memory order =
            _order(asset, nonce);

        IS06MultiAssetMint.Route memory route = _route();

        assertTrue(
            target.verifyRoute(route),
            "route rejected"
        );

        assertTrue(
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                asset,
                order.order_type
            ),
            "stable-price guard rejected test order"
        );

        IS06MultiAssetMint.Signature memory sig =
            _sign(order);

        vm.prank(MINTER);

        (success, data) = MINTING.call(
            abi.encodeWithSelector(
                IS06MultiAssetMint.mint.selector,
                order,
                route,
                sig
            )
        );
    }

    function _assertGlobalCapError(
        bytes memory data
    ) internal pure {
        assertGe(
            data.length,
            4,
            "missing revert selector"
        );

        bytes4 actual;

        assembly {
            actual := mload(add(data, 32))
        }

        bytes4 expected =
            bytes4(
                keccak256("GlobalMaxMintPerBlockExceeded()")
            );

        assertEq(
            uint32(actual),
            uint32(expected),
            "wrong cap revert"
        );
    }

    function _approveUSDC() internal {
        vm.prank(MINTER);

        (bool ok, bytes memory data) = USDC.call(
            abi.encodeWithSelector(
                IERC20MultiAssetTest.approve.selector,
                MINTING,
                type(uint256).max
            )
        );

        require(ok, "USDC approve call reverted");

        require(
            data.length == 0 ||
                (
                    data.length >= 32 &&
                    abi.decode(data, (bool))
                ),
            "USDC approval returned false"
        );
    }

    function _approveUSDT() internal {
        vm.prank(MINTER);

        (bool ok, bytes memory data) = USDT.call(
            abi.encodeWithSelector(
                IERC20MultiAssetTest.approve.selector,
                MINTING,
                type(uint256).max
            )
        );

        require(ok, "USDT approve call reverted");

        require(
            data.length == 0 ||
                (
                    data.length >= 32 &&
                    abi.decode(data, (bool))
                ),
            "USDT approval returned false"
        );
    }

    function test_GlobalMintCapIsSharedAcrossUSDCAndUSDT()
        external
    {
        _seedAuthorization();

        // Test-only token balances on the local fork.
        deal(USDC, MINTER, 10_000_000);
        deal(USDT, MINTER, 10_000_000);

        _approveUSDC();
        _approveUSDT();

        (, bool usdcActive, uint128 usdcCap,) =
            target.tokenConfig(USDC);

        (, bool usdtActive, uint128 usdtCap,) =
            target.tokenConfig(USDT);

        (uint128 globalCap,) = target.globalConfig();

        assertTrue(usdcActive, "USDC inactive");
        assertTrue(usdtActive, "USDT inactive");

        assertGe(
            usdcCap,
            UNIT,
            "USDC cap below test amount"
        );

        assertGe(
            usdtCap,
            UNIT,
            "USDT cap below test amount"
        );

        assertGt(
            globalCap,
            UNIT,
            "global cap below test amount"
        );

        _seedAssetMinted(USDC, 0);
        _seedAssetMinted(USDT, 0);
        _seedGlobalMinted(globalCap - UNIT);

        // First local-fork mint attempts to reach the global cap.
        (bool firstOk, bytes memory firstData) =
            _attemptMint(USDC, 906201);

        if (!firstOk) {
            emit log_named_bytes(
                "USDC mint revert",
                firstData
            );
        }

        assertTrue(
            firstOk,
            "USDC boundary mint should reach global cap"
        );

        (uint128 globalAfterUSDC,) =
            target.totalPerBlock(block.number);

        (uint128 usdcAfter,) =
            target.totalPerBlockPerAsset(
                block.number,
                USDC
            );

        (uint128 usdtAfter,) =
            target.totalPerBlockPerAsset(
                block.number,
                USDT
            );

        assertEq(
            globalAfterUSDC,
            globalCap,
            "global counter did not reach cap"
        );

        assertEq(
            usdcAfter,
            UNIT,
            "USDC asset counter mismatch"
        );

        assertEq(
            usdtAfter,
            0,
            "USDT counter changed before its mint"
        );

        // Second mint must fail if the global cap is shared.
        (bool secondOk, bytes memory secondData) =
            _attemptMint(USDT, 906202);

        assertFalse(
            secondOk,
            "USDT mint bypassed shared global cap"
        );

        _assertGlobalCapError(secondData);

        (uint128 globalFinal,) =
            target.totalPerBlock(block.number);

        (uint128 usdcFinal,) =
            target.totalPerBlockPerAsset(
                block.number,
                USDC
            );

        (uint128 usdtFinal,) =
            target.totalPerBlockPerAsset(
                block.number,
                USDT
            );

        assertEq(
            globalFinal,
            globalCap,
            "global counter changed after rejected USDT mint"
        );

        assertEq(
            usdcFinal,
            UNIT,
            "USDC counter changed after rejected USDT mint"
        );

        assertEq(
            usdtFinal,
            0,
            "USDT counter changed after rejected mint"
        );
    }
}
