// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

contract P301_ForkDiagnostic is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        address(bytes20(hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_DiagnoseTargetReadCalls() public {
        emit log_named_uint("chainId", block.chainid);
        emit log_named_uint("forkBlock", block.number);
        emit log_named_uint("targetCodeLength", TARGET.code.length);
        emit log_named_bytes32("targetCodeHash", TARGET.codehash);

        (bool ownerOk, bytes memory ownerData) =
            TARGET.staticcall(abi.encodeWithSignature("owner()"));

        emit log_named_uint("ownerCallSuccess", ownerOk ? 1 : 0);
        emit log_named_bytes("ownerReturnData", ownerData);

        (bool roleOk, bytes memory roleData) =
            TARGET.staticcall(
                abi.encodeWithSignature(
                    "hasRole(bytes32,address)",
                    bytes32(0),
                    address(1)
                )
            );

        emit log_named_uint("hasRoleCallSuccess", roleOk ? 1 : 0);
        emit log_named_bytes("hasRoleReturnData", roleData);

        (bool assetOk, bytes memory assetData) =
            TARGET.staticcall(
                abi.encodeWithSignature("isSupportedAsset(address)", USDC)
            );

        emit log_named_uint("isSupportedAssetCallSuccess", assetOk ? 1 : 0);
        emit log_named_bytes("isSupportedAssetReturnData", assetData);

        assertTrue(TARGET.code.length > 0, "Target has no code");
    }
}
