// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEthenaMinting {
    struct Route {
        address[] addresses;
        uint128[] ratios;
    }

    function usde() external view returns (address);

    function verifyNonce(address sender, uint128 nonce)
        external
        view
        returns (uint128, uint256, uint256);

    function verifyRoute(Route calldata route)
        external
        view
        returns (bool);

    function verifyStablesLimit(
        uint128 collateralAmount,
        uint128 usdeAmount,
        address collateralAsset,
        uint8 orderType
    ) external view returns (bool);

    function tokenConfig(address asset)
        external
        view
        returns (
            uint8 tokenType,
            bool isActive,
            uint128 maxMintPerBlock,
            uint128 maxRedeemPerBlock
        );

    function isSupportedAsset(address asset) external view returns (bool);

    function stablesDeltaLimit() external view returns (uint128);
}

contract MintingV2TransitionTest {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    event BoundaryResult(
        string testName,
        uint128 collateralAmount,
        uint128 usdeAmount,
        uint8 orderType,
        bool accepted
    );

    event DeltaLimitObserved(uint128 deltaLimit);

    event RouteResult(
        string testName,
        bool callSucceeded,
        bool accepted
    );

    IEthenaMinting target = IEthenaMinting(MINTING);

    function assertTrue(bool value, string memory reason)
        internal
        pure
    {
        require(value, reason);
    }

    function assertEq(
        address a,
        address b,
        string memory reason
    ) internal pure {
        require(a == b, reason);
    }

    function test_P01_usde_binding() external {
        assertEq(
            target.usde(),
            USDE,
            "USDe binding mismatch"
        );
    }

    function test_P02_nonce_boundary() external {
        address sender = address(0x1111);

        (
            uint128 slotA,
            uint256 invalidatorA,
            uint256 bitA
        ) = target.verifyNonce(
            sender,
            uint128(0x1234)
        );

        (
            uint128 slotB,
            uint256 invalidatorB,
            uint256 bitB
        ) = target.verifyNonce(
            sender,
            uint128(
                uint256(0x1234) + (uint256(1) << 64)
            )
        );

        assertTrue(
            slotA == slotB,
            "expected nonce slot collision not observed"
        );

        assertTrue(
            bitA == bitB,
            "expected nonce bit collision not observed"
        );

        assertTrue(
            invalidatorA == invalidatorB,
            "unexpected bitmap state difference"
        );
    }

    function test_P03_non_custodian_route_rejected()
        external
    {
        address[] memory addresses =
            new address[](2);

        uint128[] memory ratios =
            new uint128[](2);

        addresses[0] = address(1);
        addresses[1] = address(2);

        ratios[0] = 5000;
        ratios[1] = 5000;

        IEthenaMinting.Route memory route =
            IEthenaMinting.Route({
                addresses: addresses,
                ratios: ratios
            });

        (
            bool ok,
            bytes memory data
        ) = address(target).staticcall(
            abi.encodeWithSelector(
                IEthenaMinting.verifyRoute.selector,
                route
            )
        );

        bool accepted = false;

        if (ok && data.length >= 32) {
            accepted = abi.decode(data, (bool));
        }

        emit RouteResult(
            "P03_NON_CUSTODIAN_ROUTE",
            ok,
            accepted
        );

        assertTrue(
            !accepted,
            "non-custodian route accepted"
        );
    }

    function test_P04_empty_route_rejected()
        external
    {
        address[] memory addresses =
            new address[](0);

        uint128[] memory ratios =
            new uint128[](0);

        IEthenaMinting.Route memory route =
            IEthenaMinting.Route({
                addresses: addresses,
                ratios: ratios
            });

        (
            bool ok,
            bytes memory data
        ) = address(target).staticcall(
            abi.encodeWithSelector(
                IEthenaMinting.verifyRoute.selector,
                route
            )
        );

        bool
