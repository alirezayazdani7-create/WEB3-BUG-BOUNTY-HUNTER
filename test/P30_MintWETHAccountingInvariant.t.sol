// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IWETHP30 {
    function balanceOf(address account) external view returns (uint256);
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUSDeP30 {
    function balanceOf(address account) external view returns (uint256);
}

interface IMintingP30 {

    enum SignatureType {
        EIP712,
        EIP1271
    }

    enum OrderType {
        MINT,
        REDEEM
    }

    struct Order {
        string order_id;
        OrderType order_type;
        uint120 expiry;
        uint128 nonce;
        address benefactor;
        address beneficiary;
        address collateral_asset;
        uint128 collateral_amount;
        uint128 usde_amount;
    }

    struct Route {
        address[] addresses;
        uint128[] ratios;
    }

    struct Signature {
        SignatureType signature_type;
        bytes signature_bytes;
    }

    function owner() external view returns (address);

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    function addWhitelistedBenefactor(
        address benefactor
    ) external;

    function hashOrder(
        Order calldata order
    ) external view returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    ) external view returns (bytes32);

    function verifyRoute(
        Route calldata route
    ) external view returns (bool);

    function isCustodianAddress(
        address custodian
    ) external view returns (bool);

    function mintWETH(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    ) external;
}

contract P30Valid1271Wallet {

    bytes4 constant MAGICVALUE = 0x1626ba7e;
    bytes4 constant FAILVALUE = 0xffffffff;

    bytes32 public approvedDigest;

    function setApprovedDigest(
        bytes32 digest
    ) external {
        approvedDigest = digest;
    }

    function execute(
        address target,
        bytes calldata data
    ) external returns (bytes memory) {

        (
            bool ok,
            bytes memory ret
        ) = target.call(data);

        require(ok, "wallet execute failed");

        return ret;
    }

    function executeValue(
        address target,
        bytes calldata data
    )
        external
        payable
        returns (bytes memory)
    {
        (
            bool ok,
            bytes memory ret
        ) = target.call{value: msg.value}(data);

        require(ok, "wallet execute value failed");

        return ret;
    }

    function isValidSignature(
        bytes32 hash,
        bytes calldata
    )
        external
        view
        returns (bytes4)
    {
        if (hash == approvedDigest) {
            return MAGICVALUE;
        }

        return FAILVALUE;
    }

    receive() external payable {}
}

contract P30MintWETHAccountingInvariantTest is Test {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant USDe =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    address constant CUSTODIAN =
        0x12FDB344e4D195fF6613D0f742a6E38344c8b455;

    /*
     * These are observed Mint callers on the live V2 contract.
     * The test NEVER trusts these addresses blindly.
     * _findMinter() verifies actual MINTER_ROLE membership
     * on the selected local fork before using one.
     */
    address constant MINTER_CANDIDATE_1 =
        0x24bE9948466FEcEB22A9B77b19e404F2119fb962;

    address constant MINTER_CANDIDATE_2 =
        0x950c886C9C0d9dE4E0F8E9eC7d0A4A0AA060e96C8;

    address constant MINTER_CANDIDATE_3 =
        0x655a1B01B4f7A0c5f0F7E2F0F91faD93B7B;

    address constant MINTER_CANDIDATE_4 =
        0x6FD5ffEe1220b0458c2114d6ce7fB4dE2BC8fEE6;

    bytes32 constant MINTER_ROLE =
        keccak256("MINTER_ROLE");

    IMintingP30 constant target =
        IMintingP30(MINTING);

    IWETHP30 constant weth =
        IWETHP30(WETH);

    IUSDeP30 constant usde =
        IUSDeP30(USDe);

    function _fork() internal {

        uint256 forkId =
            vm.createFork(
                vm.envString("ETHENA_FORK_RPC")
            );

        vm.selectFork(forkId);

        require(
            MINTING.code.length > 0,
            "P30: Minting V2 bytecode missing"
        );

        require(
            WETH.code.length > 0,
            "P30: WETH bytecode missing"
        );

        require(
            USDe.code.length > 0,
            "P30: USDe bytecode missing"
        );
    }

    function _findMinter()
        internal
        view
        returns (address minter)
    {
        if (
            target.hasRole(
                MINTER_ROLE,
                MINTER_CANDIDATE_1
            )
        ) {
            return MINTER_CANDIDATE_1;
        }

        if (
            target.hasRole(
                MINTER_ROLE,
                MINTER_CANDIDATE_2
            )
        ) {
            return MINTER_CANDIDATE_2;
        }

        if (
            target.hasRole(
                MINTER_ROLE,
                MINTER_CANDIDATE_3
            )
        ) {
            return MINTER_CANDIDATE_3;
        }

        if (
            target.hasRole(
                MINTER_ROLE,
                MINTER_CANDIDATE_4
            )
        ) {
            return MINTER_CANDIDATE_4;
        }

        revert(
            "P30: no verified MINTER_ROLE candidate"
        );
    }

    function _order(
        address wallet,
        uint128 collateralAmount,
        uint128 usdeAmount
    )
        internal
        view
        returns (
            IMintingP30.Order memory order
        )
    {
        order = IMintingP30.Order({
            order_id: "P30-WETH-ACCOUNTING",
            order_type: IMintingP30.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: uint128(300001),
            benefactor: wallet,
            beneficiary: wallet,
            collateral_asset: WETH,
            collateral_amount: collateralAmount,
            usde_amount: usdeAmount
        });
    }

    function _route()
        internal
        pure
        returns (
            IMintingP30.Route memory route
        )
    {
        address[] memory addresses =
            new address[](1);

        uint128[] memory ratios =
            new uint128[](1);

        addresses[0] = CUSTODIAN;
        ratios[0] = 10_000;

        route = IMintingP30.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _signature()
        internal
        pure
        returns (
            IMintingP30.Signature memory sig
        )
    {
        sig = IMintingP30.Signature({
            signature_type:
                IMintingP30.SignatureType.EIP1271,

            signature_bytes:
                hex"5033302d574554482d4143434f554e54494e47"
        });
    }

    function test_P30_WETH_AccountingInvariant()
        external
    {
        _fork();

        P30Valid1271Wallet wallet =
            new P30Valid1271Wallet();

        vm.prank(target.owner());

        target.addWhitelistedBenefactor(
            address(wallet)
        );

        uint256 collateral =
            1 ether;

        uint256 usdeAmount =
            1 ether;

        vm.deal(
            address(wallet),
            collateral
        );

        wallet.executeValue{
            value: collateral
        }(
            WETH,
            abi.encodeWithSelector(
                IWETHP30.deposit.selector
            )
        );

        wallet.execute(
            WETH,
            abi.encodeWithSelector(
                IWETHP30.approve.selector,
                MINTING,
                type(uint256).max
            )
        );

        assertEq(
            weth.balanceOf(address(wallet)),
            collateral,
            "P30: initial WETH mismatch"
        );

        IMintingP30.Order memory order =
            _order(
                address(wallet),
                uint128(collateral),
                uint128(usdeAmount)
            );

        wallet.setApprovedDigest(
            target.hashOrder(order)
        );

        IMintingP30.Route memory route =
            _route();

        IMintingP30.Signature memory sig =
            _signature();

        assertTrue(
            target.verifyRoute(route),
            "P30: valid route rejected"
        );

        assertTrue(
            target.isCustodianAddress(CUSTODIAN),
            "P30: custodian candidate is not registered"
        );

        address minter =
            _findMinter();

        target.verifyOrder(
            order,
            sig
        );

        assertTrue(
            target.hasRole(
                MINTER_ROLE,
                minter
            ),
            "P30: selected MINTER role missing"
        );

        uint256 walletWethBefore =
            weth.balanceOf(address(wallet));

        uint256 custodianEthBefore =
            CUSTODIAN.balance;

        uint256 walletUsdeBefore =
            usde.balanceOf(address(wallet));

        vm.prank(minter);

        target.mintWETH(
            order,
            route,
            sig
        );

        uint256 walletWethAfter =
            weth.balanceOf(address(wallet));

        uint256 custodianEthAfter =
            CUSTODIAN.balance;

        uint256 walletUsdeAfter =
            usde.balanceOf(address(wallet));

        uint256 wethSpent =
            walletWethBefore -
            walletWethAfter;

        uint256 ethReceived =
            custodianEthAfter -
            custodianEthBefore;

        uint256 usdeMinted =
            walletUsdeAfter -
            walletUsdeBefore;

        assertEq(
            wethSpent,
            collateral,
            "P30 ALERT: WETH spent != signed collateral"
        );

        assertEq(
            ethReceived,
            collateral,
            "P30 ALERT: custodian ETH != collateral"
        );

        assertEq(
            usdeMinted,
            usdeAmount,
            "P30 ALERT: USDe minted != signed amount"
        );

        assertEq(
            walletWethAfter,
            0,
            "P30 ALERT: residual WETH remains"
        );

        emit log_string(
            "P30 PASS: WETH -> ETH -> USDe accounting invariant holds"
        );
    }

    function test_P30_MutatedUsdeAmountCannotCreateMismatch()
        external
    {
        _fork();

        P30Valid1271Wallet wallet =
            new P30Valid1271Wallet();

        vm.prank(target.owner());

        target.addWhitelistedBenefactor(
            address(wallet)
        );

        uint256 collateral =
            1 ether;

        vm.deal(
            address(wallet),
            collateral
        );

        wallet.executeValue{
            value: collateral
        }(
            WETH,
            abi.encodeWithSelector(
                IWETHP30.deposit.selector
            )
        );

        wallet.execute(
            WETH,
            abi.encodeWithSelector(
                IWETHP30.approve.selector,
                MINTING,
                type(uint256).max
            )
        );

        IMintingP30.Order memory signedOrder =
            _order(
                address(wallet),
                uint128(collateral),
                uint128(1 ether)
            );

        wallet.setApprovedDigest(
            target.hashOrder(signedOrder)
        );

        IMintingP30.Order memory mutated =
            signedOrder;

        mutated.usde_amount =
            uint128(2 ether);

        IMintingP30.Route memory route =
            _route();

        IMintingP30.Signature memory sig =
            _signature();

        uint256 beforeWeth =
            weth.balanceOf(address(wallet));

        address minter =
            _findMinter();

        (
            bool ok,
        ) = address(MINTING).call(
            abi.encodeWithSelector(
                target.mintWETH.selector,
                mutated,
                route,
                sig
            )
        );

        /*
         * The call above must be made by an actual MINTER.
         * Because address(MINTING).call() would otherwise use
         * the test contract as msg.sender, execute the real
         * call through prank below instead.
         */

        ok;

        uint256 afterFailedAttempt =
            weth.balanceOf(address(wallet));

        assertEq(
            afterFailedAttempt,
            beforeWeth,
            "P30: preliminary mutated call changed WETH"
        );

        vm.prank(minter);

        (
            ok,
        ) = address(MINTING).call(
            abi.encodeWithSelector(
                target.mintWETH.selector,
                mutated,
                route,
                sig
            )
        );

        uint256 afterWeth =
            weth.balanceOf(address(wallet));

        assertTrue(
            !ok,
            "P30 ALERT: mutated USDe amount accepted"
        );

        assertEq(
            afterWeth,
            beforeWeth,
            "P30 ALERT: collateral changed after rejected order"
        );

        emit log_string(
            "P30 PASS: signed USDe amount is bound to execution"
        );
    }
}
