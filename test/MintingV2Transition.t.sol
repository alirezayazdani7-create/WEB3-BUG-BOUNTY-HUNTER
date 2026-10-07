// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function log_string(string calldata message) external;
}

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
    Vm constant vm =
        Vm(
            address(
                uint160(
                    uint256(
                        keccak256("hevm cheat code")
                    )
                )
            )
        );

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
        address configured = target.usde();

        assertEq(
            configured,
            USDE,
            "USDe binding mismatch"
        );

        vm.log_string(
            "P01_USDE_BINDING=PASS"
        );
    }

    function test_P02_nonce_collision_property()
        external
    {
        address sender =
            address(0x1111);

        uint128 nonceA =
            uint128(0x1234);

        uint128 nonceB =
            uint128(
                uint256(0x1234)
                + (uint256(1) << 64)
            );

        bool first =
            target.verifyNonce(
                sender,
                nonceA
            );

        bool second =
            target.verifyNonce(
                sender,
                nonceB
            );

        assertTrue(
            first == second,
            "nonce property changed unexpectedly"
        );

        vm.log_string(
            "P02_NONCE_COLLISION_PROPERTY=OBSERVED"
        );
    }

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

        bool valid =
            target.verifyRoute(
                custodians,
                ratios
            );

        assertTrue(
            !valid,
            "non-custodian route accepted"
        );

        vm.log_string(
            "P03_NON_CUSTODIAN_ROUTE_REJECTED=PASS"
        );
    }

    function test_P04_empty_route_rejected()
        external
    {
        address[] memory custodians =
            new address[](0);

        uint256[] memory ratios =
            new uint256[](0);

        bool valid =
            target.verifyRoute(
                custodians,
                ratios
            );

        assertTrue(
            !valid,
            "empty route accepted"
        );

        vm.log_string(
            "P04_EMPTY_ROUTE_REJECTED=PASS"
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

        bool valid =
            target.verifyRoute(
                custodians,
                ratios
            );

        assertTrue(
            !valid,
            "length mismatch accepted"
        );

        vm.log_string(
            "P05_ROUTE_LENGTH_MISMATCH_REJECTED=PASS"
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

        bool valid =
            target.verifyRoute(
                custodians,
                ratios
            );

        assertTrue(
            !valid,
            "zero ratio accepted"
        );

        vm.log_string(
            "P06_ZERO_RATIO_REJECTED=PASS"
        );
    }
}
