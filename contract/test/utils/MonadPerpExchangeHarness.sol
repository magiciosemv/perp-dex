// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/Exchange.sol";

contract MonadPerpExchangeHarness is MonadPerpExchange {
    constructor() MonadPerpExchange() {
        // Override fee receiver to be this contract, so fees don't revert
        feeReceiver = address(this);
    }

    bool public manualPriceMode;

    // Allow receiving ether for fee transfers
    receive() external payable {}
    fallback() external payable {}

    function setManualPriceMode(bool _mode) external {
        manualPriceMode = _mode;
    }

    function updatePrices(uint256 mark, uint256 index) external {
        markPrice = mark;
        indexPrice = index;
    }

    function _pullLatestPrice() internal virtual override {
        if (!manualPriceMode) {
            super._pullLatestPrice();
        }
        // If manual mode, do nothing (preserve manually set prices)
    }

    function _calculateMarkPrice(uint256 indexPrice_) internal view override returns (uint256) {
        if (manualPriceMode) {
            return markPrice;
        }
        return super._calculateMarkPrice(indexPrice_);
    }

    // ============================================
    // Test Helpers for VIP Module
    // ============================================

    /// @notice Set VIP volume thresholds (admin function for testing)
    function setVIPThresholds(uint256[4] calldata newThresholds) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        vipVolumeThresholds = newThresholds;
        emit VIPThresholdsUpdated(newThresholds);
    }

    /// @notice Get a specific VIP volume threshold
    function getVIPVolumeThreshold(uint256 index) external view returns (uint256) {
        require(index < 4, "invalid threshold index");
        return vipVolumeThresholds[index];
    }

    /// @notice Get tier fee for a specific VIP level
    function getTierFeeBps(ExchangeStorage.VIPLevel level) external view returns (uint256) {
        return tierFeeBps[level];
    }

    /// @notice Get the fee receiver address
    function getFeeReceiver() external view returns (address) {
        return feeReceiver;
    }

    /// @notice Manually update trading volume (for testing)
    function manuallyUpdateVolume(address trader, uint256 volume) external {
        _updateTradingVolume(trader, volume);
    }

    /// @notice Get referrer for a user
    function getReferrer(address user) external view override returns (address) {
        return referrers[user];
    }
}
