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
        external view
        returns (uint8, bool, uint128, uint128);

    function globalConfig()
        external view
        returns (uint128, uint128);

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

    function test_RejectsMintAboveAssetAndGlobalCap() public {
        (
            uint8 tokenType,
            bool active,
            uint128 assetMintCap,
        ) = target.tokenConfig(USDC);

        (uint128 globalMintCap,) = target.globalConfig();

        assertTrue(active, "USDC inactive");
        assertGt(assetMintCap, 0, "Asset cap is zero");
        assertGt(globalMintCap, 0, "Global cap is zero");

        uint256 effectiveCap =
            assetMintCap < globalMintCap
                ? assetMintCap
                : globalMintCap;

        uint256 amount = effectiveCap + 1;

        require(amount <= type(uint128).max, "Cap too large");

        // USDC's six decimals versus USDe's 18 decimals.
        uint256 usdeAmount = amount * 1e12;
        require(usdeAmount <= type(uint128).max, "USDe amount too large");

        IEthenaS06MintCapProbe.Order memory order =
            IEthenaS06MintCapProbe.Order({
                order_id: "S06-CAP-ENFORCEMENT",
                order_type: IEthenaS06MintCapProbe.OrderType.MINT,
                expiry: uint120(block.timestamp + 1 days),
                nonce: 906001,
                benefactor: MINTER,
                beneficiary: MINTER,
                collateral_asset: USDC,
                collateral_amount: uint128(amount),
                usde_amount: uint128(usdeAmount)
            });

        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);
        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        IEthenaS06MintCapProbe.Route memory route =
            IEthenaS06MintCapProbe.Route({
                addresses: addresses,
                ratios: ratios
            });

        assertTrue(target.verifyRoute(route), "Route rejected");

        assertTrue(
            target.verifyStablesLimit(
                order.collateral_amount,
                order.usde_amount,
                USDC,
                order.order_type
            ),
            "Stable-price guard rejected probe before cap test"
        );

        bytes32 digest = target.hashOrder(order);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(TEST_PRIVATE_KEY, digest);

        IEthenaS06MintCapProbe.Signature memory sig =
            IEthenaS06MintCapProbe.Signature({
                signature_type:
                    IEthenaS06MintCapProbe.SignatureType.EIP712,
                signature_bytes: abi.encodePacked(r, s, v)
            });

        assertEq(
            uint256(target.verifyOrder(order, sig)),
            uint256(digest),
            "Order signature verification mismatch"
        );

        emit log_named_uint("USDC token type", tokenType);
        emit log_named_uint("Asset mint cap", assetMintCap);
        emit log_named_uint("Global mint cap", globalMintCap);
        emit log_named_uint("Probe collateral amount", amount);

        // Local fork only. No Mainnet transaction is sent.
        vm.prank(MINTER);
        (bool success, bytes memory revertData) =
            MINTING.call(
                abi.encodeWithSelector(
                    IEthenaS06MintCapProbe.mint.selector,
                    order,
                    route,
                    sig
                )
            );

        emit log_named_uint("Mint call succeeded", success ? 1 : 0);
        emit log_named_uint("Revert data length", revertData.length);

        assertFalse(
            success,
            "Mint accepted an order above the effective cap"
        );
    }
}
