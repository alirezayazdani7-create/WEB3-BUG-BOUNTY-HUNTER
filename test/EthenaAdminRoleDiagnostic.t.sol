
 // SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

contract EthenaAdminRoleDiagnostic is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant PROBE = address(1);
    address constant USDC =
        address(bytes20(hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));
    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_ReadOnlyAdminRoleDiagnostics() public {
        require(TARGET.code.length > 0, "Target has no code");

        emit log_named_uint("chainId", block.chainid);
        emit log_named_uint("forkBlock", block.number);

        _logCall(
            "hasRole(DEFAULT_ADMIN_ROLE, PROBE)",
            abi.encodeWithSignature(
                "hasRole(bytes32,address)",
                DEFAULT_ADMIN_ROLE,
                PROBE
            )
        );

        _logCall(
            "getRoleAdmin(DEFAULT_ADMIN_ROLE)",
            abi.encodeWithSignature(
                "getRoleAdmin(bytes32)",
                DEFAULT_ADMIN_ROLE
            )
        );

        (bool ownerOk, bytes memory ownerData) =
            TARGET.staticcall(abi.encodeWithSignature("owner()"));

        emit log_string("owner()");
        emit log_named_uint("staticcallSuccess", ownerOk ? 1 : 0);
        emit log_named_bytes("returnData", ownerData);

        if (ownerOk && ownerData.length >= 32) {
            address ownerAddress = abi.decode(ownerData, (address));
            emit log_address("decodedOwner", ownerAddress);

            _logCall(
                "hasRole(DEFAULT_ADMIN_ROLE, owner())",
                abi.encodeWithSignature(
                    "hasRole(bytes32,address)",
                    DEFAULT_ADMIN_ROLE,
                    ownerAddress
                )
            );
        } else {
            emit log_string("Owner role check skipped");
        }

        _logCall(
            "DEFAULT_ADMIN_ROLE()",
            abi.encodeWithSignature("DEFAULT_ADMIN_ROLE()")
        );

        _logCall(
            "isSupportedAsset(USDC)",
            abi.encodeWithSignature(
                "isSupportedAsset(address)",
                USDC
            )
        );

        _logCall(
            "removeSupportedAsset(USDC) via staticcall",
            abi.encodeWithSignature(
                "removeSupportedAsset(address)",
                USDC
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
