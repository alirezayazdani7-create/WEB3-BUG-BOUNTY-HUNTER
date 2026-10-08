// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

interface IWETHP301 {
    function balanceOf(address account) external view returns (uint256);
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUSDeP301 {
    function balanceOf(address account) external view returns (uint256);
}

interface IMintingP301 {
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

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function addWhitelistedBenefactor(address benefactor) external;

    function hashOrder(Order calldata order)
        external
        view
        returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    ) external view returns (bytes32);

    function verifyRoute(Route calldata route)
        external
        view
        returns (bool);

    function isCustodianAddress(address custodian)
        external
        view
        returns (bool);

    function mintWETH(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    ) external;
}

contract P301Valid1271Wallet {
    bytes4 constant MAGICVALUE = 0x1626ba7e;
    bytes4 constant FAILVALUE = 0xffffffff;

    bytes32 public approvedDigest;

    function setApprovedDigest(bytes32 digest) external {
        approvedDigest = digest;
    }

    function execute(
        address target,
        bytes calldata data
    ) external returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call(data);
        require(ok, "wallet execute failed");
        return ret;
    }

    function executeValue(
        address target,
        bytes calldata data
    ) external payable returns (bytes memory) {
        (bool ok, bytes memory ret) =
            target.call{value: msg.value}(data);
        require(ok, "wallet execute value failed");
        return ret;
    }

    function isValidSignature(
        bytes32 hash,
        bytes calldata
    ) external view returns (bytes4) {
        if (hash == approvedDigest) {
            return MAGICVALUE;
        }
        return FAILVALUE;
    }

    receive() external payable {}
}

contract P301MintWETHAccountingDiscoveryTest is Test {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant USDe =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    bytes32 constant MINTER_ROLE =
        keccak256("MINTER_ROLE");

    IMintingP301 constant target =
        IMintingP301(MINTING);

    IWETHP301 constant weth =
        IWETHP301(WETH);

    IUSDeP301 constant usde =
        IUSDeP301(USDe);

    function _fork() internal {
        uint256 forkId =
            vm.createFork(vm.envString("ETHENA_FORK_RPC"));

        vm.selectFork(forkId);

        require(
            MINTING.code.length > 0,
            "P301: Minting V2 bytecode missing"
        );

        require(
            WETH.code.length > 0,
            "P301: WETH bytecode missing"
        );

        require(
            USDe.code.length > 0,
            "P301: USDe bytecode missing"
        );
    }

    function _minter()
        internal
        view
        returns (address)
    {
        address minter =
            vm.envAddress("P30_MINTER");

        require(
            minter != address(0),
            "P301: MINTER env missing"
        );

        require(
            target.hasRole(
                MINTER_ROLE,
                minter
            ),
            "P301: MINTER_ROLE verification failed"
        );

        return minter;
    }

    function _custodian()
        internal
        view
        returns (address)
    {
        address custodian =
            vm.envAddress("P30_CUSTODIAN");

        require(
            custodian != address(0),
            "P301: CUSTODIAN env missing"
        );

        require(
            target.isCustodianAddress(custodian),
            "P301: custodian verification failed"
        );

        return custodian;
    }

    function _order(
        address wallet,
        uint128 collateralAmount,
        uint128 usdeAmount
    )
        internal
        view
        returns (IMintingP301.Order memory order)
    {
        order = IMintingP301.Order({
            order_id: "P301-WETH-ACCOUNTING",
            order_type: IMintingP301.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: uint128(301001),
            benefactor: wallet,
            beneficiary: wallet,
            collateral_asset: WETH,
            collateral_amount: collateralAmount,
            usde_amount: usdeAmount
        });
    }

    function _route()
        internal
        view
        returns (IMintingP301.Route memory route)
    {
        address[] memory addresses =
            new address[](1);

        uint128[] memory ratios =
            new uint128[](1);

        addresses[0] = _custodian();
        ratios[0] = 10_000;

        route = IMintingP301.Route({
            addresses: addresses,
            ratios: ratios
        });
    }

    function _signature()
        internal
        pure
        returns (IMintingP301.Signature memory sig)
    {
        sig = IMintingP301.Signature({
            signature_type:
                IMintingP301.SignatureType.EIP1271,
            signature_bytes:
                hex"503330312d574554482d4143434f554e54494e47"
        });
    }

    function test_P301_WETH_AccountingInvariant()
        external
    {
        _fork();

        address minter = _minter();
        address custodian = _custodian();

        emit log_named_address(
            "P301 verified MINTER",
            minter
        );

        emit log_named_address(
            "P301 verified CUSTODIAN",
            custodian
        );

        P301Valid1271Wallet wallet =
            new P301Valid1271Wallet();

        vm.prank(target.owner());

        target.addWhitelistedBenefactor(
            address(wallet)
        );

        uint256 collateral = 1 ether;
        uint256 usdeAmount = 1 ether;

        vm.deal(
            address(wallet),
            collateral
        );

        wallet.executeValue{
            value: collateral
        }(
            WETH,
            abi.encodeWithSelector(
                IWETHP301.deposit.selector
            )
        );

        wallet.execute(
            WETH,
            abi.encodeWithSelector(
                IWETHP301.approve.selector,
                MINTING,
                type(uint256).max
            )
        );

        assertEq(
            weth.balanceOf(address(wallet)),
            collateral,
            "P301: initial WETH mismatch"
        );

        IMintingP301.Order memory order =
            _order(
                address(wallet),
                uint128(collateral),
                uint128(usdeAmount)
            );

        wallet.setApprovedDigest(
            target.hashOrder(order)
        );

        IMintingP301.Route memory route =
            _route();

        IMintingP301.Signature memory sig =
            _signature();

        assertTrue(
            target.verifyRoute(route),
            "P301: valid route rejected"
        );

        target.verifyOrder(
            order,
            sig
        );

        uint256 wethBefore =
            weth.balanceOf(address(wallet));

        uint256 custodianEthBefore =
            custodian.balance;

        uint256 usdeBefore =
            usde.balanceOf(address(wallet));

        vm.prank(minter);

        target.mintWETH(
            order,
            route,
            sig
        );

        uint256 wethAfter =
            weth.balanceOf(address(wallet));

        uint256 custodianEthAfter =
            custodian.balance;

        uint256 usdeAfter =
            usde.balanceOf(address(wallet));

        assertEq(
            wethBefore - wethAfter,
            collateral,
            "P301 ALERT: WETH accounting mismatch"
        );

        assertEq(
            custodianEthAfter - custodianEthBefore,
            collateral,
            "P301 ALERT: ETH custody mismatch"
        );

        assertEq(
            usdeAfter - usdeBefore,
            usdeAmount,
            "P301 ALERT: USDe mint mismatch"
        );

        assertEq(
            wethAfter,
            0,
            "P301 ALERT: residual WETH"
        );

        emit log_string(
            "P301 PASS: WETH -> ETH -> USDe accounting invariant holds"
        );
    }
}
