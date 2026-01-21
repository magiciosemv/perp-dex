// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "./ReferralModule.sol";

/// @notice Liquidation checks and execution.
/// @dev Day 6: 清算模块
abstract contract LiquidationModule is ReferralModule {

    /// @notice 检查用户是否可被清算
    /// @param trader 用户地址
    /// @return 是否可清算
    function canLiquidate(address trader) public view virtual returns (bool) {
        Position memory p = accounts[trader].position;
        if (p.size == 0) return false;

        // 使用当前标记价（未设置时使用 entryPrice）
        uint256 mark = _calculateMarkPrice(indexPrice);

        int256 unrealized = _unrealizedPnl(p);
        int256 marginBalance = int256(accounts[trader].margin) + unrealized;

        uint256 priceBase = mark == 0 ? p.entryPrice : mark;
        uint256 positionValue = SignedMath.abs(int256(priceBase) * p.size) / 1e18;

        uint256 maintenance = (positionValue * (maintenanceMarginBps + liquidationFeeBps)) / 10_000;

        return marginBalance < int256(maintenance);
    }

    /// @notice 清算用户 (在 OrderBookModule 中实现具体逻辑)
    function liquidate(address trader) external virtual nonReentrant {
        // 将在 OrderBookModule 中实现
    }

    /// @notice 清除用户所有挂单
    /// @param trader 用户地址
    function _clearTraderOrders(address trader) internal returns (uint256 freedLocked) {
        // 在当前简化实现中，不追踪单独的 lockedMargin，因此 freedLocked 恒为 0
        bestBuyId = _removeOrders(bestBuyId, trader);
        bestSellId = _removeOrders(bestSellId, trader);
        return 0;
    }

    /// @notice 从链表中删除指定用户的订单
    function _removeOrders(uint256 headId, address trader) internal returns (uint256 newHead) {
        newHead = headId;
        uint256 current = headId;
        uint256 prev = 0;

        while (current != 0) {
            Order storage o = orders[current];
            uint256 next = o.next;
            if (o.trader == trader) {
                // 删除当前节点
                if (prev == 0) {
                    newHead = next;
                } else {
                    orders[prev].next = next;
                }
                pendingOrderCount[trader]--;
                emit OrderRemoved(o.id);
                delete orders[current];
                current = next;
                continue;
            }
            prev = current;
            current = next;
        }
    }

    uint256 constant SCALE = 1e18;

    /// @notice 执行交易
    /// @dev Day 3: 撮合成交核心函数，集成手续费扣除
    /// @param buyer 买方地址
    /// @param seller 卖方地址
    /// @param buyOrderId 买单ID (0表示市价单，非0表示订单簿中的订单)
    /// @param sellOrderId 卖单ID (0表示市价单，非0表示订单簿中的订单)
    /// @param amount 交易数量
    /// @param price 成交价格
    function _executeTrade(
        address buyer,
        address seller,
        uint256 buyOrderId,
        uint256 sellOrderId,
        uint256 amount,
        uint256 price
    ) internal virtual {
        // 1. 对买卖双方先结算资金费
        _applyFunding(buyer);
        _applyFunding(seller);

        // 2. 计算名义价值
        uint256 notional = (amount * price) / 1e18;

        // 3. 判断Maker和Taker
        // Maker: 订单簿中已存在的订单 (orderId != 0)
        // Taker: 新进入的订单，立即成交 (orderId == 0)
        bool buyerIsMaker = buyOrderId != 0;
        bool sellerIsMaker = sellOrderId != 0;

        // 4. 扣除交易手续费
        _chargeTradingFee(buyer, notional, buyerIsMaker);
        _chargeTradingFee(seller, notional, sellerIsMaker);

        // 5. 更新交易量（用于VIP升级）
        _updateTradingVolume(buyer, notional);
        _updateTradingVolume(seller, notional);

        // 6. 更新双方持仓
        _updatePosition(buyer, true, amount, price);
        _updatePosition(seller, false, amount, price);

        // 7. 触发成交事件
        emit TradeExecuted(buyOrderId, sellOrderId, price, amount, buyer, seller);
    }

    /// @notice 更新用户持仓
    /// @dev Day 3: 持仓更新核心函数
    function _updatePosition(
        address trader,
        bool isBuy,
        uint256 amount,
        uint256 tradePrice
    ) internal virtual {
        Position storage p = accounts[trader].position;
        int256 signedAmount = isBuy ? int256(amount) : -int256(amount);
        uint256 existingAbs = SignedMath.abs(p.size);

        // 1) 同方向加仓或开新仓
        if (p.size == 0 || (p.size > 0) == (signedAmount > 0)) {
            uint256 newAbs = existingAbs + amount;
            uint256 weighted = existingAbs == 0
                ? tradePrice
                : (existingAbs * p.entryPrice + amount * tradePrice) / newAbs;
            p.entryPrice = weighted;
            p.size += signedAmount;
            emit PositionUpdated(trader, p.size, p.entryPrice);
            return;
        }

        // 2) 反向减仓 / 平仓
        uint256 closing = amount < existingAbs ? amount : existingAbs;
        int256 pnlPerUnit = p.size > 0
            ? int256(tradePrice) - int256(p.entryPrice)
            : int256(p.entryPrice) - int256(tradePrice);
        int256 pnl = (pnlPerUnit * int256(closing)) / int256(SCALE);

        // 已实现盈亏直接结算到 margin
        int256 newMargin = int256(accounts[trader].margin) + pnl;
        if (newMargin < 0) {
            accounts[trader].margin = 0;
        } else {
            accounts[trader].margin = uint256(newMargin);
        }

        // 3) 是否产生反向新仓位
        uint256 remaining = amount - closing;
        if (closing == existingAbs) {
            // 原仓位全部平掉
            if (remaining == 0) {
                p.size = 0;
                p.entryPrice = tradePrice;
            } else {
                // 反向开新仓
                p.size = signedAmount > 0 ? int256(remaining) : -int256(remaining);
                p.entryPrice = tradePrice;
            }
        } else {
            // 部分减仓，方向不变
            if (p.size > 0) {
                p.size -= int256(closing);
            } else {
                p.size += int256(closing);
            }
        }

        emit PositionUpdated(trader, p.size, p.entryPrice);
    }
}
