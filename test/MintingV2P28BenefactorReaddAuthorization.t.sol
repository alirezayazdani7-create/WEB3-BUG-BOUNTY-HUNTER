// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function prank(address msgSender) external;
    function sign(uint256 privateKey, bytes32 digest)
        external returns (uint8 v, bytes32 r, bytes32 s);
    function store(address target, bytes32 slot, bytes32 value) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUSDe {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
    function minter() external view returns (address);
}

interface IEthenaMinting {
    enum OrderType { MINT, REDEEM }
    enum SignatureType { EIP712, EIP1271 }
    enum DelegatedSignerStatus { REJECTED, PENDING, ACCEPTED }

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

    struct Signature {
        SignatureType signature_type;
        bytes signature_bytes;
    }

    function owner() external view returns (address);
    function addWhitelistedBenefactor(address) external;
    function removeWhitelistedBenefactor(address) external;
    function grantRole(bytes32, address) external;
    function setDelegatedSigner(address) external;
    function confirmDelegatedSigner(address) external;
    function setApprovedBeneficiary(address, bool) external;
    function delegatedSigner(address, address)
        external view returns (DelegatedSignerStatus);
    function isApprovedBeneficiary(address, address) external view returns (bool);
    function hashOrder(Order calldata) external view returns (bytes32);
    function verifyOrder(Order calldata, Signature calldata)
        external view returns (bytes32);
    function redeem(Order calldata, Signature calldata) external;
}

contract MintingV2P28BenefactorReaddAuthorizationTest {
    address constant MINTING = 0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;
    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    IEthenaMinting constant target = IEthenaMinting(MINTING);
    IUSDe constant usde = IUSDe(USDE);
    IERC20 constant usdc = IERC20(USDC);

    function assertTrue(bool v, string memory r) internal pure { require(v, r); }
    function assertEq(uint256 a, uint256 b, string memory r) internal pure { require(a == b, r); }

    function _redeemerRole() internal pure returns (bytes32) {
        return keccak256("REDEEMER_ROLE");
    }

    function _fundBenefactor(address b, uint256 amount) internal {
        vm.prank(usde.minter());
        usde.mint(b, amount);
        assertEq(usde.balanceOf(b), amount, "USDe local mint failed");
        vm.prank(b);
        require(usde.approve(MINTING, type(uint256).max), "USDe approve failed");
    }

    function _fundMintingUSDC(uint256 amount) internal {
        bytes32 slot = keccak256(abi.encode(MINTING, uint256(9)));
        vm.store(USDC, slot, bytes32(amount));
        assertEq(usdc.balanceOf(MINTING), amount, "USDC funding failed");
    }

    function _order(address b, address beneficiary, uint128 nonce)
        internal view returns (IEthenaMinting.Order memory o)
    {
        o = IEthenaMinting.Order({
            order_id: "P28-BENEFACTOR-READD",
            order_type: IEthenaMinting.OrderType.REDEEM,
            expiry: uint120(block.timestamp + 1 days),
            nonce: nonce,
            benefactor: b,
            beneficiary: beneficiary,
            collateral_asset: USDC,
            collateral_amount: 999900,
            usde_amount: 1e18
        });
    }

    function _sig(uint256 key, bytes32 digest)
        internal returns (IEthenaMinting.Signature memory s)
    {
        (uint8 v, bytes32 r, bytes32 ss) = vm.sign(key, digest);
        s = IEthenaMinting.Signature({
            signature_type: IEthenaMinting.SignatureType.EIP712,
            signature_bytes: abi.encodePacked(r, ss, v)
        });
    }

    function _mustFail(IEthenaMinting.Order memory o, IEthenaMinting.Signature memory s)
        internal view
    {
        (bool ok,) = MINTING.staticcall(
            abi.encodeWithSelector(target.verifyOrder.selector, o, s)
        );
        assertTrue(!ok, "authorization unexpectedly remained valid");
    }

    function test_P28_remove_readd_revives_old_delegate_and_beneficiary_authorization()
        external
    {
        address benefactor = vm.addr(10);
        address delegate = vm.addr(11);
        address beneficiary = vm.addr(12);

        vm.prank(target.owner());
        target.addWhitelistedBenefactor(benefactor);

        vm.prank(target.owner());
        target.grantRole(_redeemerRole(), benefactor);

        _fundBenefactor(benefactor, 1e18);
        _fundMintingUSDC(999900);

        vm.prank(benefactor);
        target.setDelegatedSigner(delegate);

        vm.prank(delegate);
        target.confirmDelegatedSigner(benefactor);

        vm.prank(benefactor);
        target.setApprovedBeneficiary(beneficiary, true);

        IEthenaMinting.Order memory oldOrder =
            _order(benefactor, beneficiary, 28001001);
        IEthenaMinting.Signature memory oldSignature =
            _sig(11, target.hashOrder(oldOrder));

        target.verifyOrder(oldOrder, oldSignature);

        vm.prank(target.owner());
        target.removeWhitelistedBenefactor(benefactor);

        _mustFail(oldOrder, oldSignature);

        vm.prank(target.owner());
        target.addWhitelistedBenefactor(benefactor);

        assertTrue(
            uint8(target.delegatedSigner(delegate, benefactor)) ==
                uint8(IEthenaMinting.DelegatedSignerStatus.ACCEPTED),
            "delegate state was cleared"
        );

        assertTrue(
            target.isApprovedBeneficiary(benefactor, beneficiary),
            "beneficiary state was cleared"
        );

        target.verifyOrder(oldOrder, oldSignature);

        uint256 usdeBefore = usde.balanceOf(benefactor);
        uint256 usdcBefore = usdc.balanceOf(beneficiary);

        vm.prank(benefactor);
        target.redeem(oldOrder, oldSignature);

        assertEq(usde.balanceOf(benefactor), usdeBefore - 1e18,
            "old authorization did not execute");
        assertEq(usdc.balanceOf(beneficiary), usdcBefore + 999900,
            "collateral did not reach old beneficiary");
    }

    function test_P28_delegate_removal_still_invalidates_authorization()
        external
    {
        address benefactor = vm.addr(20);
        address delegate = vm.addr(21);

        vm.prank(target.owner());
        target.addWhitelistedBenefactor(benefactor);

        vm.prank(benefactor);
        target.setDelegatedSigner(delegate);

        vm.prank(delegate);
        target.confirmDelegatedSigner(benefactor);

        IEthenaMinting.Order memory o =
            _order(benefactor, benefactor, 28001002);

        IEthenaMinting.Signature memory s =
            _sig(21, target.hashOrder(o));

        target.verifyOrder(o, s);

        vm.prank(benefactor);
        target.removeDelegatedSigner(delegate);

        _mustFail(o, s);
    }
}
