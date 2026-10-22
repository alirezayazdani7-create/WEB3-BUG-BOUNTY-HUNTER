
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IS06RedeemGlobalCap {
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

    struct Signature {
        SignatureType signature_type;
        bytes signature_bytes;
    }

    function globalConfig() external view returns (uint128, uint128);
    function totalPerBlock(uint256) external view returns (uint128, uint128);
    function hasRole(bytes32, address) external view returns (bool);
    function redeem(Order calldata, Signature calldata) external;
}

contract EthenaS06RedeemGlobalCapEnforcementTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant REDEEMER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    bytes32 constant REDEEMER_ROLE =
        keccak256("REDEEMER_ROLE");

    uint128 constant UNIT = 1e18;

    IS06RedeemGlobalCap target =
        IS06RedeemGlobalCap(MINTING);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
    }

    function _seedRedeemerRole() internal {
        bytes32 roleDataSlot =
            keccak256(abi.encode(REDEEMER_ROLE, uint256(0)));

        vm.store(
            MINTING,
            keccak256(abi.encode(REDEEMER, roleDataSlot)),
            bytes32(uint256(1))
        );

        assertTrue(
            target.hasRole(REDEEMER_ROLE, REDEEMER),
            "redeemer role seed failed"
        );
    }

    function _seedGlobalRedeemed(uint128 value) internal {
        // Local-fork-only fixture. Slot 13 and packed counter layout
        // are assumptions to validate against the deployed implementation.
        bytes32 slot =
            keccak256(abi.encode(block.number, uint256(13)));

        vm.store(
            MINTING,
            slot,
            bytes32(uint256(value) << 128)
        );

        (, uint128 observed) =
            target.totalPerBlock(block.number);

        assertEq(
            observed,
            value,
            "global redeemed counter seed mismatch"
        );
    }

    function _assertGlobalRedeemCapError(
        bytes memory data
    ) internal pure {
        assertGe(data.length, 4, "missing revert selector");

        bytes4 actual;
        assembly {
            actual := mload(add(data, 32))
        }

        bytes4 expected =
            bytes4(
                keccak256("GlobalMaxRedeemPerBlockExceeded()")
            );

        assertEq(
            uint32(actual),
            uint32(expected),
            "wrong redemption cap error"
        );
    }

    function _attemptRedeem(
        address asset,
        uint128 nonce
    )
        internal
        returns (bool success, bytes memory data)
    {
        IS06RedeemGlobalCap.Order memory order =
            IS06RedeemGlobalCap.Order({
                order_id: string.concat(
                    "S06-REDEEM-GLOBAL-",
                    vm.toString(nonce)
                ),
                order_type:
                    IS06RedeemGlobalCap.OrderType.REDEEM,
                expiry: uint120(block.timestamp + 1 days),
                nonce: nonce,
                benefactor: REDEEMER,
                beneficiary: REDEEMER,
                collateral_asset: asset,
                collateral_amount: 1e6,
                usde_amount: UNIT
            });

        IS06RedeemGlobalCap.Signature memory signature =
            IS06RedeemGlobalCap.Signature({
                signature_type:
                    IS06RedeemGlobalCap.SignatureType.EIP712,
                signature_bytes: bytes("")
            });

        vm.prank(REDEEMER);

        (success, data) = MINTING.call(
            abi.encodeWithSelector(
                IS06RedeemGlobalCap.redeem.selector,
                order,
                signature
            )
        );
    }

    function test_GlobalRedeemCapRejectsFurtherUSDCAndUSDTRedemptions()
        external
    {
        (, uint128 globalRedeemCap) =
            target.globalConfig();

        assertGt(
            globalRedeemCap,
            UNIT,
            "global redeem cap too small"
        );

        _seedRedeemerRole();

        // Artificial near-cap state on a local fork only.
        // This is a guard test, not evidence of a live exploit.
        uint128 startingRedeemed =
            globalRedeemCap - UNIT + 1;

        _seedGlobalRedeemed(startingRedeemed);

        (bool usdcOk, bytes memory usdcData) =
            _attemptRedeem(USDC, 907101);

        assertFalse(
            usdcOk,
            "USDC redemption passed above global cap"
        );

        _assertGlobalRedeemCapError(usdcData);

        (bool usdtOk, bytes memory usdtData) =
            _attemptRedeem(USDT, 907102);

        assertFalse(
            usdtOk,
            "USDT redemption passed above global cap"
        );

        _assertGlobalRedeemCapError(usdtData);

        (, uint128 finalRedeemed) =
            target.totalPerBlock(block.number);

        assertEq(
            finalRedeemed,
            startingRedeemed,
            "counter changed after rejected redemptions"
        );
    }
}
