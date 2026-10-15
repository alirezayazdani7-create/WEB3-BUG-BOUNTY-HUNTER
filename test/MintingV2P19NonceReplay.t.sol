
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface VmP19 {
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;

    function store(
        address target,
        bytes32 slot,
        bytes32 value
    ) external;

    function expectRevert(bytes4 revertData) external;
}

interface IERC20P19Full {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IEthenaMintingP19Full {
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

    function owner() external view returns (address);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function addWhitelistedBenefactor(address benefactor) external;
    function hashOrder(Order calldata order) external view returns (bytes32);
    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    ) external view returns (bytes32);

    // Correct parameter and return types for the verifyNonce selector.
    function verifyNonce(address sender, uint128 nonce)
        external
        view
        returns (uint128, uint256, uint256);

    function mint(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    ) external;
}

contract P19CollisionWallet {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant FAILVALUE = 0xffffffff;

    bytes32 public approvedDigest;

    function setApprovedDigest(bytes32 digest) external {
        approvedDigest = digest;
    }

    function execute(address target, bytes calldata data)
        external
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = target.call(data);
        require(ok, "wallet execute failed");
        return ret;
    }

    function isValidSignature(bytes32 hash, bytes calldata)
        external
        view
        returns (bytes4)
    {
        return hash == approvedDigest ? MAGICVALUE : FAILVALUE;
    }
}

contract MintingV2P19NonceCollisionTest {
    address internal constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address internal constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address internal constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    address internal constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    VmP19 internal constant vm = VmP19(
        address(uint160(uint256(keccak256("hevm cheat code"))))
    );

    IEthenaMintingP19Full internal constant target =
        IEthenaMintingP19Full(MINTING);

    IERC20P19Full internal constant usdc = IERC20P19Full(USDC);

    function _assert(bool condition, string memory reason) internal pure {
        require(condition, reason);
    }

    function _assertEq(uint256 a, uint256 b, string memory reason)
        internal
        pure
    {
        require(a == b, reason);
    }

    function _authorize(address wallet) internal {
        vm.prank(target.owner());
        target.addWhitelistedBenefactor(wallet);
    }

    function _fundAndApprove(P19CollisionWallet wallet, uint256 amount)
        internal
    {
        // Confirm the USDC storage layout before using this in another fork.
        bytes32 slot = keccak256(abi.encode(address(wallet), uint256(9)));
        vm.store(USDC, slot, bytes32(amount));

        _assertEq(
            usdc.balanceOf(address(wallet)),
            amount,
            "wallet funding failed; USDC storage layout may differ"
        );

        wallet.execute(
            USDC,
            abi.encodeWithSelector(
                IERC20P19Full.approve.selector,
                MINTING,
                type(uint256).max
            )
        );
    }

    function _order(
        address wallet,
        uint128 nonce,
        string memory orderId,
        uint128 collateral,
        uint128 usdeAmount
    ) internal view returns (IEthenaMintingP19Full.Order memory o) {
        o = IEthenaMintingP19Full.Order({
            order_id: orderId,
            order_type: IEthenaMintingP19Full.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: nonce,
            benefactor: wallet,
            beneficiary: wallet,
            collateral_asset: USDC,
            collateral_amount: collateral,
            usde_amount: usdeAmount
        });
    }

    function _route()
        internal
        pure
        returns (IEthenaMintingP19Full.Route memory r)
    {
        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        r = IEthenaMintingP19Full.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _sig()
        internal
        pure
        returns (IEthenaMintingP19Full.Signature memory s)
    {
        s = IEthenaMintingP19Full.Signature({
            signature_type: IEthenaMintingP19Full.SignatureType.EIP1271,
            signature_bytes: hex"5031392d434f4c4c4953494f4e"
        });
    }

    function _nonceAvailable(address sender, uint128 nonce)
        internal
        view
        returns (bool)
    {
        (bool ok,) = MINTING.staticcall(
            abi.encodeWithSelector(
                target.verifyNonce.selector,
                sender,
                nonce
            )
        );
        return ok;
    }

    function test_distinctHighBitNonceCollisionBlocksSecondOrder() external {
        P19CollisionWallet wallet = new P19CollisionWallet();
        _authorize(address(wallet));

        uint128 firstNonce = 19_001_003;
        uint128 secondNonce =
            uint128(uint256(firstNonce) + (uint256(1) << 64));

        uint128 collateral = 999_900_001;
        uint128 usdeAmount = uint128(1_000e18);

        _fundAndApprove(address(wallet) == address(0) ? wallet : wallet, uint256(collateral) * 2);

        IEthenaMintingP19Full.Order memory first = _order(
            address(wallet),
            firstNonce,
            "P19-COLLISION-FIRST",
            collateral,
            usdeAmount
        );

        IEthenaMintingP19Full.Order memory second = _order(
            address(wallet),
            secondNonce,
            "P19-COLLISION-SECOND",
            collateral,
            usdeAmount
        );

        IEthenaMintingP19Full.Route memory route = _route();
        IEthenaMintingP19Full.Signature memory sig = _sig();

        (uint128 slotA,, uint256 bitA) =
            target.verifyNonce(address(wallet), firstNonce);

        (uint128 slotB,, uint256 bitB) =
            target.verifyNonce(address(wallet), secondNonce);

        _assertEq(slotA, slotB, "nonce slots do not collide");
        _assertEq(bitA, bitB, "nonce bits do not collide");

        wallet.setApprovedDigest(target.hashOrder(first));
        target.verifyOrder(first, sig);

        vm.startPrank(MINTER);
        target.mint(first, route, sig);
        vm.stopPrank();

        uint256 balanceAfterFirst = usdc.balanceOf(address(wallet));

        _assertEq(
            balanceAfterFirst,
            collateral,
            "first mint collateral balance mismatch"
        );

        wallet.setApprovedDigest(target.hashOrder(second));

        _assert(
            !_nonceAvailable(address(wallet), secondNonce),
            "second nonce remains available after first mint"
        );

        vm.expectRevert(bytes4(keccak256("InvalidNonce()")));

        vm.startPrank(MINTER);
        target.mint(second, route, sig);
        vm.stopPrank();

        _assertEq(
            usdc.balanceOf(address(wallet)),
            balanceAfterFirst,
            "second order changed collateral balance"
        );
    }
}
