
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IStUSDeV2Audit {
    function cooldowns(address)
        external view returns (uint104, uint152);
    function hasRole(bytes32, address) external view returns (bool);
    function asset() external view returns (address);
    function unstake(address receiver) external;
}

interface IERC20Audit {
    function balanceOf(address) external view returns (uint256);
}

contract EthenaRestrictedPendingUnstakeForkTest is Test {
    bytes32 constant FULL_RESTRICTED_STAKER_ROLE =
        keccak256("FULL_RESTRICTED_STAKER_ROLE");

    IStUSDeV2Audit stUSDe;
    address staker;
    address receiver;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));
        stUSDe = IStUSDeV2Audit(
            vm.envAddress("STUSDE_ADDRESS")
        );
        staker = vm.envAddress("RESTRICTED_STAKER");
        receiver = vm.envAddress("UNSTAKE_RECEIVER");
    }

    function test_restrictedStakerCannotClaimMaturedCooldown()
        public
    {
        require(
            stUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, staker),
            "fixture invalid: staker is not fully restricted"
        );

        (uint104 cooldownEnd, uint152 amount) =
            stUSDe.cooldowns(staker);

        require(amount > 0, "fixture invalid: no pending cooldown");
        require(
            block.timestamp >= cooldownEnd,
            "fixture invalid: cooldown not matured"
        );

        IERC20Audit token = IERC20Audit(stUSDe.asset());
        uint256 beforeBalance = token.balanceOf(receiver);

        vm.prank(staker);
        stUSDe.unstake(receiver);

        uint256 afterBalance = token.balanceOf(receiver);

        assertEq(
            afterBalance - beforeBalance,
            uint256(amount),
            "unexpected unstake amount"
        );
    }
}
