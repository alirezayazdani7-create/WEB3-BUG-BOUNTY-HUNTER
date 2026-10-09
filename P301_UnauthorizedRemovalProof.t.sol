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
    address constant ETHENA_MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);

    IEthenaMintingP301 target;

    function setUp() public {
        string memory rpc = vm.envString("ETH_RPC_URL");
        vm.createSelectFork(rpc);
        target = IEthenaMintingP301(ETHENA_MINTING);
    }

    function test_UnauthorizedCannotRemoveSupportedAsset() public {
        address attacker = makeAddr("unauthorized");
        bytes32 adminRole = DEFAULT_ADMIN_ROLE;

        bool supportedBefore = target.isSupportedAsset(WETH);
        bool attackerIsAdmin =
            target.hasRole(adminRole, attacker);

        emit log_named_uint(
            "WETH_SUPPORTED_BEFORE",
            supportedBefore ? 1 : 0
        );
        emit log_named_uint(
            "ATTACKER_IS_ADMIN",
            attackerIsAdmin ? 1 : 0
        );

        vm.assume(!attackerIsAdmin);

        vm.prank(attacker);
        vm.expectRevert();
        target.removeSupportedAsset(WETH);

        bool supportedAfter = target.isSupportedAsset(WETH);

        emit log_named_uint(
            "WETH_SUPPORTED_AFTER",
            supportedAfter ? 1 : 0
        );

        assertEq(
            supportedAfter,
            supportedBefore,
            "Unauthorized caller changed supported-asset state"
        );
    }
}
