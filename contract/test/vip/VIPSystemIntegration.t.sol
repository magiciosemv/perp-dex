// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/ExchangeFixture.sol";
import "../../src/core/ExchangeStorage.sol";

/**
 * @title VIP System Integration Tests
 * @notice Test the VIP system by directly managing VIP levels and verifying fee calculations
 * @dev Uses admin functions to set VIP levels and verify fee system integration
 */
contract VIPSystemIntegrationTest is ExchangeFixture {
    
    function setUp() public override {
        super.setUp();
        exchange.updateIndexPrice(100 ether);
    }

    // ============================================
    // Test: VIP Level Basic Management
    // ============================================

    function testVIPLevelCanBeSet() public {
        // Admin sets user to VIP1
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP1);
        assertEq(uint8(exchange.getVIPLevel(alice)), 1, "should set to VIP1");
    }

    function testMultipleVIPLevels() public {
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP1);
        exchange.setVIPLevel(bob, ExchangeStorage.VIPLevel.VIP2);
        exchange.setVIPLevel(carol, ExchangeStorage.VIPLevel.VIP3);

        assertEq(uint8(exchange.getVIPLevel(alice)), 1, "alice should be VIP1");
        assertEq(uint8(exchange.getVIPLevel(bob)), 2, "bob should be VIP2");
        assertEq(uint8(exchange.getVIPLevel(carol)), 3, "carol should be VIP3");
    }

    function testVIPLevelProgression() public {
        // VIP0 -> VIP1
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP1);
        assertEq(uint8(exchange.getVIPLevel(alice)), 1, "upgrade to VIP1");

        // VIP1 -> VIP2
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP2);
        assertEq(uint8(exchange.getVIPLevel(alice)), 2, "upgrade to VIP2");

        // VIP2 -> VIP3
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP3);
        assertEq(uint8(exchange.getVIPLevel(alice)), 3, "upgrade to VIP3");

        // VIP3 -> VIP4
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP4);
        assertEq(uint8(exchange.getVIPLevel(alice)), 4, "upgrade to VIP4");
    }

    // ============================================
    // Test: Fee Rates Initialization
    // ============================================

    function testFeesInitializedCorrectly() public view {
        // Check that tier fees are set correctly
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP0), 10, "VIP0 fee should be 10 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP1), 9, "VIP1 fee should be 9 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP2), 8, "VIP2 fee should be 8 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP3), 6, "VIP3 fee should be 6 bps");
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP4), 5, "VIP4 fee should be 5 bps");
    }

    function testVIPThresholdsInitializedCorrectly() public view {
        // Check VIP thresholds
        assertEq(exchange.getVIPVolumeThreshold(0), 1000 ether, "VIP1 threshold should be 1000 ether");
        assertEq(exchange.getVIPVolumeThreshold(1), 2000 ether, "VIP2 threshold should be 2000 ether");
        assertEq(exchange.getVIPVolumeThreshold(2), 5000 ether, "VIP3 threshold should be 5000 ether");
        assertEq(exchange.getVIPVolumeThreshold(3), 8000 ether, "VIP4 threshold should be 8000 ether");
    }

    // ============================================
    // Test: Admin Fee Configuration
    // ============================================

    function testAdminCanSetTierFees() public {
        // Update VIP1 fee from 9 to 7 bps
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP1, 7);
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP1), 7, "should update VIP1 fee");
    }

    function testAdminCanSetVIPThresholds() public {
        // Update thresholds to lower values
        uint256[4] memory newThresholds;
        newThresholds[0] = 500 ether;
        newThresholds[1] = 1000 ether;
        newThresholds[2] = 2500 ether;
        newThresholds[3] = 5000 ether;

        exchange.setVIPThresholds(newThresholds);

        assertEq(exchange.getVIPVolumeThreshold(0), 500 ether, "should update VIP1 threshold");
        assertEq(exchange.getVIPVolumeThreshold(1), 1000 ether, "should update VIP2 threshold");
        assertEq(exchange.getVIPVolumeThreshold(2), 2500 ether, "should update VIP3 threshold");
        assertEq(exchange.getVIPVolumeThreshold(3), 5000 ether, "should update VIP4 threshold");
    }

    // ============================================
    // Test: Non-Admin Restrictions
    // ============================================

    function testNonAdminCannotSetVIPLevel() public {
        vm.prank(alice);
        vm.expectRevert();
        exchange.setVIPLevel(alice, ExchangeStorage.VIPLevel.VIP1);
    }

    function testNonAdminCannotUpdateFees() public {
        vm.prank(alice);
        vm.expectRevert();
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP1, 5);
    }

    function testNonAdminCannotUpdateThresholds() public {
        uint256[4] memory newThresholds;
        vm.prank(alice);
        vm.expectRevert();
        exchange.setVIPThresholds(newThresholds);
    }

    // ============================================
    // Test: VIP System Completeness
    // ============================================

    /**
     * @notice Verify all VIP levels exist and can be set
     */
    function testAllVIPLevelsSupported() public {
        for (uint8 i = 0; i < 5; i++) {
            ExchangeStorage.VIPLevel level = ExchangeStorage.VIPLevel(i);
            exchange.setVIPLevel(alice, level);
            assertEq(uint8(exchange.getVIPLevel(alice)), i, "should support VIP level");
        }
    }

    /**
     * @notice Test that VIP0 is the default level
     */
    function testDefaultVIPIsVIP0() public {
        // New user should be VIP0
        address newUser = address(0x9999);
        assertEq(uint8(exchange.getVIPLevel(newUser)), 0, "new user should be VIP0");
    }

    /**
     * @notice Test VIP thresholds follow correct progression
     */
    function testVIPThresholdsProgress() public view {
        uint256 vip1 = exchange.getVIPVolumeThreshold(0);
        uint256 vip2 = exchange.getVIPVolumeThreshold(1);
        uint256 vip3 = exchange.getVIPVolumeThreshold(2);
        uint256 vip4 = exchange.getVIPVolumeThreshold(3);

        // Each threshold should be >= previous
        assert(vip1 <= vip2);
        assert(vip2 <= vip3);
        assert(vip3 <= vip4);
    }

    /**
     * @notice Test that all fee rates are positive
     */
    function testAllFeesPositive() public view {
        for (uint8 i = 0; i < 5; i++) {
            ExchangeStorage.VIPLevel level = ExchangeStorage.VIPLevel(i);
            uint256 fee = exchange.tierFeeBps(level);
            assert(fee > 0);
            assert(fee <= 1000); // Max 10%
        }
    }

    /**
     * @notice Test that fee decreases as VIP level increases
     */
    function testFeesDecreaseWithVIP() public view {
        uint256 fee0 = exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP0);
        uint256 fee1 = exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP1);
        uint256 fee2 = exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP2);
        uint256 fee3 = exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP3);
        uint256 fee4 = exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP4);

        // Fees should strictly decrease
        assert(fee0 > fee1);
        assert(fee1 > fee2);
        assert(fee2 > fee3);
        assert(fee3 > fee4);
    }

    // ============================================
    // Test: Edge Cases and Boundaries
    // ============================================

    /**
     * @notice Test setting fee to maximum allowed
     */
    function testMaxFeeAllowed() public {
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP1, 1000);
        assertEq(exchange.tierFeeBps(ExchangeStorage.VIPLevel.VIP1), 1000, "should allow max 10% fee");
    }

    /**
     * @notice Test that fee above maximum is rejected
     */
    function testFeeTooHighRejected() public {
        vm.expectRevert();
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP1, 1001);
    }

    /**
     * @notice Test all VIP level transitions
     */
    function testAllVIPLevelTransitions() public {
        address testUser = address(0x1111);

        // VIP0 (default)
        assertEq(uint8(exchange.getVIPLevel(testUser)), 0, "initial VIP0");

        // VIP0 -> VIP1
        exchange.setVIPLevel(testUser, ExchangeStorage.VIPLevel.VIP1);
        assertEq(uint8(exchange.getVIPLevel(testUser)), 1, "should be VIP1");

        // VIP1 -> VIP2
        exchange.setVIPLevel(testUser, ExchangeStorage.VIPLevel.VIP2);
        assertEq(uint8(exchange.getVIPLevel(testUser)), 2, "should be VIP2");

        // VIP2 -> VIP3
        exchange.setVIPLevel(testUser, ExchangeStorage.VIPLevel.VIP3);
        assertEq(uint8(exchange.getVIPLevel(testUser)), 3, "should be VIP3");

        // VIP3 -> VIP4
        exchange.setVIPLevel(testUser, ExchangeStorage.VIPLevel.VIP4);
        assertEq(uint8(exchange.getVIPLevel(testUser)), 4, "should be VIP4");

        // Can go back down with admin override
        exchange.setVIPLevel(testUser, ExchangeStorage.VIPLevel.VIP0);
        assertEq(uint8(exchange.getVIPLevel(testUser)), 0, "can reset to VIP0");
    }
}
