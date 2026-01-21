// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/ExchangeFixture.sol";
import "../../src/core/ExchangeStorage.sol";

/**
 * @title VIPModule Tests - Simplified Version
 * @notice Comprehensive test suite for VIP level management using direct volume updates
 * @dev Tests VIP upgrades directly without complex trade execution
 */
contract VIPModuleSimplifiedTest is ExchangeFixture {
    
    // ============================================
    // Test Setup
    // ============================================

    function setUp() public override {
        super.setUp();
        // Initialize price at 100 ether
        exchange.updateIndexPrice(100 ether);
    }

    // ============================================
    // Helper Functions
    // ============================================

    /**
     * @notice Directly update trading volume for a user (simulates trades)
     * @param trader The trader address
     * @param volumeUSD The volume in USD (using ether as unit: 1 ether = 1000 USD)
     */
    function _addVolume(address trader, uint256 volumeUSD) internal {
        exchange.manuallyUpdateVolume(trader, volumeUSD);
    }

    /**
     * @notice Get VIP level for a trader
     */
    function _getVIPLevel(address trader) internal view returns (uint8) {
        return uint8(exchange.getVIPLevel(trader));
    }

    // ============================================
    // Test: Initial VIP Level
    // ============================================

    function testInitialVIPLevelIsVIP0() public view {
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 0, "new trader should be VIP0");
    }

    // ============================================
    // Test: VIP Upgrades
    // ============================================

    /**
     * @notice Test upgrade to VIP1 at 1000 USD threshold
     */
    function testUpgradeToVIP1At1000Volume() public {
        _addVolume(alice, 1000 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 1, "should be VIP1 at 1000 volume");
    }

    /**
     * @notice Test upgrade to VIP2 at 2000 USD threshold
     */
    function testUpgradeToVIP2At2000Volume() public {
        _addVolume(alice, 2000 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 2, "should be VIP2 at 2000 volume");
    }

    /**
     * @notice Test upgrade to VIP3 at 5000 USD threshold
     */
    function testUpgradeToVIP3At5000Volume() public {
        _addVolume(alice, 5000 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 3, "should be VIP3 at 5000 volume");
    }

    /**
     * @notice Test upgrade to VIP4 at 8000 USD threshold
     */
    function testUpgradeToVIP4At8000Volume() public {
        _addVolume(alice, 8000 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 4, "should be VIP4 at 8000 volume");
    }

    /**
     * @notice Test no upgrade below VIP1 threshold
     */
    function testNoUpgradeBelowVIP1Threshold() public {
        _addVolume(alice, 500 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 0, "should stay VIP0 below 1000");
    }

    /**
     * @notice Test exact threshold upgrade
     */
    function testExactThresholdUpgrade() public {
        _addVolume(alice, 1000 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 1, "should upgrade at exact 1000 threshold");
    }

    /**
     * @notice Test just below threshold no upgrade
     */
    function testJustBelowThresholdNoUpgrade() public {
        _addVolume(alice, 999 ether);
        uint8 level = _getVIPLevel(alice);
        assertEq(level, 0, "should not upgrade below threshold");
    }

    /**
     * @notice Test multiple trades accumulate volume
     */
    function testVolumeAccuracyAcrossTrades() public {
        _addVolume(alice, 500 ether);
        _addVolume(alice, 300 ether);
        _addVolume(alice, 200 ether);

        uint8 level = _getVIPLevel(alice);
        assertEq(level, 1, "should accumulate volume across trades");
    }

    /**
     * @notice Test multiple users have independent VIP levels
     */
    function testMultipleUsersIndependentVIP() public {
        _addVolume(alice, 1000 ether);
        _addVolume(bob, 2000 ether);
        _addVolume(carol, 5000 ether);

        assertEq(_getVIPLevel(alice), 1, "alice should be VIP1");
        assertEq(_getVIPLevel(bob), 2, "bob should be VIP2");
        assertEq(_getVIPLevel(carol), 3, "carol should be VIP3");
    }

    /**
     * @notice Test rapid successive volume updates
     */
    function testRapidSuccessiveVolumes() public {
        for (uint256 i = 0; i < 8; i++) {
            _addVolume(alice, 1000 ether);
        }

        assertEq(_getVIPLevel(alice), 4, "should reach VIP4 after 8000 volume");
    }

    /**
     * @notice Test manual VIP upgrade check
     */
    function testManualCheckVIPUpgrade() public {
        _addVolume(alice, 1000 ether);
        
        vm.prank(alice);
        exchange.checkVIPUpgrade();

        assertEq(_getVIPLevel(alice), 1, "should be VIP1 after manual check");
    }

    // ============================================
    // Test: Admin Functions
    // ============================================

    /**
     * @notice Test admin can set VIP level directly
     */
    function testAdminCanSetVIPLevel() public {
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP3);
        assertEq(_getVIPLevel(alice), 3, "admin should be able to set VIP level");
    }

    /**
     * @notice Test non-admin cannot set VIP level
     */
    function testNonAdminCannotSetVIPLevel() public {
        vm.prank(alice);
        vm.expectRevert();
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP1);
    }

    /**
     * @notice Test admin can update VIP thresholds
     */
    function testAdminCanUpdateVIPThresholds() public {
        uint256[4] memory thresholds;
        thresholds[0] = 500 ether;
        thresholds[1] = 1000 ether;
        thresholds[2] = 2000 ether;
        thresholds[3] = 5000 ether;
        
        exchange.setVIPThresholds(thresholds);

        // Now 500 USD should upgrade to VIP1
        _addVolume(alice, 500 ether);
        assertEq(_getVIPLevel(alice), 1, "should upgrade to VIP1 with new 500 threshold");
    }

    // ============================================
    // Test: Fee Rates and Thresholds
    // ============================================

    /**
     * @notice Test fee rates decrease with VIP level
     */
    function testFeeRatesDecreaseWithVIPLevel() public view {
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP0), 10, "VIP0 should be 10 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP1), 9, "VIP1 should be 9 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP2), 8, "VIP2 should be 8 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP3), 6, "VIP3 should be 6 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP4), 5, "VIP4 should be 5 bps");
    }

    /**
     * @notice Test VIP thresholds are correct
     */
    function testVIPThresholdsAreCorrect() public view {
        assertEq(exchange.getVIPVolumeThreshold(0), 1000 ether, "VIP1 threshold should be 1000 ether");
        assertEq(exchange.getVIPVolumeThreshold(1), 2000 ether, "VIP2 threshold should be 2000 ether");
        assertEq(exchange.getVIPVolumeThreshold(2), 5000 ether, "VIP3 threshold should be 5000 ether");
        assertEq(exchange.getVIPVolumeThreshold(3), 8000 ether, "VIP4 threshold should be 8000 ether");
    }

    // ============================================
    // Test: Edge Cases
    // ============================================

    /**
     * @notice Test VIP level cannot downgrade (only upgrade)
     */
    function testVIPCannotDowngrade() public {
        // Upgrade to VIP3
        _addVolume(alice, 5000 ether);
        assertEq(_getVIPLevel(alice), 3, "should be VIP3");

        // Admin sets to VIP4
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP4);
        assertEq(_getVIPLevel(alice), 4, "should be VIP4");

        // Check upgrade - should not downgrade
        vm.prank(alice);
        exchange.checkVIPUpgrade();
        assertEq(_getVIPLevel(alice), 4, "should stay VIP4");
    }

    /**
     * @notice Test crossing multiple thresholds in one update
     */
    function testCrossMultipleThresholdsInOneUpdate() public {
        _addVolume(alice, 8000 ether);
        assertEq(_getVIPLevel(alice), 4, "should reach VIP4 in single volume update");
    }

    /**
     * @notice Test volume accumulation with different sizes
     */
    function testVolumeAccumulationVariableSize() public {
        _addVolume(alice, 100 ether);
        assertEq(_getVIPLevel(alice), 0, "should stay VIP0");

        _addVolume(alice, 500 ether);
        assertEq(_getVIPLevel(alice), 0, "should stay VIP0");

        _addVolume(alice, 400 ether);
        assertEq(_getVIPLevel(alice), 1, "should upgrade to VIP1 at total 1000");
    }
}
