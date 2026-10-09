// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract P301_ForkDiagnostic is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_DiagnoseTargetReadCalls() public {
        emit log_named_uint("chainId", block.chainid);
        emit log_named_uint("forkBlock", block.number);
        emit log_named_uint("targetCodeLength", TARGET.code.length);
        emit log_named_bytes32("targetCodeHash", TARGET.codehash);

        (bool ownerOK, bytes memory ownerData) =
            TARGET.staticcall(abi.encodeWithSignature("owner()"));
        emit log_named_uint("ownerCallSuccess", ownerOK ? 1 : 0);
        emit log_named_bytes("ownerReturnData", ownerData);

        (bool roleOK, bytes memory roleData) =
            TARGET.staticcall(
                abi.encodeWithSignature(
                    "hasRole(bytes32,address)",
                    bytes32(0),
                    address(1)
                )
            );
        emit log_named_uint("hasRoleCallSuccess", roleOK ? 1 : 0);
        emit log_named_bytes("hasRoleReturnData", roleData);

        (bool assetOK, bytes memory assetData) =
            TARGET.staticcall(
                abi.encodeWithSignature(
                    "isSupportedAsset(address)",
                    USDC
                )
            );
        emit log_named_uint("isSupportedAssetCallSuccess", assetOK ? 1 : 0);
        emit log_named_bytes("isSupportedAssetReturnData", assetData);

        assertTrue(TARGET.code.length > 0, "Target has no code");
    }
}
