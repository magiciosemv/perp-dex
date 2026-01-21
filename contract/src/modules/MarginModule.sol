// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "./LiquidationModule.sol";

/// @notice Margin accounting (deposit/withdraw) plus margin checks.
/// @dev Day 1: 保证金模块
abstract contract MarginModule is LiquidationModule {

    /// @notice 存入保证金
    function deposit() external payable virtual nonReentrant {
        // 将发送的原生代币计入用户保证金
        accounts[msg.sender].margin += msg.value;
        emit MarginDeposited(msg.sender, msg.value);
    }

    /// @notice 提取保证金
    /// @param amount 提取金额
    function withdraw(uint256 amount) external virtual nonReentrant {
        require(amount > 0, "amount=0");

        // 资金费结算（Day5/Day6 实现具体逻辑）
        _applyFunding(msg.sender);

        // 基本保证金检查
        require(accounts[msg.sender].margin >= amount, "not enough margin");

        // 维持保证金检查（Day6 实现）
        _ensureWithdrawKeepsMaintenance(msg.sender, amount);

        // 先扣减再转账，避免重入
        accounts[msg.sender].margin -= amount;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "withdraw failed");

        emit MarginWithdrawn(msg.sender, amount);
    }

    /// @notice 计算持仓所需保证金
    function _calculatePositionMargin(int256 size) internal view returns (uint256) {
        // 无持仓或尚未有标记价时不需要保证金
        if (size == 0 || markPrice == 0) return 0;

        uint256 absSize = SignedMath.abs(size);
        // 名义价值 = |size| * markPrice / 1e18
        uint256 notional = (absSize * markPrice) / 1e18;
        // 所需保证金 = 名义价值 * initialMarginBps / 10000
        return (notional * initialMarginBps) / 10_000;
    }

    /// @notice 获取用户待成交订单数量
    function _countPendingOrders(address trader) internal view returns (uint256) {
        return pendingOrderCount[trader];
    }

    /// @notice 计算最坏情况下所需保证金
    /// @dev 假设所有挂单都成交后的保证金需求
    function _calculateWorstCaseMargin(address trader) internal view returns (uint256) {
        Position memory pos = accounts[trader].position;

        // 1. 计算买单方向挂单所需保证金（使用委托价）
        uint256 buyOrderMargin = 0;
        uint256 id = bestBuyId;
        while (id != 0) {
            Order storage o = orders[id];
            if (o.trader == trader) {
                uint256 orderVal = (o.price * o.amount) / 1e18;
                buyOrderMargin += (orderVal * initialMarginBps) / 10_000;
            }
            id = o.next;
        }

        // 2. 计算卖单方向挂单所需保证金
        uint256 sellOrderMargin = 0;
        id = bestSellId;
        while (id != 0) {
            Order storage o2 = orders[id];
            if (o2.trader == trader) {
                uint256 orderVal2 = (o2.price * o2.amount) / 1e18;
                sellOrderMargin += (orderVal2 * initialMarginBps) / 10_000;
            }
            id = o2.next;
        }

        // 3. 当前持仓所需保证金（基于标记价）
        uint256 positionMargin = _calculatePositionMargin(pos.size);

        // 4. 总需求 = 持仓保证金 + max(买单保证金, 卖单保证金)
        uint256 ordersMargin = buyOrderMargin > sellOrderMargin ? buyOrderMargin : sellOrderMargin;
        return positionMargin + ordersMargin;
    }

    /// @notice 检查用户是否有足够保证金
    function _checkWorstCaseMargin(address trader) internal view {
        uint256 required = _calculateWorstCaseMargin(trader);
        Position memory p = accounts[trader].position;

        // marginBalance = margin + unrealizedPnl
        int256 marginBalance = int256(accounts[trader].margin) + _unrealizedPnl(p);

        require(marginBalance >= int256(required), "insufficient margin");
    }

    /// @notice 确保提现后仍满足维持保证金要求
    function _ensureWithdrawKeepsMaintenance(address trader, uint256 amount) internal view {
        Position memory p = accounts[trader].position;

        // 1. 如果没有持仓，提现不受限制
        if (p.size == 0) return;

        // 2. 计算提现后的保证金余额（含未实现盈亏）
        int256 marginAfter = int256(accounts[trader].margin) - int256(amount);
        int256 unrealized = _unrealizedPnl(p);
        int256 marginBalance = marginAfter + unrealized;

        // 3. 计算持仓价值与维持保证金
        uint256 priceBase = markPrice == 0 ? p.entryPrice : markPrice;
        uint256 positionValue = SignedMath.abs(int256(priceBase) * p.size) / 1e18;
        uint256 maintenance = (positionValue * maintenanceMarginBps) / 10_000;

        // 4. 确保提现后仍高于维持保证金，否则可能触发清算
        require(marginBalance >= int256(maintenance), "withdraw would trigger liquidation");
    }
}
