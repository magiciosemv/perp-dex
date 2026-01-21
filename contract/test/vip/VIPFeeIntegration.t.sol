// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/ExchangeFixture.sol";
import "../../src/core/ExchangeStorage.sol";

/**
 * @title VIP Fee Integration Tests
 * @notice Tests for VIP level integration with trading fee calculation
 * @dev Verifies that different VIP levels receive appropriate fee rates
 */
contract VIPFeeIntegrationTest is ExchangeFixture {

    function setUp() public override {
        super.setUp();
        exchange.updateIndexPrice(100 ether);
    }

    // ============================================
    // Helper Functions
    // ============================================

    function _placeVolumeAndUpgrade(address trader, uint256 volumeUSD) internal {
        uint256 marginNeeded = volumeUSD / 100;
        _deposit(trader, marginNeeded);

        uint256 amount = (volumeUSD * 1e18) / (100 ether);
        vm.prank(trader);
        exchange.placeOrder(true, 100 ether, amount, 0);
    }

    function _getFeeRate(address trader) internal view returns (uint256) {
        return exchange.getActualFeeRate(trader, false);
    }

    // ============================================
    // Test: Default Fee Rates by VIP Level
    // ============================================

    /**
     * @notice Test VIP0 has 10 bps fee rate
     * @dev New traders with no volume should pay 10 bps
     */
    function testVIP0FeeRateIs10Bps() public {
        uint256 feeRate = _getFeeRate(alice);
        assertEq(feeRate, 10, "VIP0 should have 10 bps fee rate");
    }

    /**
     * @notice Test VIP1 has 9 bps fee rate
     * @dev Traders with 1000+ USD should pay 9 bps
     */
    function testVIP1FeeRateIs9Bps() public {
        _placeVolumeAndUpgrade(alice, 1000 ether);
        uint256 feeRate = _getFeeRate(alice);
        assertEq(feeRate, 9, "VIP1 should have 9 bps fee rate");
    }

    /**
     * @notice Test VIP2 has 8 bps fee rate
     * @dev Traders with 2000+ USD should pay 8 bps
     */
    function testVIP2FeeRateIs8Bps() public {
        _placeVolumeAndUpgrade(alice, 2000 ether);
        uint256 feeRate = _getFeeRate(alice);
        assertEq(feeRate, 8, "VIP2 should have 8 bps fee rate");
    }

    /**
     * @notice Test VIP3 has 6 bps fee rate
     * @dev Traders with 5000+ USD should pay 6 bps
     */
    function testVIP3FeeRateIs6Bps() public {
        _placeVolumeAndUpgrade(alice, 5000 ether);
        uint256 feeRate = _getFeeRate(alice);
        assertEq(feeRate, 6, "VIP3 should have 6 bps fee rate");
    }

    /**
     * @notice Test VIP4 has 5 bps fee rate
     * @dev Traders with 8000+ USD should pay 5 bps (minimum)
     */
    function testVIP4FeeRateIs5Bps() public {
        _placeVolumeAndUpgrade(alice, 8000 ether);
        uint256 feeRate = _getFeeRate(alice);
        assertEq(feeRate, 5, "VIP4 should have 5 bps fee rate (minimum)");
    }

    // ============================================
    // Test: Fee Rate Progression with Volume
    // ============================================



    /**
     * @notice Test maximum fee discount is 5 bps at VIP4
     * @dev VIP4 is minimum fee rate, cannot go lower
     */
    function testMinimumFeeIs5Bps() public {
        _placeVolumeAndUpgrade(alice, 8000 ether);
        uint256 feeRate = _getFeeRate(alice);
        
        assertEq(feeRate, 5, "minimum fee should be 5 bps");
        
        // Even with more volume, should stay at 5 bps
        _placeVolumeAndUpgrade(alice, 20000 ether);
        uint256 feeRateAfter = _getFeeRate(alice);
        
        assertEq(feeRateAfter, 5, "fee should remain at minimum 5 bps");
    }

    // ============================================
    // Test: Fee Calculation with VIP Discount
    // ============================================

    /**
     * @notice Test fee calculation uses correct VIP tier
     * @dev Fee should be calculated using the trader's VIP fee rate
     */
    function testFeeCalculationUsesVIPRate() public {
        _placeVolumeAndUpgrade(alice, 1000 ether);

        // Once at VIP1, fee rate should be 9 bps
        uint256 feeRate = _getFeeRate(alice);
        assertEq(feeRate, 9, "should use VIP1 fee rate");

        // The fee charged should reflect this rate
        // (Assuming fee charging is integrated with VIP lookup)
    }

    // ============================================
    // Test: Admin Fee Configuration
    // ============================================

    /**
     * @notice Test admin can update fee rates for VIP tiers
     * @dev Admin should be able to modify tier fee configurations
     */
    function testAdminCanUpdateTierFees() public {
        // Set new fee rates
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP0, 12);
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP1, 10);
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP4, 3);

        // Verify new rates
        uint256 fee0 = exchange.getActualFeeRate(alice, false);
        assertEq(fee0, 12, "VIP0 should have updated fee rate");

        // After upgrading to VIP1
        _placeVolumeAndUpgrade(alice, 1000 ether);
        uint256 fee1 = _getFeeRate(alice);
        assertEq(fee1, 10, "VIP1 should have updated fee rate");
    }

    /**
     * @notice Test admin cannot set invalid fee rates
     * @dev Fees should have reasonable upper bounds
     */
    function testAdminFeeRateMaxLimit() public {
        // Try to set fee rate above maximum (1000 bps = 10%)
        vm.expectRevert();
        exchange.setTierFeeBps(ExchangeStorage.VIPLevel.VIP0, 2000);
    }

    // ============================================
    // Test: Multiple Users with Different Fees
    // ============================================

    /**
     * @notice Test different users pay different fees based on VIP level
     * @dev Each user should pay fee based on their own VIP level
     */
    function testDifferentUsersPayDifferentFees() public {
        // Alice: no trading, VIP0 (10 bps)
        uint256 aliceFee = _getFeeRate(alice);

        // Bob: 1000 USD, VIP1 (9 bps)
        _placeVolumeAndUpgrade(bob, 1000 ether);
        uint256 bobFee = _getFeeRate(bob);

        // Carol: 5000 USD, VIP3 (6 bps)
        _placeVolumeAndUpgrade(carol, 5000 ether);
        uint256 carolFee = _getFeeRate(carol);

        assertEq(aliceFee, 10, "alice should pay 10 bps");
        assertEq(bobFee, 9, "bob should pay 9 bps");
        assertEq(carolFee, 6, "carol should pay 6 bps");

        assertTrue(aliceFee > bobFee && bobFee > carolFee, 
            "higher VIP users should pay lower fees");
    }

    // ============================================
    // Test: Fee Stability After Volume Cleanup
    // ============================================



    // ============================================
    // Test: Fee Savings Calculation
    // ============================================

    /**
     * @notice Test calculating total fee savings with VIP upgrades
     * @dev Higher VIP levels should result in lower total fees paid
     */
    function testFeeReductionWithVIPUpgrade() public {
        // Simulate two traders with same trading volume but different VIP levels
        
        // Trader 1: Stays at VIP0 (10 bps)
        _deposit(alice, 10 ether);
        
        // Trader 2: Upgrades to VIP1 (9 bps)
        _placeVolumeAndUpgrade(bob, 1000 ether);

        uint256 aliceFee = _getFeeRate(alice);
        uint256 bobFee = _getFeeRate(bob);

        // Fee difference: 10 - 9 = 1 bps
        uint256 feeDifference = aliceFee - bobFee;
        assertEq(feeDifference, 1, "VIP1 saves 1 bps compared to VIP0");

        // For a 10000 USD trade:
        // Alice: 10000 * 10 / 10000 = 10 units
        // Bob: 10000 * 9 / 10000 = 9 units
        // Savings: 1 unit per 10000 USD
    }

    // ============================================
    // Test: Fee Rate View Functions
    // ============================================

    /**
     * @notice Test getReferralRebateBps returns correct value
     * @dev Should return the configured referral rebate percentage
     */
    function testGetReferralRebateBps() public {
        uint256 rebateBps = exchange.getReferralRebateBps();
        assertEq(rebateBps, 1000, "default referral rebate should be 10% (1000 bps)");
    }

    // ============================================
    // Test: Fee Rate Persistence
    // ============================================

    /**
     * @notice Test fee rate remains consistent across multiple queries
     * @dev Fee rate for a given VIP level should be deterministic
     */
    function testFeeRateConsistency() public {
        _placeVolumeAndUpgrade(alice, 5000 ether);

        uint256 fee1 = _getFeeRate(alice);
        uint256 fee2 = _getFeeRate(alice);
        uint256 fee3 = _getFeeRate(alice);

        assertEq(fee1, fee2, "fee rate should be consistent");
        assertEq(fee2, fee3, "fee rate should be consistent");
    }

    // ============================================
    // Test: Fee Rate Edge Cases
    // ============================================

    /**
     * @notice Test fee rate at exact VIP upgrade boundaries
     * @dev At threshold, new fee rate should apply immediately
     */
    function testFeeRateAtUpgradeBoundary() public {
        // Just below threshold: VIP0 (10 bps)
        _placeVolumeAndUpgrade(alice, 999 ether);
        uint256 feeBelow = _getFeeRate(alice);

        // Deposit more to get exactly to threshold
        _deposit(alice, 1 ether);
        uint256 amount = 1e16;  // 0.01 at 100 ether price = 1 USD
        vm.prank(alice);
        exchange.placeOrder(true, 100 ether, amount, 0);

        // At/above threshold: VIP1 (9 bps)
        uint256 feeAbove = _getFeeRate(alice);

        assertTrue(feeBelow > feeAbove, "fee should decrease at upgrade boundary");
    }
}
