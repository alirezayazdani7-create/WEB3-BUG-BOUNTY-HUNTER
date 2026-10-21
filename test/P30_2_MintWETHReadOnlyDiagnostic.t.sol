// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IP30Diagnostic {
    struct Route {
        address[] addresses;
        uint128[] ratios;
    }

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function verifyRoute(Route calldata route)
        external
        view
        returns (bool);

    function isCustodianAddress(address custodian)
        external
        view
        returns (bool);
}

contract P30_2_MintWETHReadOnlyDiagnostic is Test {
    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant USDE =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    address constant CUSTODIAN =
        0x12FDB344e4D195fF6613D0f742a6E38344c8b455;

    address constant MINTER_1 =
        0x24bE9948466FEcEB22A9B77b19e404F2119fb962;

    address constant MINTER_2 =
        0x6FD5ffEe1220b0458c2114d6ce7fB4dE2BC8fEE6;

    bytes32 constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c858b8a1abb4ceeef8d981c8956a6;

    bytes4 constant OBSERVED_ERROR_SELECTOR = 0x24a01144;

    IP30Diagnostic constant target = IP30Diagnostic(MINTING);

    function _fork() internal {
        vm.createSelectFork(vm.envString("ETHENA_FORK_RPC"));

        assertGt(MINTING.code.length, 0, "Minting contract has no code");
        assertGt(WETH.code.length, 0, "WETH contract has no code");
        assertGt(USDE.code.length, 0, "USDe contract has no code");
    }

    function test_P302_ReadOnlyConfigurationDiagnostic() external {
        _fork();

        emit log_string("P30.2 READ-ONLY DIAGNOSTIC");
        emit log_named_uint("Fork block", block.number);

        emit log_named_uint(
            "Minting bytecode length",
            MINTING.code.length
        );
        emit log_named_uint("WETH bytecode length", WETH.code.length);
        emit log_named_uint("USDe bytecode length", USDE.code.length);

        bool minter1HasRole =
            target.hasRole(MINTER_ROLE, MINTER_1);
        bool minter2HasRole =
            target.hasRole(MINTER_ROLE, MINTER_2);

        emit log_named_address("Minter candidate 1", MINTER_1);
        emit log_named_uint(
            "Candidate 1 has MINTER_ROLE (1=yes)",
            minter1HasRole ? 1 : 0
        );

        emit log_named_address("Minter candidate 2", MINTER_2);
        emit log_named_uint(
            "Candidate 2 has MINTER_ROLE (1=yes)",
            minter2HasRole ? 1 : 0
        );

        bool custodianRegistered =
            target.isCustodianAddress(CUSTODIAN);

        emit log_named_address("Custodian candidate", CUSTODIAN);
        emit log_named_uint(
            "Custodian registered (1=yes)",
            custodianRegistered ? 1 : 0
        );

        address[] memory addresses = new address[](1);
        uint128[] memory ratios = new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        IP30Diagnostic.Route memory route =
            IP30Diagnostic.Route({
                addresses: addresses,
                ratios: ratios
            });

        (bool routeCallOk, bytes memory routeRet) =
            MINTING.staticcall(
                abi.encodeWithSelector(
                    target.verifyRoute.selector,
                    route
                )
            );

        emit log_named_uint(
            "verifyRoute staticcall succeeded (1=yes)",
            routeCallOk ? 1 : 0
        );

        if (routeCallOk && routeRet.length >= 32) {
            bool routeValid = abi.decode(routeRet, (bool));

            emit log_named_uint(
                "Route accepted (1=yes)",
                routeValid ? 1 : 0
            );
        } else {
            emit log_string("verifyRoute return/revert data:");
            emit log_bytes(routeRet);
        }

        emit log_string(
            "Previously observed mintWETH error selector:"
        );
        emit log_bytes(abi.encodePacked(OBSERVED_ERROR_SELECTOR));

        emit log_string(
            "READ-ONLY ONLY: mintWETH was NOT called."
        );
        emit log_string(
            "No token transfer or contract state change was attempted."
        );
    }
}
