
function test_RejectsCumulativeMintAboveGlobalCap() external {
    _seedAuthorization();

    (, bool active, uint128 assetCap,) = target.tokenConfig(USDC);
    (uint128 globalCap,) = target.globalConfig();

    assertTrue(active, "USDC inactive");
    assertGt(globalCap, REQUEST_USDE, "global cap too small");
    assertGt(assetCap, REQUEST_USDE, "asset cap too small");

    // Asset counter remains zero, far below its cap.
    _seedAssetCounter(0);

    // The next request would push the global counter above its cap.
    _seedGlobalCounter(globalCap - REQUEST_USDE + 1);

    _assertRejectedByCap(906102);
}
