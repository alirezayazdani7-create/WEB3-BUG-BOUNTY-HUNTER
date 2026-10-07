// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEthenaMinting {
    function usde() external view returns (address);

    function verifyNonce(
        address sender,
        uint128 nonce
    ) external view returns (bool);

    function verifyRoute(
        address[] calldata custodians,
        uint256[] calldata ratios
    ) external view returns (bool);
}

contract MintingV2TransitionTest {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    IEthenaMinting target =
        IEthenaMinting(MINTING);

    function assertTrue(
        bool value,
        string memory reason
    ) internal pure {
        require(value, reason);
    }

    function assertEq(
        address a,
        address b,
        string memory reason
    ) internal pure {
        require(a == b, reason);
    }

    function test_P01_usde_binding()
        external
    {
        address configured =
            target.usde();

        assertEq(
            configured,
            USDE,
            "USDe binding mismatch"
        );
    }

    /*
     * verifyNonce() can revert when a nonce is invalid.
     *
     * Here we use two fresh addresses/nonces and record that
     * both calls complete successfully.
     *
     * This is an observation only and is NOT a vulnerability claim.
     */
    function test_P02_nonce_boundary()
        external
    {
        address sender =
            address(0x1111);

        (bool okA,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyNonce.selector,
                    sender,
                    uint128(0x1234)
                )
            );

        (bool okB,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyNonce.selector,
                    sender,
                    uint128(
                        uint256(0x1234)
                        + (uint256(1) << 64)
                    )
                )
            );

        assertTrue(
            okA,
            "first nonce verification reverted"
        );

        assertTrue(
            okB,
            "second nonce verification reverted"
        );
    }

    /*
     * verifyRoute() reverts for an invalid route.
     * Therefore the correct test is to assert that the
     * low-level call fails.
     */
    function test_P03_non_custodian_route_rejected()
        external
    {
        address[] memory custodians =
            new address[](2);

        uint256[] memory ratios =
            new uint256[](2);

        custodians[0] = address(1);
        custodians[1] = address(2);

        ratios[0] = 5000;
        ratios[1] = 5000;

        (bool ok,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyRoute.selector,
                    custodians,
                    ratios
                )
            );

        assertTrue(
            !ok,
            "non-custodian route was accepted"
        );
    }

    function test_P04_empty_route_rejected()
        external
    {
        address[] memory custodians =
            new address[](0);

        uint256[] memory ratios =
            new uint256[](0);

        (bool ok,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyRoute.selector,
                    custodians,
                    ratios
                )
            );

        assertTrue(
            !ok,
            "empty route was accepted"
        );
    }

    function test_P05_length_mismatch_rejected()
        external
    {
        address[] memory custodians =
            new address[](2);

        uint256[] memory ratios =
            new uint256[](1);

        custodians[0] = address(1);
        custodians[1] = address(2);

        ratios[0] = 10000;

        (bool ok,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyRoute.selector,
                    custodians,
                    ratios
                )
            );

        assertTrue(
            !ok,
            "length mismatch was accepted"
        );
    }

    function test_P06_zero_ratio_rejected()
        external
    {
        address[] memory custodians =
            new address[](2);

        uint256[] memory ratios =
            new uint256[](2);

        custodians[0] = address(1);
        custodians[1] = address(2);

        ratios[0] = 10000;
        ratios[1] = 0;

        (bool ok,) =
            address(target).staticcall(
                abi.encodeWithSelector(
                    IEthenaMinting.verifyRoute.selector,
                    custodians,
                    ratios
                )
            );

        assertTrue(
            !ok,
            "zero-ratio route was accepted"
        );
    }
}
