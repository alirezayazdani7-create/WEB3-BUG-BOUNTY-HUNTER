
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IEthenaS06MintCapProbe {
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

    function tokenConfig(address asset)
        external view returns (uint8, bool, uint128, uint128);

    function globalConfig()
        external view returns (uint128, uint128);

    function hashOrder(Order calldata order)
        external view returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    ) external view returns (bytes32);

    function verifyRoute(Route calldata route)
        external view returns (bool);

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

    function isWhitelistedBenefactor(address benefactor)
        external view returns (bool);

    function isApprovedBeneficiary(
        address benefactor,
        address beneficiary
    ) external view returns (bool);
}

contract EthenaS06USDCMintCapEnforcementTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    uint256 constant TEST_PRIVATE_KEY = 1;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    IEthenaS06MintCapProbe target =
        IEthenaS06MintCapProbe(MINTING);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
    }

    // Local-fork storage setup only.
    // Do not interpret this as proof of the deployed storage layout.
    function _seedLocalWhitelistAndApproval() internal {
        bytes32 member = bytes32(uint256(uint160(MINTER)));

        // Assumed EnumerableSet storage slots; assertions below
        // must validate these assumptions before the mint probe.
        bytes32 whitelistData =
            keccak256(abi.encode(uint256(4)));

        bytes32 whitelistIndex =
            keccak256(abi.encode(member, uint256(5)));

        vm.store(
            MINTING,
            bytes32(uint256(4)),
            bytes32(uint256(1))
        );
        vm.store(MINTING, whitelistData, member);
        vm.store(MINTING, whitelistIndex, bytes32(uint256(1)));

        uint256 setBase =
            uint256(keccak256(abi.encode(MINTER, uint256(6))));

        bytes32 approvedData =
            keccak256(abi.encode(setBase));

        bytes32 approvedIndex =
            keccak256(abi.encode(member, setBase + 1));

        vm.store(
            MINTING,
            bytes32(setBase),
            bytes32(uint256(1))
        );
        vm.store(MINTING, approvedData, member);
        vm.store(MINTING, approvedIndex, bytes32(uint256(1)));

        assertTrue(
            target.isWhitelistedBenefactor(MINTER),
            "Local setup: benefactor not whitelisted"
        );

        assertTrue(
            target.isApprovedBeneficiary(MINTER, MINTER),
            "Local setup: beneficiary not approved"
        );
    }

    function _buildOrder(uint128 amount, uint128 usdeAmount)
        internal view
        returns (IEthenaS06MintCapProbe.Order memory order)
    {
        order = IEthenaS06MintCapProbe.Order({
            order_id: "S06-CAP-ENFORCEMENT-LOCAL",
            order_type: IEthenaS06MintCapProbe.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: 906001,
            benefactor: MINTER,
            beneficiary: MINTER,
            collateral_asset: USDC,
            collateral_amount: amount,
            usde_amount: usdeAmount
        });
    }

    function _buildRoute()
        internal pure
        returns (IEthenaS06MintCapProbe.Route memory route)
    {
        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        route = IEthenaS06MintCapProbe.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _sign(IEthenaS06MintCapProbe.Order memory order)
        internal
        returns (
            IEthenaS06MintCapProbe.Signature memory sig,
            bytes32 digest
        )
    {
        digest = target.hashOrder(order);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(TEST_PRIVATE_KEY, digest);

        sig = IEthenaS06MintCapProbe.Signature({
            signature_type:
                IEthenaS06MintCapProbe.SignatureType.EIP712,
            signature_bytes: abi.encodePacked(r, s, v)
        });
    }

    function test_RejectsMintAboveAssetAndGlobalCap() public {
        _seedLocalWhitelistAndApproval();

        (, bool active, uint128 assetMintCap,) =
            target.tokenConfig(USDC);

        (uint128 globalMintCap,) = target.globalConfig();

        assertTrue(active, "USDC inactive");
        assertGt(assetMintCap, 0, "Asset cap is zero");
        assertGt(globalMintCap, 0, "Global cap is zero");

        uint256 effectiveCap = assetMintCap < globalMintCap
            ? assetMintCap
            : globalMintCap;

        uint256 amount = effectiveCap + 1;

        require(amount <= type(uint128).max, "Cap too large");

        // USDC has 6 decimals; USDe has 18 decimals.
        uint256 usdeAmount = amount * 1e12;

        require(
            usdeAmount <= type(uint128).max,
            "USDe amount too large"
        );

        IEthenaS06MintCapProbe.Order memory order =
            _buildOrder(uint128(amount), uint128(usdeAmount));

        IEthenaS06MintCapProbe.Route memory route = _buildRoute();

        assertTrue(target.verifyRoute(route), "Route rejected");

        assertTrue(
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                USDC,
                order.order_type
            ),
            "Stable-price guard rejected probe"
        );

        (
            IEthenaS06MintCapProbe.Signature memory sig,
            bytes32 digest
        ) = _sign(order);

        assertEq(
            uint256(target.verifyOrder(order, sig)),
            uint256(digest),
            "Order signature verification mismatch"
        );

        emit log_named_uint("Asset mint cap", assetMintCap);
        emit log_named_uint("Global mint cap", globalMintCap);
        emit log_named_uint("Probe collateral amount", amount);

        // This call is executed on the local fork simulation only.
        vm.prank(MINTER);

        (bool success, bytes memory revertData) = MINTING.call(
            abi.encodeWithSelector(
                IEthenaS06MintCapProbe.mint.selector,
                order,
                route,
                sig
            )
        );

        emit log_named_uint("Mint call succeeded", success ? 1 : 0);
        emit log_named_bytes("Mint revert data", revertData);

        assertFalse(
            success,
            "Mint accepted an order above the effective cap"
        );

        assertGe(
            revertData.length,
            4,
            "Missing revert selector"
        );

        bytes4 actualError;

        assembly {
            actualError := mload(add(revertData, 32))
        }

        bytes4 assetCapError =
            bytes4(keccak256("MaxMintPerBlockExceeded()"));

        bytes4 globalCapError =
            bytes4(keccak256("GlobalMaxMintPerBlockExceeded()"));

        assertTrue(
            actualError == assetCapError ||
            actualError == globalCapError,
            "Mint reverted for a reason other than a mint cap"
        );

        emit log_named_bytes32(
            "Confirmed cap error selector",
            bytes32(actualError)
        );
    }
}
