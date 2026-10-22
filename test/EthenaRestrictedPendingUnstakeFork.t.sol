// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IStakedUSDeV2Diagnostic {
    function cooldowns(address account)
        external
        view
        returns (uint104 cooldownEnd, uint256 underlyingAmount);

    function silo() external view returns (address);
}

interface IAccessControlDiagnostic {
    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);
}

contract EthenaRestrictedPendingUnstakeForkTest is Test {
    bytes32 constant FULL_RESTRICTED_STAKER_ROLE =
        keccak256("FULL_RESTRICTED_STAKER_ROLE");

    function test_ReadOnlyRestrictedUnstakeDiagnostics() public {
        string memory rpc = vm.envString("RPC_URL");
        address staked = vm.envAddress("STAKED_USDE");
        address usde = vm.envAddress("USDE");
        address user = vm.envAddress("RESTRICTED_USER");

        vm.createSelectFork(rpc);

        require(staked.code.length > 0, "Staked contract has no code");
        require(usde.code.length > 0, "USDe contract has no code");

        IStakedUSDeV2Diagnostic staking =
            IStakedUSDeV2Diagnostic(staked);

        (uint104 cooldownEnd, uint256 amount) =
            staking.cooldowns(user);

        bool restricted =
            IAccessControlDiagnostic(staked).hasRole(
                FULL_RESTRICTED_STAKER_ROLE,
                user
            );

        emit log_named_address("StakedUSDeV2", staked);
        emit log_named_address("USDe", usde);
        emit log_named_address("Restricted user", user);
        emit log_named_address("Silo", staking.silo());
        emit log_named_uint("Cooldown end", cooldownEnd);
        emit log_named_uint("Pending amount", amount);
        emit log_named_uint("Current timestamp", block.timestamp);
        emit log_named_uint("Restricted (1=yes)", restricted ? 1 : 0);

        if (!restricted) {
            emit log("INCONCLUSIVE: account is not restricted");
        } else if (amount == 0) {
            emit log("INCONCLUSIVE: no pending unstake amount");
        } else if (block.timestamp < cooldownEnd) {
            emit log("INCONCLUSIVE: cooldown has not matured");
        } else {
            emit log(
                "PRECONDITIONS MET: further access-control analysis required"
            );
        }
    }
}
