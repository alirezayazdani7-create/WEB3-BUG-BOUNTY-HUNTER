// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEthenaNonceProbe {
    function verifyNonce(address sender, uint128 nonce)
        external
        view
        returns (uint128 slot, uint256 invalidator, uint256 bit);
}

contract EthenaNonceCollisionDiagnostic {
    address internal constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address internal constant SENDER = address(0x1111);

    IEthenaNonceProbe internal constant target =
        IEthenaNonceProbe(MINTING);

    // Checks mapping collision only; does not prove mint/redeem impact.
    function test_high64BitCollisionDiagnostic() external view {
        uint128 a = uint128(0x1234);
        uint128 b = uint128(uint256(a) + (uint256(1) << 64));

        (uint128 slotA, , uint256 bitA) =
            target.verifyNonce(SENDER, a);

        (uint128 slotB, , uint256 bitB) =
            target.verifyNonce(SENDER, b);

        require(slotA == slotB, "SLOT_MISMATCH");
        require(bitA == bitB, "BIT_MISMATCH");
    }

    function test_highBitsDoNotChangeBitmapMapping() external view {
        uint128 base = uint128(0x5A3C);

        (uint128 expectedSlot, , uint256 expectedBit) =
            target.verifyNonce(SENDER, base);

        uint128[3] memory offsets = [
            uint128(uint256(1) << 64),
            uint128(uint256(1) << 80),
            uint128(uint256(1) << 120)
        ];

        for (uint256 i = 0; i < offsets.length; i++) {
            uint128 candidate = base + offsets[i];

            (uint128 slot, , uint256 bit) =
                target.verifyNonce(SENDER, candidate);

            require(slot == expectedSlot, "HIGH_BITS_CHANGED_SLOT");
            require(bit == expectedBit, "HIGH_BITS_CHANGED_BIT");
        }
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
            "ADJACENT_NONCES_MAP_IDENTICALLY"
        );
    }

    function test_zeroNonceIsRejected() external view {
        (bool success, ) = address(target).staticcall(
            abi.encodeWithSelector(
                IEthenaNonceProbe.verifyNonce.selector,
                SENDER,
                uint128(0)
            )
        );

        require(!success, "ZERO_NONCE_WAS_ACCEPTED");
    }
}
