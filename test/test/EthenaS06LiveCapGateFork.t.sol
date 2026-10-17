
 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IEthenaS06Gate {
    enum SignatureType { EIP712, EIP1271 }
    enum OrderType { MINT, REDEEM }

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
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);

    function tokenConfig(address asset)
        external view
        returns (uint8 tokenType, bool active, uint128 maxMintPerBlock, uint128 maxRedeemPerBlock);

    function globalConfig()
        external view
        returns (uint128 globalMaxMintPerBlock, uint128 globalMaxRedeemPerBlock);

    function mintWETH(Order calldata order, Route calldata route, Signature calldata signature) external;
}

contract EthenaS06LiveCapGateForkTest is Test {
    address constant MINTING = 0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant CUSTODIAN = 0x12FDB344e4D195fF6613D0f742a6E38344c8b455;
    address constant MINTER = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    IEthenaS06Gate target = IEthenaS06Gate(MINTING);

    function _prepareFork() internal {
        uint256 forkId = vm.createFork(vm.envString("ETHENA_FORK_RPC"));
        vm.selectFork(forkId);

        require(MINTING.code.length > 0, "Minting V2 code missing");
        require(WETH.code.length > 0, "WETH code missing");

        address admin = target.owner();
        vm.prank(admin);
        target.grantRole(keccak256("MINTER_ROLE"), MINTER);

        require(
            target.hasRole(keccak256("MINTER_ROLE"), MINTER),
            "Local fork MINTER_ROLE grant failed"
        );
    }

    function _route() internal pure returns (IEthenaS06Gate.Route memory r) {
        address[] memory destinations = new address[](1);
        uint128[] memory ratios = new uint128[](1);
        destinations[0] = CUSTODIAN;
        ratios[0] = 10_000;
        r = IEthenaS06Gate.Route({addresses: destinations, ratios: ratios});
    }

    function _order(uint128 usdeAmount)
        internal view returns (IEthenaS06Gate.Order memory o)
    {
        o = IEthenaS06Gate.Order({
            order_id: "S06-CAP-GATE-LOCAL-TEST",
            order_type: IEthenaS06Gate.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: 987654321,
            benefactor: address(this),
            beneficiary: address(this),
            collateral_asset: WETH,
            collateral_amount: 1,
            usde_amount: usdeAmount
        });
    }

    function _callMint(uint128 usdeAmount)
        internal returns (bool ok, bytes memory data)
    {
        IEthenaS06Gate.Order memory o = _order(usdeAmount);
        IEthenaS06Gate.Signature memory s = IEthenaS06Gate.Signature({
            signature_type: IEthenaS06Gate.SignatureType.EIP712,
            signature_bytes: hex"01"
        });

        vm.prank(MINTER);
        (ok, data) = MINTING.call(
            abi.encodeWithSelector(
                IEthenaS06Gate.mintWETH.selector,
                o,
                _route(),
                s
            )
        );
    }

    function _selector(bytes memory data) internal pure returns (bytes4 sel) {
        if (data.length < 4) return bytes4(0);
        assembly {
            sel := mload(add(data, 32))
        }
    }

    function test_S06_AboveCapHitsCapGateBeforeInvalidSignature() external {
        _prepareFork();

        (, bool active, uint128 assetMintCap,) = target.tokenConfig(WETH);
        (uint128 globalMintCap,) = target.globalConfig();

        assertTrue(active, "WETH token config is inactive");
        assertGt(assetMintCap, 0, "WETH asset mint cap is zero");
        assertGt(globalMintCap, 0, "Global mint cap is zero");

        uint128 highestCap = assetMintCap > globalMintCap
            ? assetMintCap
            : globalMintCap;

        assertLt(highestCap, type(uint128).max, "Cannot safely add one to cap");
        uint128 aboveBothCaps = highestCap + 1;

        // Control: below cap, the deliberately invalid signature should reject.
        (bool controlOk, bytes memory controlData) = _callMint(1);
        assertFalse(controlOk, "Control call unexpectedly succeeded");
        assertGe(controlData.length, 4, "Control revert has no selector");

        // Test: above both configured caps should reject at a different gate.
        (bool capOk, bytes memory capData) = _callMint(aboveBothCaps);
        assertFalse(capOk, "Above-cap mint unexpectedly succeeded");
        assertGe(capData.length, 4, "Above-cap revert has no selector");

        bytes4 controlSelector = _selector(controlData);
        bytes4 capSelector = _selector(capData);

        emit log_named_bytes32("Control revert selector", bytes32(controlSelector));
        emit log_named_bytes32("Above-cap revert selector", bytes32(capSelector));
        emit log_named_uint("WETH asset mint cap", assetMintCap);
        emit log_named_uint("Global mint cap", globalMintCap);
        emit log_named_uint("Above-both-caps request", aboveBothCaps);

        assertTrue(
            capSelector != controlSelector,
            "No evidence cap gate runs before invalid-signature rejection"
        );
    }
}
