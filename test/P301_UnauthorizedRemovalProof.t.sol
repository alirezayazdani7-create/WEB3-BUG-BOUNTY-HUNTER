
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

    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);

    IEthenaMintingP301 target;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        target = IEthenaMintingP301(TARGET);

        require(TARGET.code.length > 0, "Target has no code");
    }

    function test_UnauthorizedCannotRemoveSupportedAsset() public {
        address attacker = makeAddr("unauthorized");

        assertFalse(
            target.hasRole(DEFAULT_ADMIN_ROLE, attacker),
            "Attacker unexpectedly has admin role"
        );

        // Find a candidate asset that is currently supported.
        // The test must not pass merely because an asset is inactive.
        address[] memory candidates = new address[](4);
        candidates[0] = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3; // USDe
        candidates[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        candidates[2] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        candidates[3] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI

        address asset;
        bool found;

        for (uint256 i = 0; i < candidates.length; i++) {
            try target.isSupportedAsset(candidates[i]) returns (bool supported) {
                if (supported) {
                    asset = candidates[i];
                    found = true;
                    break;
                }
            } catch {}
        }

        require(found, "No supported candidate asset found");

        vm.startPrank(attacker);
        vm.expectRevert();
        target.removeSupportedAsset(asset);
        vm.stopPrank();

        assertTrue(
            target.isSupportedAsset(asset),
            "Supported asset status changed after unauthorized call"
        );
    }
}
