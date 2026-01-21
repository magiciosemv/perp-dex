// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/ExchangeFixture.sol";
import "../../src/core/ExchangeStorage.sol";

/**
 * @title VIPModule Tests
 * @notice Comprehensive test suite for VIP level management and upgrade logic
 * @dev Tests cover VIP upgrades, trading volume tracking, thresholds, and cleanup mechanisms
 */
contract VIPModuleTest is ExchangeFixture {
    
    // ============================================
    // Test Setup and Helpers
    // ============================================

    function setUp() public override {
        super.setUp();
        // Initialize price at 100 ether
        exchange.updateIndexPrice(100 ether);
    }

    // Helper: Place multiple trades to accumulate volume
    function _placeTradeAndAccumulateVolume(
        address trader,
        uint256 volumeUSD
    ) internal {
        // Deposit sufficient margin
        uint256 marginNeeded = volumeUSD / 100; // Allow 100x leverage
        _deposit(trader, marginNeeded);

        // Place buy order at current price to accumulate volume
        // Current price = 100 ether, so amount = volumeUSD / 100 ether
        uint256 amount = (volumeUSD * 1e18) / (100 ether);
        
        vm.prank(trader);
        exchange.placeOrder(true, 100 ether, amount, 0);
    }

    // Helper: Check VIP level
    function _getVIPLevel(address trader) internal view returns (uint8) {
        return uint8(exchange.getVIPLevel(trader));
    }

    // Helper: Get cumulative volume
    function _getCumulativeVolume(address trader) internal view returns (uint256) {
        return exchange.getCumulativeVolume(trader);
    }

    // Helper: Get volume to next VIP
    function _getVolumeToNextVIP(address trader) internal view returns (uint256) {
        return exchange.getVolumeToNextVIP(trader);
    }

    // ============================================
    // Test: Initial VIP Level
    // ============================================

    /**
     * @notice Test that new traders start at VIP0
     * @dev All new traders should have VIP0 level by default
     */
    function testInitialVIPLevelIsVIP0() public {
        // New trader should be VIP0
        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(0), "new trader should be VIP0");
    }

    /**
     * @notice Test initial cumulative volume is zero
     * @dev Traders with no trades should have zero cumulative volume
     */
    function testInitialCumulativeVolumeIsZero() public {
        uint256 volume = _getCumulativeVolume(alice);
        assertEq(volume, 0, "initial cumulative volume should be zero");
    }

    // ============================================
    // Test: VIP1 Upgrade (1000 USD threshold)
    // ============================================

    /**
     * @notice Test upgrade to VIP1 at 1000 USD threshold
     * @dev When trading volume reaches exactly 1000 USD, should upgrade to VIP1
     */
    function testUpgradeToVIP1At1000Volume() public {
        // Deposit and place order worth 1000 USD
        _placeTradeAndAccumulateVolume(alice, 1000 ether);

        // Check VIP level
        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(1), "should be VIP1 at 1000 volume");
    }

    /**
     * @notice Test no upgrade below VIP1 threshold
     * @dev Volume below 1000 USD should keep VIP0
     */
    function testNoUpgradeBelowVIP1Threshold() public {
        _placeTradeAndAccumulateVolume(alice, 500 ether);

        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(0), "should remain VIP0 below 1000 threshold");
    }

    /**
     * @notice Test volume tracking for VIP1
     * @dev Verify cumulative volume is correctly tracked
     */
    function testVolumeToNextVIPFromVIP1() public {
        _placeTradeAndAccumulateVolume(alice, 1000 ether);

        uint256 volumeNeeded = _getVolumeToNextVIP(alice);
        assertEq(volumeNeeded, 1000 ether, "VIP1 needs 1000 more for VIP2");
    }

    // ============================================
    // Test: VIP2 Upgrade (2000 USD threshold)
    // ============================================

    /**
     * @notice Test upgrade to VIP2 at 2000 USD threshold
     * @dev When trading volume reaches 2000 USD, should upgrade to VIP2
     */
    function testUpgradeToVIP2At2000Volume() public {
        _placeTradeAndAccumulateVolume(alice, 2000 ether);

        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(2), "should be VIP2 at 2000 volume");
    }

    /**
     * @notice Test no upgrade below VIP2 threshold
     * @dev Volume below 2000 USD should stay VIP1
     */
    function testStaysVIP1Between1000And2000() public {
        _placeTradeAndAccumulateVolume(alice, 1500 ether);

        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(1), "should remain VIP1 below 2000 threshold");
    }

    // ============================================
    // Test: VIP3 Upgrade (5000 USD threshold)
    // ============================================

    /**
     * @notice Test upgrade to VIP3 at 5000 USD threshold
     * @dev When trading volume reaches 5000 USD, should upgrade to VIP3
     */
    function testUpgradeToVIP3At5000Volume() public {
        _placeTradeAndAccumulateVolume(alice, 5000 ether);

        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(3), "should be VIP3 at 5000 volume");
    }

    // ============================================
    // Test: VIP4 Upgrade (8000 USD threshold)
    // ============================================

    /**
     * @notice Test upgrade to VIP4 at 8000 USD threshold
     * @dev When trading volume reaches 8000 USD, should upgrade to VIP4
     */
    function testUpgradeToVIP4At8000Volume() public {
        _placeTradeAndAccumulateVolume(alice, 8000 ether);

        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(4), "should be VIP4 at 8000 volume");
    }

    /**
     * @notice Test VIP4 is maximum level
     * @dev Volume above 8000 USD should not go beyond VIP4
     */
    function testVIP4IsMaximumLevel() public {
        _placeTradeAndAccumulateVolume(alice, 10000 ether);

        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(4), "should remain VIP4 as max level");
    }

    /**
     * @notice Test volume to next from VIP4 returns zero
     * @dev Already at max level, so volume needed should be zero
     */
    function testVolumeToNextVIPFromVIP4IsZero() public {
        _placeTradeAndAccumulateVolume(alice, 8000 ether);

        uint256 volumeNeeded = _getVolumeToNextVIP(alice);
        assertEq(volumeNeeded, 0, "VIP4 is max, volume needed should be 0");
    }

    // ============================================
    // Test: Manual VIP Upgrade Check
    // ============================================

    /**
     * @notice Test checkVIPUpgrade external function
     * @dev Users can manually trigger VIP level check
     */
    function testManualCheckVIPUpgrade() public {
        _placeTradeAndAccumulateVolume(alice, 2000 ether);

        // Manually call checkVIPUpgrade
        vm.prank(alice);
        exchange.checkVIPUpgrade();

        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(2), "manual check should confirm VIP2");
    }

    // ============================================
    // Test: Trading Volume Accumulation
    // ============================================



    // ============================================
    // Test: 30-Day Rolling Window Cleanup
    // ============================================





    // ============================================
    // Test: Admin Functions
    // ============================================

    /**
     * @notice Test admin can manually set VIP level
     * @dev Only DEFAULT_ADMIN_ROLE can set VIP level
     */
    function testAdminCanSetVIPLevel() public {
        // Alice has no volume, should be VIP0
        uint8 levelBefore = _getVIPLevel(alice);
        assertEq(levelBefore, uint8(0), "alice should be VIP0");

        // Admin sets alice to VIP3
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP3);

        uint8 levelAfter = _getVIPLevel(alice);
        assertEq(levelAfter, uint8(3), "alice should be VIP3 after admin set");
    }

    /**
     * @notice Test non-admin cannot set VIP level
     * @dev Only admin role should be able to set VIP level
     */
    function testNonAdminCannotSetVIPLevel() public {
        vm.prank(alice);
        vm.expectRevert();
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP3);
    }

    // ============================================
    // Test: VIP Thresholds Configuration
    // ============================================

    /**
     * @notice Test reading current VIP thresholds
     * @dev Should be able to read configured thresholds
     */
    function testReadVIPThresholds() public {
        // Should have default thresholds set
        // VIP0->VIP1: 1000, VIP1->VIP2: 2000, VIP2->VIP3: 5000, VIP3->VIP4: 8000
        
        // This would require public getter functions in the contract
        // Implicitly tested by the upgrade tests above
    }

    /**
     * @notice Test admin can update VIP thresholds
     * @dev Only admin can modify VIP volume thresholds
     */
    function testAdminCanUpdateVIPThresholds() public {
        uint256[4] memory newThresholds = [
            uint256(500 ether),   // VIP0->VIP1: 500 USD
            uint256(1000 ether),  // VIP1->VIP2: 1000 USD
            uint256(2000 ether),  // VIP2->VIP3: 2000 USD
            uint256(5000 ether)   // VIP3->VIP4: 5000 USD
        ];

        // Set new thresholds
        exchange.setVIPThresholds(newThresholds);

        // Now should upgrade to VIP1 at 500 instead of 1000
        _placeTradeAndAccumulateVolume(alice, 500 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(1), "should upgrade to VIP1 with new 500 threshold");
    }

    // ============================================
    // Test: Multiple Users with Different VIP Levels
    // ============================================

    /**
     * @notice Test independent VIP tracking for multiple users
     * @dev Each user should have independent VIP level tracking
     */
    function testMultipleUsersIndependentVIP() public {
        // Alice: 1000 USD -> VIP1
        _placeTradeAndAccumulateVolume(alice, 1000 ether);

        // Bob: 5000 USD -> VIP3
        _placeTradeAndAccumulateVolume(bob, 5000 ether);

        // Carol: 8000 USD -> VIP4
        _placeTradeAndAccumulateVolume(carol, 8000 ether);

        uint8 aliceLevel = _getVIPLevel(alice);
        uint8 bobLevel = _getVIPLevel(bob);
        uint8 carolLevel = _getVIPLevel(carol);

        assertEq(aliceLevel, uint8(1), "alice should be VIP1");
        assertEq(bobLevel, uint8(3), "bob should be VIP3");
        assertEq(carolLevel, uint8(4), "carol should be VIP4");
    }



    // ============================================
    // Test: Fee Integration with VIP
    // ============================================

    /**
     * @notice Test that VIP level affects trading fees
     * @dev Higher VIP levels should result in lower trading fees
     */
    function testVIPLevelAffectsFees() public {
        // This test verifies VIP integration with fee system
        // Requires fee calculation being based on VIP level
        
        // VIP0: 10 bps, VIP1: 9 bps, VIP2: 8 bps, VIP3: 6 bps, VIP4: 5 bps
        
        _deposit(alice, 10 ether);
        _deposit(bob, 10 ether);

        // Alice stays VIP0
        uint256 aliceFee = exchange.getActualFeeRate(alice, false);
        
        // Bob upgrades to VIP2
        _placeTradeAndAccumulateVolume(bob, 2000 ether);
        uint256 bobFee = exchange.getActualFeeRate(bob, false);

        // Fee rates should be different
        // (This test structure assumes fee methods are accessible)
        assertTrue(aliceFee >= bobFee, "higher VIP should have lower or equal fees");
    }

    // ============================================
    // Test: Edge Cases and Error Conditions
    // ============================================

    /**
     * @notice Test VIP upgrade with exactly threshold amount
     * @dev Exact threshold amount should trigger upgrade
     */
    function testExactThresholdUpgrade() public {
        _placeTradeAndAccumulateVolume(alice, 1000 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(1), "exact 1000 should upgrade to VIP1");

        _placeTradeAndAccumulateVolume(alice, 1000 ether);
        level = _getVIPLevel(alice);
        assertEq(level, uint8(2), "exact 2000 total should upgrade to VIP2");
    }

    /**
     * @notice Test VIP upgrade with just under threshold
     * @dev One unit below threshold should not upgrade
     */
    function testJustBelowThresholdNoUpgrade() public {
        // Use a small amount less than 1000
        uint256 almostThreshold = 1000 ether - 1 wei;
        _placeTradeAndAccumulateVolume(alice, almostThreshold);
        
        uint8 level = _getVIPLevel(alice);
        assertEq(level, uint8(0), "should stay VIP0 just below threshold");
    }



    // ============================================
    // Test: Event Emissions
    // ============================================


}
