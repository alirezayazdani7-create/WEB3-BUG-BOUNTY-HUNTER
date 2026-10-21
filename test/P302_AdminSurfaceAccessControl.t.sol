// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

contract P302_AdminSurfaceAccessControl is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant UNAUTHORIZED = address(1);

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_UnauthorizedAdminSurfaceIsBlocked() public {
        require(TARGET.code.length > 0, "Target has no code");

        (bool roleOk, bytes memory roleData) = TARGET.staticcall(
            abi.encodeWithSignature(
                "hasRole(bytes32,address)",
                DEFAULT_ADMIN_ROLE,
                UNAUTHORIZED
            )
        );

        require(roleOk, "Role query failed");
        require(
            !abi.decode(roleData, (bool)),
            "Probe unexpectedly has admin role"
        );

        _expectUnauthorizedRevert(
            "transferAdmin(address)",
            abi.encodeWithSignature(
                "transferAdmin(address)",
                UNAUTHORIZED
            )
        );

        _expectUnauthorizedRevert(
            "removeSupportedAsset(address)",
            abi.encodeWithSignature(
                "removeSupportedAsset(address)",
                USDC
            )
        );

        _expectUnauthorizedRevert(
            "addCustodianAddress(address)",
            abi.encodeWithSignature(
                "addCustodianAddress(address)",
                UNAUTHORIZED
            )
        );

        _expectUnauthorizedRevert(
            "addWhitelistedBenefactor(address)",
            abi.encodeWithSignature(
                "addWhitelistedBenefactor(address)",
                UNAUTHORIZED
            )
        );

        emit log_string(
            "P302 PASS: tested unauthorized admin calls were rejected"
        );
    }

    function _expectUnauthorizedRevert(
        string memory label,
        bytes memory payload
    ) internal {
        vm.prank(UNAUTHORIZED);

        (bool success, bytes memory returnData) =
            TARGET.call(payload);

        emit log_string(label);
        emit log_named_uint("callSucceeded", success ? 1 : 0);
        emit log_named_bytes("returnData", returnData);

        assertFalse(
            success,
            "SECURITY FAILURE: unauthorized admin call succeeded"
        );
    }
}
