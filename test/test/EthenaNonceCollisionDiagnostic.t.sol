// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEthenaNonceProbe {
    function verifyNonce(
        address sender,
        uint128 nonce
    )
        external
        view
        returns (
            uint128 slot,
            uint256 invalidator,
            uint256 bit
        );
}

contract EthenaNonceCollisionDiagnostic {
    address internal constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address internal constant SENDER = address(0x1111);

    IEthenaNonceProbe internal constant target =
        IEthenaNonceProbe(MINTING);

    function test_high64BitCollisionDiagnostic() external view {
        uint128 a = uint128(0x1234);
        uint128 b = uint128(uint256(a) + (uint256(1) << 64));

        (uint128 slotA, uint256 invA, uint256 bitA) =
            target.verifyNonce(SENDER, a);

        (uint128 slotB, uint256 invB, uint256 bitB) =
            target.verifyNonce(SENDER, b);

        require(
            slotA == slotB,
            "EXPECTED_COLLISION_NOT_OBSERVED: slot"
        );

        require(
            bitA == bitB,
            "EXPECTED_COLLISION_NOT_OBSERVED: bit"
        );

        require(
            invA == invB,
            "BITMAP_STATE_DIFFERS"
        );
    }

    function test_adjacentNonceControl() external view {
        uint128 a = uint128(0x1234);
        uint128 b = a + 1;

        (uint128 slotA, , uint256 bitA) =
            target.verifyNonce(SENDER, a);

        (uint128 slotB, , uint256 bitB) =
            target.verifyNonce(SENDER, b);

        require(
            slotA != slotB || bitA != bitB,
            "CONTROL_FAILED: adjacent nonces map identically"
        );
    }
}
