// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20Minimal {
    function approve(address spender, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}

interface IS06SequentialMint {
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

        // Local fork only: whitelist setup.
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

        // Local fork only: approved beneficiary setup.
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
            member
        );

        vm.store(
            MINTING,
            keccak256(abi.encode(member, setBase + 1)),
            bytes32(uint256(1))
        );

        // Local fork only: role setup.
        // The _roles slot assumption must be verified against source.
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

    function _fundMinterAndApprove() internal {
        // Test-only funding on the local fork.
        deal(USDC, MINTER, 3e6);

        vm.prank(MINTER);
        bool approved =
            IERC20Minimal(USDC).approve(MINTING, type(uint256).max);

        assertTrue(approved, "USDC approval failed");

        assertGe(
            IERC20Minimal(USDC).allowance(MINTER, MINTING),
            3e6,
            "allowance too small"
        );
    }

    function _seedAssetMinted(uint128 value) internal {
        // Assumes the asset counter mapping is rooted at slot 14.
        bytes32 outer =
            keccak256(abi.encode(block.number, uint256(14)));

        bytes32 slot =
            keccak256(abi.encode(USDC, outer));

        vm.store(
            MINTING,
            slot,
            bytes32(uint256(value))
        );

        (uint128 observed,) =
            target.totalPerBlockPerAsset(block.number, USDC);

        assertEq(
            observed,
            value,
            "asset counter seed mismatch"
        );
    }

    function _seedGlobalMinted(uint128 value) internal {
        // Assumes the global counter mapping is rooted at slot 13.
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
        uint128 collateral,
        uint128 usde,
        uint128 nonce
    ) internal view returns (IS06SequentialMint.Order memory) {
        return IS06SequentialMint.Order({
            order_id: string.concat(
                "S06-SEQUENTIAL-",
                vm.toString(nonce)
            ),
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
        internal
        pure
        returns (IS06SequentialMint.Route memory route)
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

    function _sign(
        IS06SequentialMint.Order memory order
    ) internal returns (IS06SequentialMint.Signature memory sig) {
        bytes32 digest = target.hashOrder(order);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PRIVATE_KEY, digest);

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

    function _attemptMint(
        IS06SequentialMint.Order memory order
    ) internal returns (bool success, bytes memory data) {
        IS06SequentialMint.Route memory route = _route();

        assertTrue(
            target.verifyRoute(route),
            "route rejected"
        );

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
        assertGe(
            data.length,
            4,
            "missing revert selector"
        );

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
    }

    function test_SequentialMintCountersAndOverCapRejection()
        external
    {
        _seedAuthorization();
        _fundMinterAndApprove();

        (, bool active, uint128 assetCap,) =
            target.tokenConfig(USDC);

        (uint128 globalCap,) = target.globalConfig();

        assertTrue(active, "USDC inactive");
        assertGt(assetCap, 0, "asset cap is zero");
        assertGt(globalCap, 0, "global cap is zero");

        uint128 effectiveCap =
            assetCap < globalCap ? assetCap : globalCap;

        uint128 unit = 1e18;

        assertGt(
            effectiveCap,
            3 * unit,
            "cap too small for sequential test"
        );

        // Seed the counters immediately below the cap.
        // This is a controlled local-fork boundary test,
        // not a from-zero accumulation test.
        uint128 starting = effectiveCap - 2 * unit;

        _seedAssetMinted(starting);
        _seedGlobalMinted(starting);

        (uint128 assetBefore,) =
            target.totalPerBlockPerAsset(block.number, USDC);

        (uint128 globalBefore,) =
            target.totalPerBlock(block.number);

        IS06SequentialMint.Order memory first =
            _order(1e6, unit, 906201);

        (bool firstOk, bytes memory firstData) =
            _attemptMint(first);

        if (!firstOk) {
            emit log_named_bytes("First mint revert", firstData);
        }

        assertTrue(firstOk, "first boundary mint failed");

        (uint128 assetAfterFirst,) =
            target.totalPerBlockPerAsset(block.number, USDC);

        (uint128 globalAfterFirst,) =
            target.totalPerBlock(block.number);

        assertEq(
            uint256(assetAfterFirst),
            uint256(assetBefore) + unit,
            "asset counter did not increase after first mint"
        );

        assertEq(
            uint256(globalAfterFirst),
            uint256(globalBefore) + unit,
            "global counter did not increase after first mint"
        );

        IS06SequentialMint.Order memory second =
            _order(1e6, unit, 906202);

        (bool secondOk, bytes memory secondData) =
            _attemptMint(second);

        if (!secondOk) {
            emit log_named_bytes("Second mint revert", secondData);
        }

        assertTrue(secondOk, "second boundary mint failed");

        (uint128 assetAtCap,) =
            target.totalPerBlockPerAsset(block.number, USDC);

        (uint128 globalAtCap,) =
            target.totalPerBlock(block.number);

        assertEq(
            uint256(assetAtCap),
            uint256(effectiveCap),
            "asset counter unexpected at boundary"
        );

        assertEq(
            uint256(globalAtCap),
            uint256(effectiveCap),
            "global counter unexpected at boundary"
        );

        IS06SequentialMint.Order memory third =
            _order(1e6, unit, 906203);

        (bool thirdOk, bytes memory thirdData) =
            _attemptMint(third);

        assertFalse(
            thirdOk,
            "third mint unexpectedly passed cap"
        );

        _assertCapError(thirdData);

        // Failed mint must not change either counter.
        (uint128 assetAfterFailure,) =
            target.totalPerBlockPerAsset(block.number, USDC);

        (uint128 globalAfterFailure,) =
            target.totalPerBlock(block.number);

        assertEq(
            assetAfterFailure,
            assetAtCap,
            "asset counter changed on failed mint"
        );

        assertEq(
            globalAfterFailure,
            globalAtCap,
            "global counter changed on failed mint"
        );

        // The following block should have independent counters.
        uint256 nextBlock = block.number + 1;
        vm.roll(nextBlock);

        (uint128 nextGlobal,) =
            target.totalPerBlock(nextBlock);

        (uint128 nextAsset,) =
            target.totalPerBlockPerAsset(nextBlock, USDC);

        assertEq(
            nextGlobal,
            0,
            "global counter not zero in next block"
        );

        assertEq(
            nextAsset,
            0,
            "asset counter not zero in next block"
        );
    }
}
