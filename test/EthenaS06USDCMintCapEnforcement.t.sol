
function _seedLocalWhitelistAndApproval() internal {
    bytes32 member = bytes32(uint256(uint160(MINTER)));

    // EnumerableSet at slot 4:
    // _values length = slot 4
    // _values data = keccak256(abi.encode(4))
    // _positions mapping = slot 5
    bytes32 whitelistData =
        keccak256(abi.encode(uint256(4)));

    bytes32 whitelistIndex =
        keccak256(abi.encode(member, uint256(5)));

    vm.store(MINTING, bytes32(uint256(4)), bytes32(uint256(1)));
    vm.store(MINTING, whitelistData, member);
    vm.store(MINTING, whitelistIndex, bytes32(uint256(1)));

    // Beneficiary set nested under mapping at slot 6.
    uint256 setBase =
        uint256(keccak256(abi.encode(MINTER, uint256(6))));

    bytes32 approvedData =
        keccak256(abi.encode(setBase));

    bytes32 approvedIndex =
        keccak256(abi.encode(member, setBase + 1));

    vm.store(
        MINTING,
        bytes32(setBase),
        bytes32(uint256(1))
    );
    vm.store(MINTING, approvedData, member);
    vm.store(MINTING, approvedIndex, bytes32(uint256(1)));

    assertTrue(
        target.isWhitelistedBenefactor(MINTER),
        "Local setup: benefactor not whitelisted"
    );

    assertTrue(
        target.isApprovedBeneficiary(MINTER, MINTER),
        "Local setup: beneficiary not approved"
    );
}
