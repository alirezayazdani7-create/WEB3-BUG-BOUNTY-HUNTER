// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IEthenaMintingAccessProbe {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account)
        external view returns (bool);
    function isSupportedAsset(address asset)
        external view returns (bool);
    function removeSupportedAsset(address asset) external;
}

contract P301UnauthorizedRemovalProofTest is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;

    address constant ATTACKER = address(0xBAD);

    IEthenaMintingAccessProbe target;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
        target = IEthenaMintingAccessProbe(MINTING);

        require(
            MINTING.code.length > 0,
            "Minting contract bytecode missing"
        );

        require(
            target.isSupportedAsset(USDC),
            "USDC must be active for this test"
        );

        require(
            !target.hasRole(
                target.DEFAULT_ADMIN_ROLE(),
                ATTACKER
            ),
            "Attacker unexpectedly has admin role"
        );
    }

    function test_UnauthorizedCallerCannotRemoveSupportedAsset()
        external
    {
        vm.expectRevert();
        vm.prank(ATTACKER);
        target.removeSupportedAsset(USDC);

        assertTrue(
            target.isSupportedAsset(USDC),
            "Unauthorized call changed supported-asset state"
        );

        emit log_string(
            "PASS: unauthorized removal reverted on local fork"
        );
    }
}
