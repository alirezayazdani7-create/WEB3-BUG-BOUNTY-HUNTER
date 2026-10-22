
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IS06SequentialMint {
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
    function totalPerBlock(uint256) external view returns (uint128, uint128);
    function totalPerBlockPerAsset(uint256, address)
        external view returns (uint128, uint128);
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
}

interface IERC20MintTest {
    function approve(address spender, uint256 amount)
        external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract EthenaS06SequentialMintCapTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;
    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;
    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    uint256 constant PRIVATE_KEY = 1;
    bytes32 constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    IS06SequentialMint target = IS06SequentialMint(MINTING);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
    }

    function _seedAuthorization() internal {
        bytes32 member = bytes32(uint256(uint160(MINTER)));

        // EnumerableSet at slot 4:
        // _values array at slot 4, _indexes mapping at slot 5.
        vm.store(
            MINTING,
            bytes32(uint256(4)),
            bytes32(uint256(1))
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(uint256(4))),
            member
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(member, uint256(5))),
            bytes32(uint256(1))
        );

        // Mapping(address => EnumerableSet.AddressSet) at slot 6.
        uint256 setBase =
            uint256(keccak256(abi.encode(MINTER, uint256(6))));

        // Nested set: values array at setBase, indexes mapping at setBase + 1.
        vm.store(
            MINTING,
            bytes32(setBase),
            bytes32(uint256(1))
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(setBase)),
            member
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(member, setBase + 1)),
            bytes32(uint256(1))
        );

        // AccessControl: MINTER_ROLE membership.
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

    function _seedAssetMinted(uint128 value) internal {
        bytes32 outer = keccak256(abi.encode(block.number, uint256(14)));
        bytes32 slot = keccak256(abi.encode(USDC, outer));
        vm.store(MINTING, slot, bytes32(uint256(value)));

        (uint128 observed,) =
            target.totalPerBlockPerAsset(block.number, USDC);
        assertEq(observed, value, "asset counter seed mismatch");
    }

    function _seedGlobalMinted(uint128 value) internal {
        bytes32 slot = keccak256(abi.encode(block.number, uint256(13)));
        vm.store(MINTING, slot, bytes32(uint256(value)));

        (uint128 observed,) = target.totalPerBlock(block.number);
        assertEq(observed, value, "global counter seed mismatch");
    }

    function _order(uint128 collateral, uint128 usde, uint128 nonce)
        internal view returns (IS06SequentialMint.Order memory)
    {
        return IS06SequentialMint.Order({
            order_id: string.concat("S06-SEQUENTIAL-", vm.toString(nonce)),
            order_type: IS06SequentialMint.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: nonce,
            benefactor: MINTER,
            beneficiary: MINTER,
            collateral_asset: USDC,
            collateral_amount: collateral,
            usde_amount: usde
        });
    }

    function _route()
        internal pure returns (IS06SequentialMint.Route memory route)
    {
        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);
        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;
        route = IS06SequentialMint.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _sign(IS06SequentialMint.Order memory order)
        internal returns (IS06SequentialMint.Signature memory sig)
    {
        bytes32 digest = target.hashOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);
        sig = IS06SequentialMint.Signature({
            signature_type: IS06SequentialMint.SignatureType.EIP712,
            signature_bytes: abi.encodePacked(r, s, v)
        });
        assertEq(
            uint256(target.verifyOrder(order, sig)),
            uint256(digest),
            "order signature verification failed"
        );
    }

    function _attemptMint(IS06SequentialMint.Order memory order)
        internal returns (bool success, bytes memory data)
    {
        IS06SequentialMint.Route memory route = _route();
        assertTrue(target.verifyRoute(route), "route rejected");
        assertTrue(
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                USDC,
                order.order_type
            ),
            "stable-price guard rejected test order"
        );

        IS06SequentialMint.Signature memory sig = _sign(order);
        vm.prank(MINTER);
        (success, data) = MINTING.call(
            abi.encodeWithSelector(
                IS06SequentialMint.mint.selector,
                order,
                route,
                sig
            )
        );
    }

    function _assertCapError(bytes memory data) internal pure {
        assertGe(data.length, 4, "missing revert selector");
        bytes4 actual;
        assembly {
            actual := mload(add(data, 32))
        }

        bytes4 assetError = bytes4(keccak256("MaxMintPerBlockExceeded()"));
        bytes4 globalError = bytes4(keccak256("GlobalMaxMintPerBlockExceeded()"));
        assertTrue(
            actual == assetError || actual == globalError,
            "revert was not an expected cap error"
        );
    }

    function _readCounters()
        internal view
        returns (uint128 assetCount, uint128 globalCount)
    {
        (assetCount,) = target.totalPerBlockPerAsset(block.number, USDC);
        (globalCount,) = target.totalPerBlock(block.number);
    }

    function _assertCounters(
        uint128 expectedAsset,
        uint128 expectedGlobal,
        string memory reason
    ) internal view {
        (uint128 actualAsset, uint128 actualGlobal) = _readCounters();
        assertEq(actualAsset, expectedAsset, reason);
        assertEq(actualGlobal, expectedGlobal, reason);
    }

    function test_SequentialMintCountersAndOverCapRejection() external {
        _seedAuthorization();

        // Test-only balance and approval changes on the local fork.
        deal(USDC, MINTER, 10_000_000);

        vm.prank(MINTER);
        require(
            IERC20MintTest(USDC).approve(MINTING, type(uint256).max),
            "USDC approval failed"
        );

        assertGe(
            IERC20MintTest(USDC).balanceOf(MINTER),
            2_000_000,
            "MINTER lacks USDC for two boundary mints"
        );

        (, bool active, uint128 assetCap,) = target.tokenConfig(USDC);
        (uint128 globalCap,) = target.globalConfig();

        assertTrue(active, "USDC inactive");
        assertGt(assetCap, 0, "asset cap is zero");
        assertGt(globalCap, 0, "global cap is zero");

        uint128 effectiveCap = assetCap < globalCap ? assetCap : globalCap;
        uint128 unit = 1e18;

        assertGt(effectiveCap, 3 * unit, "cap too small for sequential test");

        uint128 starting = effectiveCap - 2 * unit;
        _seedAssetMinted(starting);
        _seedGlobalMinted(starting);

        (uint128 assetBefore, uint128 globalBefore) = _readCounters();

        IS06SequentialMint.Order memory first = _order(1e6, unit, 906201);
        (bool firstOk, bytes memory firstData) = _attemptMint(first);
        if (!firstOk) emit log_named_bytes("First mint revert", firstData);
        assertTrue(firstOk, "first boundary mint failed");

        _assertCounters(
            assetBefore + unit,
            globalBefore + unit,
            "counters incorrect after first mint"
        );

        IS06SequentialMint.Order memory second = _order(1e6, unit, 906202);
        (bool secondOk, bytes memory secondData) = _attemptMint(second);
        if (!secondOk) emit log_named_bytes("Second mint revert", secondData);
        assertTrue(secondOk, "second boundary mint failed");

        (uint128 assetAtCap, uint128 globalAtCap) = _readCounters();

        assertEq(
            assetAtCap,
            assetBefore + 2 * unit,
            "asset counter unexpected at boundary"
        );
        assertEq(
            globalAtCap,
            globalBefore + 2 * unit,
            "global counter unexpected at boundary"
        );

        IS06SequentialMint.Order memory third = _order(1e6, unit, 906203);
        (bool thirdOk, bytes memory thirdData) = _attemptMint(third);

        assertFalse(thirdOk, "third mint unexpectedly passed cap");
        _assertCapError(thirdData);

        _assertCounters(
            assetAtCap,
            globalAtCap,
            "counter changed after failed mint"
        );

        uint256 nextBlock = block.number + 1;
        vm.roll(nextBlock);

        (uint128 nextGlobal,) = target.totalPerBlock(nextBlock);
        (uint128 nextAsset,) =
            target.totalPerBlockPerAsset(nextBlock, USDC);

        assertEq(nextGlobal, 0, "global counter not zero in next block");
        assertEq(nextAsset, 0, "asset counter not zero in next block");
    }
}
