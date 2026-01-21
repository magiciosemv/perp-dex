// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "../core/ExchangeStorage.sol";

/// @notice Funding settlement and shared math helpers.
/// @dev Day 5: 资金费率计算与结算
abstract contract FundingModule is ExchangeStorage {

    /// @notice 结算全局资金费率
    /// @dev 每隔 fundingInterval 调用一次，更新 cumulativeFundingRate
    function settleFunding() public virtual {
        // 1. 仅在到达结算时间且指数价已设置时更新
        if (block.timestamp < lastFundingTime + fundingInterval) return;
        if (indexPrice == 0) return;

        // 2. 计算 Premium Index = (Mark - Index) / Index
        int256 mark = int256(markPrice);
        int256 index = int256(indexPrice);
        int256 premiumIndex = ((mark - index) * int256(1e18)) / index;

        // 3. 应用利率与钳位
        int256 interestRate = 1e14; // 0.01%
        int256 clampRange = 5e14;   // 0.05%

        int256 diff = interestRate - premiumIndex;
        int256 clamped = diff;
        if (diff > clampRange) clamped = clampRange;
        if (diff < -clampRange) clamped = -clampRange;

        int256 rate = premiumIndex + clamped;

        // 4. 应用每 interval 上限
        if (maxFundingRatePerInterval > 0) {
            if (rate > maxFundingRatePerInterval) rate = maxFundingRatePerInterval;
            if (rate < -maxFundingRatePerInterval) rate = -maxFundingRatePerInterval;
        }

        // 5. 累计到全局费率并更新时间
        cumulativeFundingRate += rate;
        lastFundingTime = block.timestamp;

        // 6. 触发事件
        emit FundingUpdated(cumulativeFundingRate, block.timestamp);
    }

    /// @notice 结算特定用户的资金费
    /// @param trader 用户地址
    function settleUserFunding(address trader) external virtual {
        _applyFunding(trader);
    }

    /// @notice 设置资金费率参数 (仅管理员)
    function setFundingParams(uint256 interval, int256 maxRatePerInterval) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(interval > 0, "interval=0");
        require(maxRatePerInterval >= 0, "cap<0");
        fundingInterval = interval;
        maxFundingRatePerInterval = maxRatePerInterval;
        emit FundingParamsUpdated(interval, maxRatePerInterval);
    }

    /// @notice 应用资金费到用户账户
    /// @dev 内部函数，计算用户应付/应收的资金费
    function _applyFunding(address trader) internal virtual {
        Account storage a = accounts[trader];
        Position storage p = a.position;

        // 1. 无持仓时，仅更新基准 index，避免历史费用累加
        if (p.size == 0) {
            lastFundingIndex[trader] = cumulativeFundingRate;
            return;
        }

        // 2. 确保全局费率为最新
        settleFunding();

        // 3. 计算本次需结算的费率差
        int256 diff = cumulativeFundingRate - lastFundingIndex[trader];
        if (diff == 0) return;

        // 4. Payment = Size * MarkPrice * Diff / 1e36
        int256 payment = (int256(p.size) * int256(markPrice) * diff) / int256(1e36);

        // 5. 更新用户 margin
        uint256 free = a.margin;
        if (payment > 0) {
            // 需要支付
            uint256 pay = uint256(payment);
            if (pay >= free) {
                a.margin = 0;
            } else {
                a.margin = free - pay;
            }
        } else if (payment < 0) {
            // 收到资金费
            uint256 credit = uint256(-payment);
            a.margin = free + credit;
        }

        // 6. 更新用户的 funding index
        lastFundingIndex[trader] = cumulativeFundingRate;

        // 7. 触发事件
        emit FundingPaid(trader, payment);
    }

    /// @notice 计算未实现盈亏
    /// @param p 持仓结构体
    /// @return 未实现盈亏 (可为负)
    function _unrealizedPnl(Position memory p) internal view returns (int256) {
        if (p.size == 0) return 0;

        // priceDiff = markPrice - entryPrice
        int256 priceDiff = int256(markPrice) - int256(p.entryPrice);

        // 空头仓位方向相反
        if (p.size < 0) {
            priceDiff = -priceDiff;
        }

        // PnL = priceDiff * |size| / 1e18
        return (priceDiff * int256(SignedMath.abs(p.size))) / int256(1e18);
    }

    /// @notice 钩子：子模块可覆盖以在操作前拉取最新价格
    function _pullLatestPrice() internal virtual {}
}
