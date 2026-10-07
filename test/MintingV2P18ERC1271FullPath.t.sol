// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function prank(address msgSender) external;

    function startPrank(address msgSender) external;

    function stopPrank() external;

    function store(
        address target,
        bytes32 slot,
        bytes32 value
    ) external;
}

interface IERC20P18 {
    function balanceOf(address account)
        external
        view
        returns (uint256);

    function approve(
        address spender,
        uint256 amount
    )
        external
        returns (bool);
}

interface IEthenaMintingP18 {

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

    function owner()
        external
        view
        returns (address);

    function hasRole(
        bytes32 role,
        address account
    )
        external
        view
        returns (bool);

    function addWhitelistedBenefactor(
        address benefactor
    )
        external;

    function hashOrder(
        Order calldata order
    )
        external
        view
        returns (bytes32);

    function verifyOrder(
        Order calldata order,
        Signature calldata signature
    )
        external
        view
        returns (bytes32);

    function verifyRoute(
        Route calldata route
    )
        external
        view
        returns (bool);

    function mint(
        Order calldata order,
        Route calldata route,
        Signature calldata signature
    )
        external;
}

contract P18Valid1271Wallet {

    bytes4 internal constant MAGICVALUE =
        0x1626ba7e;

    bytes4 internal constant FAILVALUE =
        0xffffffff;

    bytes32 public approvedDigest;

    function setApprovedDigest(
        bytes32 digest
    )
        external
    {
        approvedDigest = digest;
    }

    function execute(
        address target,
        bytes calldata data
    )
        external
        returns (bytes memory)
    {
        (
            bool ok,
            bytes memory ret
        ) =
            target.call(data);

        require(
            ok,
            "wallet execute failed"
        );

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
        if (
            hash ==
            approvedDigest
        ) {
            return MAGICVALUE;
        }

        return FAILVALUE;
    }
}

contract MintingV2P18ERC1271FullPathTest {

    address constant MINTING =
        0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant MINTER =
        0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    address constant CUSTODIAN =
        0x8f0eE0393Eae7fc1638BD7860a3FEc6a663786AE;

    Vm constant vm =
        Vm(
            address(
                uint160(
                    uint256(
                        keccak256(
                            "hevm cheat code"
                        )
                    )
                )
            )
        );

    IEthenaMintingP18 constant target =
        IEthenaMintingP18(
            MINTING
        );

    IERC20P18 constant usdc =
        IERC20P18(
            USDC
        );

    function assertTrue(
        bool value,
        string memory reason
    )
        internal
        pure
    {
        require(
            value,
            reason
        );
    }

    function assertEq(
        uint256 a,
        uint256 b,
        string memory reason
    )
        internal
        pure
    {
        require(
            a == b,
            reason
        );
    }

    function _minterRole()
        internal
        pure
        returns (bytes32)
    {
        return keccak256("MINTER_ROLE");
    }

    function _assertMinterAuthorized()
        internal
        view
    {
        assertTrue(
            target.hasRole(
                _minterRole(),
                MINTER
            ),
            "local MINTER_ROLE was not granted"
        );
    }

    function _authorize(
        address wallet
    )
        internal
    {
        address owner =
            target.owner();

        vm.prank(
            owner
        );

        target.addWhitelistedBenefactor(
            wallet
        );
    }

    function _order(
        address wallet,
        uint128 nonce
    )
        internal
        view
        returns (
            IEthenaMintingP18.Order memory o
        )
    {
        o =
            IEthenaMintingP18.Order({

                order_id:
                    "P18-1271-FULL-PATH",

                order_type:
                    IEthenaMintingP18.OrderType.MINT,

                expiry:
                    uint120(
                        block.timestamp +
                        1 days
                    ),

                nonce:
                    nonce,

                benefactor:
                    wallet,

                beneficiary:
                    MINTER,

                collateral_asset:
                    USDC,

                collateral_amount:
                    999_900_001,

                usde_amount:
                    1_000e18
            });
    }

    function _route(
        address destination
    )
        internal
        pure
        returns (
            IEthenaMintingP18.Route memory r
        )
    {
        address[] memory addresses =
            new address[](1);

        uint128[] memory ratios =
            new uint128[](1);

        addresses[0] =
            destination;

        ratios[0] =
            10_000;

        r =
            IEthenaMintingP18.Route({

                addresses:
                    addresses,

                ratios:
                    ratios
            });
    }

    function _sig()
        internal
        pure
        returns (
            IEthenaMintingP18.Signature memory s
        )
    {
        s =
            IEthenaMintingP18.Signature({

                signature_type:
                    IEthenaMintingP18.SignatureType.EIP1271,

                signature_bytes:
                    hex"5031382d54455354"
            });
    }

    function _fundAndApprove(
        P18Valid1271Wallet wallet,
        uint256 amount
    )
        internal
    {
        bytes32 slot =
            keccak256(
                abi.encode(
                    address(wallet),
                    uint256(9)
                )
            );

        vm.store(
            USDC,
            slot,
            bytes32(amount)
        );

        assertEq(
            usdc.balanceOf(
                address(wallet)
            ),
            amount,
            "wallet USDC funding failed"
        );

        wallet.execute(
            USDC,
            abi.encodeWithSelector(
                IERC20P18.approve.selector,
                MINTING,
                type(uint256).max
            )
        );
    }

    function test_P18_eip1271_full_mint_path_passes()
        external
    {
        P18Valid1271Wallet wallet =
            new P18Valid1271Wallet();

        _authorize(
            address(wallet)
        );

        uint256 collateral =
            999_900_001;

        _fundAndApprove(
            wallet,
            collateral
        );

        IEthenaMintingP18.Order memory order =
            _order(
                address(wallet),
                18001001
            );

        wallet.setApprovedDigest(
            target.hashOrder(
                order
            )
        );

        IEthenaMintingP18.Route memory route =
            _route(
                CUSTODIAN
            );

        IEthenaMintingP18.Signature memory sig =
            _sig();

        assertTrue(
            target.verifyRoute(
                route
            ),
            "valid custodian route rejected"
        );

        target.verifyOrder(
            order,
            sig
        );

        _assertMinterAuthorized();

        vm.startPrank(
            MINTER
        );

        target.mint(
            order,
            route,
            sig
        );

        vm.stopPrank();

        assertEq(
            usdc.balanceOf(
                address(wallet)
            ),
            0,
            "wallet collateral was not transferred"
        );
    }

    function test_P18_mutated_route_cannot_redirect_full_mint()
        external
    {
        P18Valid1271Wallet wallet =
            new P18Valid1271Wallet();

        _authorize(
            address(wallet)
        );

        uint256 collateral =
            999_900_001;

        _fundAndApprove(
            wallet,
            collateral
        );

        IEthenaMintingP18.Order memory order =
            _order(
                address(wallet),
                18001002
            );

        wallet.setApprovedDigest(
            target.hashOrder(
                order
            )
        );

        IEthenaMintingP18.Route memory malicious =
            _route(
                address(0xbeef)
            );

        IEthenaMintingP18.Signature memory sig =
            _sig();

        assertTrue(
            !target.verifyRoute(
                malicious
            ),
            "malicious route unexpectedly passed route guard"
        );

        _assertMinterAuthorized();

        vm.startPrank(
            MINTER
        );

        (bool ok,) =
            MINTING.call(
                abi.encodeWithSelector(
                    target.mint.selector,
                    order,
                    malicious,
                    sig
                )
            );

        vm.stopPrank();

        assertTrue(
            !ok,
            "mutated route reached full mint"
        );

        assertEq(
            usdc.balanceOf(
                address(wallet)
            ),
            collateral,
            "wallet collateral changed despite rejected route"
        );
    }
}
