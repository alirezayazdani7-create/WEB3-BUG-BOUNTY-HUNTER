// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function prank(address msgSender) external;
}

interface IERC1271P17 {
    function isValidSignature(
        bytes32 hash,
        bytes calldata signature
    ) external view returns (bytes4);
}

interface IEthenaMintingP17 {
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

    struct Signature {
        SignatureType signature_type;
        bytes signature_bytes;
    }

    function owner() external view returns (address);

    function addWhitelistedBenefactor(address benefactor) external;

    function hashOrder(Order calldata order)
        external
        view
        returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    ) external view returns (bytes32);
}

contract P17Valid1271Wallet is IERC1271P17 {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant FAILVALUE = 0xffffffff;

    bytes32 public approvedDigest;

    function setApprovedDigest(bytes32 digest) external {
        approvedDigest = digest;
    }

    function isValidSignature(
        bytes32 hash,
        bytes calldata
    ) external view returns (bytes4) {
        if (hash == approvedDigest) {
            return MAGICVALUE;
        }

        return FAILVALUE;
    }
}

contract P17Wrong1271Wallet is IERC1271P17 {
    function isValidSignature(
        bytes32,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xffffffff;
    }
}

contract MintingV2P17EIP1271BoundaryTest {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    Vm constant vm =
        Vm(address(uint160(uint256(
            keccak256("hevm cheat code")
        ))));

    IEthenaMintingP17 constant target =
        IEthenaMintingP17(MINTING);

    function assertTrue(
        bool value,
        string memory reason
    ) internal pure {
        require(value, reason);
    }

    function _baseOrder(address benefactor)
        internal
        view
        returns (IEthenaMintingP17.Order memory o)
    {
        o = IEthenaMintingP17.Order({
            order_id: "P17-1271",
            order_type: IEthenaMintingP17.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: 17001001,
            benefactor: benefactor,
            beneficiary: benefactor,
            collateral_asset: USDC,
            collateral_amount: 999_900_001,
            usde_amount: 1_000e18
        });
    }

    function _authorizeBenefactor(address benefactor) internal {
        address owner = target.owner();

        vm.prank(owner);
        target.addWhitelistedBenefactor(benefactor);
    }

    function _eip1271Signature()
        internal
        pure
        returns (IEthenaMintingP17.Signature memory sig)
    {
        sig = IEthenaMintingP17.Signature({
            signature_type:
                IEthenaMintingP17.SignatureType.EIP1271,
            signature_bytes: hex"5031372d54455354"
        });
    }

    function _accepts(
        IEthenaMintingP17.Order memory order,
        IEthenaMintingP17.Signature memory sig
    ) internal view returns (bool) {
        (bool ok,) = MINTING.staticcall(
            abi.encodeWithSelector(
                target.verifyOrder.selector,
                order,
                sig
            )
        );

        return ok;
    }

    function test_P17_valid_eip1271_signature_is_accepted()
        external
    {
        P17Valid1271Wallet wallet =
            new P17Valid1271Wallet();

        _authorizeBenefactor(address(wallet));

        IEthenaMintingP17.Order memory order =
            _baseOrder(address(wallet));

        bytes32 digest =
            target.hashOrder(order);

        wallet.setApprovedDigest(digest);

        IEthenaMintingP17.Signature memory sig =
            _eip1271Signature();

        assertTrue(
            _accepts(order, sig),
            "valid EIP1271 signature rejected"
        );
    }

    function test_P17_eip1271_signature_is_order_bound()
        external
    {
        P17Valid1271Wallet wallet =
            new P17Valid1271Wallet();

        _authorizeBenefactor(address(wallet));

        IEthenaMintingP17.Order memory original =
            _baseOrder(address(wallet));

        wallet.setApprovedDigest(
            target.hashOrder(original)
        );

        IEthenaMintingP17.Signature memory sig =
            _eip1271Signature();

        assertTrue(
            _accepts(original, sig),
            "baseline EIP1271 authorization rejected"
        );

        IEthenaMintingP17.Order memory mutated;

        mutated = original;
        mutated.collateral_amount =
            original.collateral_amount - 99_999;

        assertTrue(
            !_accepts(mutated, sig),
            "EIP1271 accepted mutated collateral amount"
        );

        mutated = original;
        mutated.usde_amount =
            original.usde_amount + 1;

        assertTrue(
            !_accepts(mutated, sig),
            "EIP1271 accepted mutated USDe amount"
        );

        mutated = original;
        mutated.beneficiary =
            address(0xbeef);

        assertTrue(
            !_accepts(mutated, sig),
            "EIP1271 accepted mutated beneficiary"
        );

        mutated = original;
        mutated.nonce =
            original.nonce + 1;

        assertTrue(
            !_accepts(mutated, sig),
            "EIP1271 accepted mutated nonce"
        );
    }

    function test_P17_wrong_eip1271_magic_is_rejected()
        external
    {
        P17Wrong1271Wallet wallet =
            new P17Wrong1271Wallet();

        _authorizeBenefactor(address(wallet));

        IEthenaMintingP17.Order memory order =
            _baseOrder(address(wallet));

        IEthenaMintingP17.Signature memory sig =
            _eip1271Signature();

        assertTrue(
            !_accepts(order, sig),
            "wrong ERC1271 magic value was accepted"
        );
    }
}
