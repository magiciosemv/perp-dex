// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FundingModule.sol";

/// @notice Price management (Operator updates only).
/// @dev Day 4: 价格预言机模块
abstract contract PricingModule is FundingModule {

    /// @notice 更新指数价格 (仅 OPERATOR_ROLE)
    /// @param newIndexPrice 新的指数价格
    function updateIndexPrice(uint256 newIndexPrice) external virtual onlyRole(OPERATOR_ROLE) {
        // 更新指数价格
        indexPrice = newIndexPrice;

        // 计算并更新标记价格
        markPrice = _calculateMarkPrice(newIndexPrice);

        // 触发价格更新事件
        emit MarkPriceUpdated(markPrice, indexPrice);
    }

    /// @notice 计算标记价格
    /// @dev 使用订单簿最优价和指数价的中位数
    /// @param indexPrice_ 指数价格
    /// @return 标记价格
    function _calculateMarkPrice(uint256 indexPrice_) internal view virtual returns (uint256) {
        uint256 bestBid = bestBuyId == 0 ? 0 : orders[bestBuyId].price;
        uint256 bestAsk = bestSellId == 0 ? 0 : orders[bestSellId].price;

        // 如果买卖盘都为空，直接返回指数价格
        if (bestBid == 0 && bestAsk == 0) {
        return indexPrice_;
        }

        // 若一侧为空，则使用指数价填充该侧
        if (bestBid == 0) bestBid = indexPrice_;
        if (bestAsk == 0) bestAsk = indexPrice_;

        // 计算三价取中
        uint256 a = bestBid;
        uint256 b = bestAsk;
        uint256 c = indexPrice_;

        if (a > b) {
            (a, b) = (b, a);
        }
        if (b > c) {
            (b, c) = (c, b);
        }
        if (a > b) {
            (a, b) = (b, a);
        }

        uint256 median = b;

        // 钳位：标记价不超过指数价 ±5%
        uint256 maxDeviation = (indexPrice_ * 500) / 10_000; // 5%
        uint256 upper = indexPrice_ + maxDeviation;
        uint256 lower = indexPrice_ > maxDeviation ? indexPrice_ - maxDeviation : 0;

        if (median > upper) return upper;
        if (median < lower) return lower;

        return median;
    }

    function _pullLatestPrice() internal virtual override(FundingModule) {
        // No-op: Price is pushed by operator
    }
}
