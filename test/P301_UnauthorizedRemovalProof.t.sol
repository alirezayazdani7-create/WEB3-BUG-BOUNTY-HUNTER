// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

interface IEthenaMintingP301 {
    function removeSupportedAsset(address asset) external;
    function isSupportedAsset(address asset) external view returns (bool);
    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);
}

contract P301_UnauthorizedRemovalProof is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IEthenaMintingP301 target;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        target = IEthenaMintingP301(TARGET);
    }

    function test_UnauthorizedCannotRemoveSupportedAsset() public {
        address attacker = makeAddr("unauthorized");

        bool supportedBefore = target.isSupportedAsset(WETH);
        assertFalse(
            target.hasRole(bytes32(0), attacker),
            "Test attacker unexpectedly has admin role"
        );

        vm.startPrank(attacker);
        vm.expectRevert();
        target.removeSupportedAsset(WETH);
        vm.stopPrank();

        assertEq(
            target.isSupportedAsset(WETH),
            supportedBefore,
            "Unauthorized caller changed asset support"
        );
    }
}
