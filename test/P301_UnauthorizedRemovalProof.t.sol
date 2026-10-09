// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

contract P301_ForkDiagnostic is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        address(bytes20(hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));

    address constant UNAUTHORIZED = address(1);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_UnauthorizedCannotRemoveSupportedAsset() public {
        emit log_named_uint("chainId", block.chainid);
        emit log_named_uint("forkBlock", block.number);

        require(TARGET.code.length > 0, "Target has no code");

        // Confirm USDC is supported before the test.
        (bool readOk, bytes memory readData) =
            TARGET.staticcall(
                abi.encodeWithSignature(
                    "isSupportedAsset(address)",
                    USDC
                )
            );

        require(readOk, "Initial asset query failed");
        require(
            abi.decode(readData, (bool)),
            "USDC is not supported at this fork block"
        );

        // Confirm the test address is not an admin.
        (bool roleOk, bytes memory roleData) =
            TARGET.staticcall(
                abi.encodeWithSignature(
                    "hasRole(bytes32,address)",
                    bytes32(0),
                    UNAUTHORIZED
                )
            );

        require(roleOk, "Admin role query failed");
        require(
            !abi.decode(roleData, (bool)),
            "Test address unexpectedly has admin role"
        );

        // Attempt removal only on the local fork.
        vm.prank(UNAUTHORIZED);
        (bool removeOk, bytes memory removeData) =
            TARGET.call(
                abi.encodeWithSignature(
                    "removeSupportedAsset(address)",
                    USDC
                )
            );

        emit log_named_uint(
            "unauthorizedRemovalSucceeded",
            removeOk ? 1 : 0
        );
        emit log_named_bytes(
            "unauthorizedRemovalReturnData",
            removeData
        );

        // The unauthorized call must fail.
        assertFalse(
            removeOk,
            "SECURITY FAILURE: unauthorized removal succeeded"
        );

        // Confirm USDC remains supported after the failed attempt.
        (bool finalReadOk, bytes memory finalReadData) =
            TARGET.staticcall(
                abi.encodeWithSignature(
                    "isSupportedAsset(address)",
                    USDC
                )
            );

        require(finalReadOk, "Final asset query failed");
        assertTrue(
            abi.decode(finalReadData, (bool)),
            "SECURITY FAILURE: USDC no longer supported"
        );

        emit log_string(
            "PASS: unauthorized removal was rejected on local fork"
        );
    }
}
