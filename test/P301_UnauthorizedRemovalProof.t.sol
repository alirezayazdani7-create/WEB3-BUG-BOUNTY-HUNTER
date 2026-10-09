// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

interface IEthenaMintingP301 {
    function owner() external view returns (address);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);
    function isSupportedAsset(address asset)
        external
        view
        returns (bool);
    function removeSupportedAsset(address asset) external;
}

contract P301_ForkAccessControlTest is Test {
    address constant TARGET =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_UnauthorizedCannotRemoveSupportedAsset()
        public
    {
        IEthenaMintingP301 target =
            IEthenaMintingP301(TARGET);

        address attacker = makeAddr("unauthorized-p301");

        assertTrue(
            target.isSupportedAsset(USDC),
            "USDC is not supported at this fork block"
        );

        bytes32 adminRole = target.DEFAULT_ADMIN_ROLE();

        assertFalse(
            target.hasRole(adminRole, attacker),
            "Test attacker unexpectedly has admin role"
        );

        vm.prank(attacker);
        vm.expectRevert();

        target.removeSupportedAsset(USDC);

        assertTrue(
            target.isSupportedAsset(USDC),
            "Supported asset changed after unauthorized attempt"
        );
    }
}
