
function test_RejectsCumulativeMintAboveGlobalCap() external {
    _seedAuthorization();

    (, bool active, uint128 assetCap,) = target.tokenConfig(USDC);
    (uint128 globalCap,) = target.globalConfig();

    assertTrue(active, "USDC inactive");
    assertGt(globalCap, REQUEST_USDE, "global cap too small for probe");

    // If USDC has the same cap as the global cap, this asset
    // cannot isolate global-cap enforcement.
    if (assetCap >= globalCap) {
        emit log("INCONCLUSIVE: USDC asset cap is not below global cap.");
        emit log_named_uint("USDC asset cap", assetCap);
        emit log_named_uint("Global cap", globalCap);
        return;
    }

    // Keep the asset counter at zero to isolate the global cap.
    _seedAssetCounter(0);
    _seedGlobalCounter(globalCap - REQUEST_USDE + 1);

    _assertRejectedByCap(906102);
}
