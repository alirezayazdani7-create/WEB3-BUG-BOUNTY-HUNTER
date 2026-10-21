
 // SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

contract P303_AccessControlIntegrity is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant UNAUTHORIZED = address(1);

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_UnauthorizedCallsPreserveAdminAndAssetState()
        public
    {
        require(TARGET.code.length > 0, "Target has no code");

        address adminBefore = _readOwner();
        bool supportedBefore = _isSupported(USDC);

        require(supportedBefore, "USDC not supported before test");

        (bool roleOk, bytes memory roleData) = TARGET.staticcall(
            abi.encodeWithSignature(
                "hasRole(bytes32,address)",
                DEFAULT_ADMIN_ROLE,
                UNAUTHORIZED
            )
        );

        require(roleOk && roleData.length >= 32, "Role query failed");
        require(
            !abi.decode(roleData, (bool)),
            "Probe unexpectedly has admin role"
        );

        _expectAccessControlRevert(
            "removeSupportedAsset(address)",
            abi.encodeWithSignature(
                "removeSupportedAsset(address)",
                USDC
            )
        );

        _expectAccessControlRevert(
            "transferAdmin(address)",
            abi.encodeWithSignature(
                "transferAdmin(address)",
                UNAUTHORIZED
            )
        );

        _expectAccessControlRevert(
            "addCustodianAddress(address)",
            abi.encodeWithSignature(
                "addCustodianAddress(address)",
                UNAUTHORIZED
            )
        );

        _expectAccessControlRevert(
            "addWhitelistedBenefactor(address)",
            abi.encodeWithSignature(
                "addWhitelistedBenefactor(address)",
                UNAUTHORIZED
            )
        );

        address adminAfter = _readOwner();
        bool supportedAfter = _isSupported(USDC);

        assertEq(adminAfter, adminBefore, "Admin changed unexpectedly");
        assertEq(
            supportedAfter,
            supportedBefore,
            "USDC support state changed unexpectedly"
        );

        emit log_string("P303 PASS: access-control integrity preserved");
        emit log_address(adminBefore);
        emit log_address(adminAfter);
        emit log_named_uint("USDC supported after test", supportedAfter ? 1 : 0);
    }

    function _readOwner() internal view returns (address result) {
        (bool ok, bytes memory data) =
            TARGET.staticcall(abi.encodeWithSignature("owner()"));

        require(ok && data.length >= 32, "owner() query failed");
        result = abi.decode(data, (address));
    }

    function _isSupported(address asset) internal view returns (bool) {
        (bool ok, bytes memory data) = TARGET.staticcall(
            abi.encodeWithSignature("isSupportedAsset(address)", asset)
        );

        require(ok && data.length >= 32, "Asset query failed");
        return abi.decode(data, (bool));
    }

    function _expectAccessControlRevert(
        string memory label,
        bytes memory payload
    ) internal {
        vm.prank(UNAUTHORIZED);
        (bool success, bytes memory data) = TARGET.call(payload);

        emit log_string(label);
        emit log_named_uint("callSucceeded", success ? 1 : 0);
        emit log_named_bytes("returnData", data);

        assertFalse(success, "Unauthorized call unexpectedly succeeded");
        assertTrue(
            _contains(data, bytes("AccessControl: account")),
            "Revert was not the expected AccessControl error"
        );
    }

    function _contains(bytes memory haystack, bytes memory needle)
        internal
        pure
        returns (bool)
    {
        if (needle.length == 0) return true;
        if (haystack.length < needle.length) return false;

        for (uint256 i = 0; i <= haystack.length - needle.length; i++) {
            bool found = true;

            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }

            if (found) return true;
        }

        return false;
    }
}
