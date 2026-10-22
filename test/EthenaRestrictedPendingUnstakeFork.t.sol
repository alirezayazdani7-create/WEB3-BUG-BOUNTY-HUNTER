// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStakedUSDeV2Minimal {
    function cooldowns(address account)
        external
        view
        returns (uint104 cooldownEnd, uint256 underlyingAmount);

    function unstake(address receiver) external;
    function silo() external view returns (address);
}

interface IAccessControlMinimal {
    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);
}

/// @notice Read-only fork diagnostic. No transactions are broadcast.
/// @dev Supply STAKED_USDE, USDE, RESTRICTED_USER and RPC_URL as environment variables.
contract EthenaRestrictedPendingUnstakeForkTest is Test {
    bytes32 constant FULL_RESTRICTED_STAKER_ROLE =
        keccak256("FULL_RESTRICTED_STAKER_ROLE");

    address staked;
    address usde;
    address restrictedUser;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"));

        staked = vm.envAddress("STAKED_USDE");
        usde = vm.envAddress("USDE");
        restrictedUser = vm.envAddress("RESTRICTED_USER");

        require(staked.code.length > 0, "Staked contract has no code");
        require(usde.code.length > 0, "USDe contract has no code");
    }

    function test_ReadOnlyRestrictedUnstakeDiagnostics() public view {
        IStakedUSDeV2Minimal staking =
            IStakedUSDeV2Minimal(staked);

        (uint104 cooldownEnd, uint256 underlyingAmount) =
            staking.cooldowns(restrictedUser);

        bool hasRestriction =
            IAccessControlMinimal(staked).hasRole(
                FULL_RESTRICTED_STAKER_ROLE,
                restrictedUser
            );

        emit log_named_address("StakedUSDeV2", staked);
        emit log_named_address("USDe", usde);
        emit log_named_address("Restricted user", restrictedUser);
        emit log_named_address("Silo", staking.silo());
        emit log_named_uint("Cooldown end", cooldownEnd);
        emit log_named_uint("Pending underlying amount", underlyingAmount);
        emit log_named_uint("Current timestamp", block.timestamp);
        emit log_named_uint(
            "Has FULL_RESTRICTED_STAKER_ROLE (1=yes)",
            hasRestriction ? 1 : 0
        );

        if (!hasRestriction) {
            emit log("INCONCLUSIVE: supplied user is not fully restricted");
        } else if (underlyingAmount == 0) {
            emit log("INCONCLUSIVE: no pending cooldown amount");
        } else if (block.timestamp < cooldownEnd) {
            emit log("INCONCLUSIVE: cooldown has not matured");
        } else {
            emit log(
                "PRECONDITIONS MET: review unstake and inherited access controls"
            );
        }

        // Intentionally does not call unstake(), approve(), or transfer tokens.
    }
}
