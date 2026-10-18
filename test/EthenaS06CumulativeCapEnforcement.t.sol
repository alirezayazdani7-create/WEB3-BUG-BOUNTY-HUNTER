
    function _buildOrderWithNonce(uint128 nonce, string memory orderId)
        internal
        view
        returns (IS06CumulativeProbe.Order memory)
    {
        return IS06CumulativeProbe.Order({
            order_id: orderId,
            order_type: IS06CumulativeProbe.OrderType.MINT,
            expiry: uint120(block.timestamp + 1 days),
            nonce: nonce,
            benefactor: MINTER,
            beneficiary: MINTER,
            collateral_asset: USDC,
            collateral_amount: COLLATERAL_USDC,
            usde_amount: REQUEST_USDE
        });
    }

    function _submitMint(uint128 nonce, string memory orderId)
        internal
        returns (bool success, bytes memory data)
    {
        IS06CumulativeProbe.Order memory order =
            _buildOrderWithNonce(nonce, orderId);
        IS06CumulativeProbe.Route memory route = _buildRoute();
        IS06CumulativeProbe.Signature memory sig = _signOrder(order);

        vm.prank(MINTER);
        (success, data) = MINTING.call(
            abi.encodeWithSelector(
                IS06CumulativeProbe.mint.selector,
                order,
                route,
                sig
            )
        );
    }

    function test_RealMintIncrementsCumulativeCountersAndNextBlockStartsFresh()
        external
    {
        _seedAuthorization();

        (, bool active, uint128 assetCap,) = target.tokenConfig(USDC);
        (uint128 globalCap,) = target.globalConfig();

        assertTrue(active, "USDC inactive");
        assertGt(
            assetCap,
            REQUEST_USDE * 2,
            "asset cap too small for two mints"
        );
        assertGt(
            globalCap,
            REQUEST_USDE * 2,
            "global cap too small for two mints"
        );

        uint128 assetSeed = assetCap - REQUEST_USDE * 2;
        uint128 globalSeed = globalCap - REQUEST_USDE * 2;

        _seedAssetCounter(assetSeed);
        _seedGlobalCounter(globalSeed);

        // Fund and approve USDC only on the local fork.
        deal(USDC, MINTER, uint256(COLLATERAL_USDC) * 3);

        vm.prank(MINTER);
        require(
            IERC20S06Probe(USDC).approve(
                MINTING,
                type(uint256).max
            ),
            "USDC approval failed"
        );

        (bool ok1, bytes memory err1) =
            _submitMint(906201, "S06-REAL-MINT-1");

        assertTrue(
            ok1,
            string.concat("first local mint failed: ", vm.toString(err1))
        );

        (uint128 globalAfter1,) = target.totalPerBlock(block.number);
        (uint128 assetAfter1,) =
            target.totalPerBlockPerAsset(block.number, USDC);

        assertEq(
            globalAfter1,
            globalSeed + REQUEST_USDE,
            "global counter did not increment after mint 1"
        );
        assertEq(
            assetAfter1,
            assetSeed + REQUEST_USDE,
            "asset counter did not increment after mint 1"
        );

        (bool ok2, bytes memory err2) =
            _submitMint(906202, "S06-REAL-MINT-2");

        assertTrue(
            ok2,
            string.concat("second local mint failed: ", vm.toString(err2))
        );

        (uint128 globalAfter2,) = target.totalPerBlock(block.number);
        (uint128 assetAfter2,) =
            target.totalPerBlockPerAsset(block.number, USDC);

        assertEq(
            globalAfter2,
            globalCap,
            "global counter did not reach cap"
        );
        assertEq(
            assetAfter2,
            assetCap,
            "asset counter did not reach cap"
        );

        (bool ok3, bytes memory err3) =
            _submitMint(906203, "S06-REAL-MINT-3");

        assertFalse(
            ok3,
            "third mint accepted after cap was reached"
        );
        assertGe(err3.length, 4, "third mint has no revert selector");

        bytes4 actual;
        assembly {
            actual := mload(add(err3, 32))
        }

        bytes4 assetError =
            bytes4(keccak256("MaxMintPerBlockExceeded()"));
        bytes4 globalError =
            bytes4(keccak256("GlobalMaxMintPerBlockExceeded()"));

        assertTrue(
            actual == assetError || actual == globalError,
            "third mint did not fail with a cap error"
        );

        uint256 nextBlock = block.number + 1;
        vm.roll(nextBlock);

        (uint128 globalNext,) = target.totalPerBlock(nextBlock);
        (uint128 assetNext,) =
            target.totalPerBlockPerAsset(nextBlock, USDC);

        assertEq(
            globalNext,
            0,
            "global counter not fresh in next block"
        );
        assertEq(
            assetNext,
            0,
            "asset counter not fresh in next block"
        );
    }
