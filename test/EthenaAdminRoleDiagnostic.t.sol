// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

contract EthenaAdminRoleDiagnostic is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant PROBE = address(1);
    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_ReadOnlyAdminRoleDiagnostics() public {
        require(TARGET.code.length > 0, "Target has no code");

        emit log_named_uint("chainId", block.chainid);
        emit log_named_uint("forkBlock", block.number);

        _logCall(
            "hasRole(bytes32,address)",
            abi.encodeWithSignature(
                "hasRole(bytes32,address)",
                DEFAULT_ADMIN_ROLE,
                PROBE
            )
        );

        _logCall(
            "getRoleAdmin(bytes32)",
            abi.encodeWithSignature(
                "getRoleAdmin(bytes32)",
                DEFAULT_ADMIN_ROLE
            )
        );

        _logCall(
            "owner()",
            abi.encodeWithSignature("owner()")
        );

        _logCall(
            "DEFAULT_ADMIN_ROLE()",
            abi.encodeWithSignature("DEFAULT_ADMIN_ROLE()")
        );

        _logCall(
            "isSupportedAsset(address)",
            abi.encodeWithSignature(
                "isSupportedAsset(address)",
                address(
                    bytes20(
                        hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
                    )
                )
            )
        );
    }

    function _logCall(
        string memory label,
        bytes memory payload
    ) internal {
        (bool ok, bytes memory data) = TARGET.staticcall(payload);

        emit log_string(label);
        emit log_named_uint("staticcallSuccess", ok ? 1 : 0);
        emit log_named_bytes("returnData", data);
    }
}
