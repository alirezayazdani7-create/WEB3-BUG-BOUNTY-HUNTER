
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IS06CumulativeProbe {
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

    function tokenConfig(address)
        external view returns (uint8, bool, uint128, uint128);
    function globalConfig() external view returns (uint128, uint128);
    function hashOrder(Order calldata) external view returns (bytes32);
    function verifyOrder(Order calldata, Signature calldata)
        external view returns (bytes32);
    function verifyRoute(Route calldata) external view returns (bool);
    function verifyStablesLimit(uint128, uint128, address, OrderType)
        external view returns (bool);
    function mint(Order calldata, Route calldata, Signature calldata) external;
    function isWhitelistedBenefactor(address) external view returns (bool);
    function isApprovedBeneficiary(address, address) external view returns (bool);
    function hasRole(bytes32, address) external view returns (bool);
    function totalPerBlock(uint256) external view returns (uint128, uint128);
    function totalPerBlockPerAsset(uint256, address)
        external view returns (uint128, uint128);
}

contract EthenaS06CumulativeCapEnforcementTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;
    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;
    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    uint256 constant PRIVATE_KEY = 1;
    uint128 constant REQUEST_USDE = 1e18;
    uint128 constant COLLATERAL_USDC = 1e6;

    bytes32 constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    IS06CumulativeProbe target = IS06CumulativeProbe(MINTING);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
    }

    function _seedAuthorization() internal {
        bytes32 member = bytes32(uint256(uint160(MINTER)));

        // Test-only authorization setup on the local fork.
        vm.store(MINTING, bytes32(uint256(4)), bytes32(uint256(1)));
        vm.store(MINTING, keccak256(abi.encode(uint256(4))), member);
        vm.store(
            MINTING,
            keccak256(abi.encode(member, uint256(5))),
            bytes32(uint256(1))
        );

        uint256 setBase = uint256(keccak256(abi.encode(MINTER, uint256(6))));
        vm.store(MINTING, bytes32(setBase), bytes32(uint256(1)));
        vm.store(MINTING, keccak256(abi.encode(setBase)), member);
        vm.store(
            MINTING,
            keccak256(abi.encode(member, setBase + 1)),
            bytes32(uint256(1))
        );

        bytes32 roleDataSlot = keccak256(abi.encode(MINTER_ROLE, uint256(0)));
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

    function _seedGlobalCounter(uint128 value) internal {
        bytes32 slot = keccak256(abi.encode(block.number, uint256(13)));
        vm.store(MINTING, slot, bytes32(uint256(value)));

        (uint128 observed,) = target.totalPerBlock(block.number);
        assertEq(observed, value, "global counter seed mismatch");
    }

    function _seedAssetCounter(uint128 value) internal {
        bytes32 outer = keccak256(abi.encode(block.number, uint256(14)));
        bytes32 slot = keccak256(abi.encode(USDC, outer));
        vm.store(MINTING, slot, bytes32(uint256(value)));

        (uint128 observed,) =
            target.totalPerBlockPerAsset(block.number, USDC);
        assertEq(observed, value, "asset counter seed mismatch");
    }

    function _buildOrder(uint128 nonce)
        internal view returns (IS06CumulativeProbe.Order memory)
    {
        return IS06CumulativeProbe.Order({
            order_id: string.concat("S06-CUMULATIVE-", vm.toString(nonce)),
            order_type: IS06CumulativeProbe.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: nonce,
            benefactor: MINTER,
            beneficiary: MINTER,
            collateral_asset: USDC,
            collateral_amount: COLLATERAL_USDC,
            usde_amount: REQUEST_USDE
        });
    }

    function _buildRoute()
        internal pure returns (IS06CumulativeProbe.Route memory route)
    {
        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        route = IS06CumulativeProbe.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _signOrder(IS06CumulativeProbe.Order memory order)
        internal returns (IS06CumulativeProbe.Signature memory sig)
    {
        bytes32 digest = target.hashOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);

        sig = IS06CumulativeProbe.Signature({
            signature_type: IS06CumulativeProbe.SignatureType.EIP712,
            signature_bytes: abi.encodePacked(r, s, v)
        });

        assertEq(
            uint256(target.verifyOrder(order, sig)),
            uint256(digest),
            "signature verification failed"
        );
    }

    function _assertRejectedByCap(uint128 nonce) internal {
        IS06CumulativeProbe.Order memory order = _buildOrder(nonce);
        IS06CumulativeProbe.Route memory route = _buildRoute();

        assertTrue(target.verifyRoute(route), "route rejected before cap check");
        assertTrue(
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                USDC,
                order.order_type
            ),
            "stable-price guard rejected probe"
        );

        IS06CumulativeProbe.Signature memory sig = _signOrder(order);

        (uint128 assetBefore,) =
            target.totalPerBlockPerAsset(block.number, USDC);
        (uint128 globalBefore,) = target.totalPerBlock(block.number);

        // Local-fork call only.
        vm.prank(MINTER);
        (bool success, bytes memory data) = MINTING.call(
            abi.encodeWithSelector(
                IS06CumulativeProbe.mint.selector,
                order,
                route,
                sig
            )
        );

        assertFalse(success, "mint unexpectedly passed cap");
        assertGe(data.length, 4, "missing revert selector");

        bytes4 actual;
        assembly {
            actual := mload(add(data, 32))
        }

        bytes4 assetError =
            bytes4(keccak256("MaxMintPerBlockExceeded()"));
        bytes4 globalError =
            bytes4(keccak256("GlobalMaxMintPerBlockExceeded()"));

        assertTrue(
            actual == assetError || actual == globalError,
            "revert was not an expected cap error"
        );

        (uint128 assetAfter,) =
            target.totalPerBlockPerAsset(block.number, USDC);
        (uint128 globalAfter,) = target.totalPerBlock(block.number);

        assertEq(
            assetAfter,
            assetBefore,
            "asset counter changed after reverted mint"
        );
        assertEq(
            globalAfter,
            globalBefore,
            "global counter changed after reverted mint"
        );

        emit log_named_bytes32("Confirmed cap error", bytes32(actual));
    }

    function test_RejectsCumulativeMintAboveAssetCap() external {
        _seedAuthorization();

        (, bool active, uint128 assetCap,) = target.tokenConfig(USDC);
        (uint128 globalCap,) = target.globalConfig();

        assertTrue(active, "USDC inactive");
        assertGt(assetCap, REQUEST_USDE, "asset cap too small");
        assertGt(globalCap, REQUEST_USDE, "global cap too small");

        // Cross the asset cap while the global counter remains zero.
        _seedGlobalCounter(0);
        _seedAssetCounter(assetCap - REQUEST_USDE + 1);

        _assertRejectedByCap(906101);
    }

    function test_RejectsCumulativeMintAboveGlobalCap() external {
        _seedAuthorization();

        (, bool active, uint128 assetCap,) = target.tokenConfig(USDC);
        (uint128 globalCap,) = target.globalConfig();

        assertTrue(active, "USDC inactive");
        assertGt(globalCap, REQUEST_USDE, "global cap too small");

        // USDC cannot isolate the global cap when its cap is equal to
        // or greater than the global cap. Do not claim a global-cap pass.
        if (assetCap >= globalCap) {
            emit log("INCONCLUSIVE: USDC cap cannot isolate global cap.");
            emit log_named_uint("USDC asset cap", assetCap);
            emit log_named_uint("Global cap", globalCap);
            return;
        }

        _seedAssetCounter(0);
        _seedGlobalCounter(globalCap - REQUEST_USDE + 1);

        _assertRejectedByCap(906102);
    }
}
