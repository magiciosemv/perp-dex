import {
    Exchange,
    MarginEvent,
    Order,
    Trade,
    Position,
    Candle,
    LatestCandle,
    FundingEvent,
    Liquidation,
    // Day 8+: VIP和返佣实体（需要codegen生成类型后才能使用）
    // UserVolume,
    // ReferralStat,
    // RebatePayment,
    // VIPLevelChange,
} from "../generated";

/**
 * Day 1: 处理保证金充值事件
 */
Exchange.MarginDeposited.handler(async ({ event, context }) => {
    const entity: MarginEvent = {
        id: `${event.transaction.hash}-${event.logIndex}`,
        trader: event.params.trader,
        amount: event.params.amount,
        eventType: "DEPOSIT",
        timestamp: event.block.timestamp,
        txHash: event.transaction.hash,
    };
    context.MarginEvent.set(entity);
});

/**
 * Day 1: 处理保证金提现事件
 */
Exchange.MarginWithdrawn.handler(async ({ event, context }) => {
    const entity: MarginEvent = {
        id: `${event.transaction.hash}-${event.logIndex}`,
        trader: event.params.trader,
        amount: event.params.amount,
        eventType: "WITHDRAW",
        timestamp: event.block.timestamp,
        txHash: event.transaction.hash,
    };
    context.MarginEvent.set(entity);
});

/**
 * Day 2: 处理订单创建事件
 */
Exchange.OrderPlaced.handler(async ({ event, context }) => {
    const order: Order = {
        id: event.params.id.toString(),
        trader: event.params.trader,
        isBuy: event.params.isBuy,
        price: event.params.price,
        initialAmount: event.params.amount,
        amount: event.params.amount,
        status: "OPEN",
        timestamp: event.block.timestamp,
    };
    context.Order.set(order);
});

/**
 * Day 2: 处理订单移除事件
 */
Exchange.OrderRemoved.handler(async ({ event, context }) => {
    const order = await context.Order.get(event.params.id.toString());
    if (order) {
        context.Order.set({
            ...order,
            status: order.amount === 0n ? "FILLED" : "CANCELLED",
            amount: 0n, // 清零以便 GET_OPEN_ORDERS 过滤
        });
    }
});

/**
 * Day 3: 处理成交事件
 */
Exchange.TradeExecuted.handler(async ({ event, context }) => {
    // 1. 创建成交记录
    const trade: Trade = {
        id: `${event.transaction.hash}-${event.logIndex}`,
        buyer: event.params.buyer,
        seller: event.params.seller,
        price: event.params.price,
        amount: event.params.amount,
        timestamp: event.block.timestamp,
        txHash: event.transaction.hash,
        buyOrderId: event.params.buyOrderId,
        sellOrderId: event.params.sellOrderId,
    };
    context.Trade.set(trade);

    // 2. 更新买卖双方订单的剩余量
    const buyOrder = await context.Order.get(event.params.buyOrderId.toString());
    if (buyOrder) {
        const newAmount = buyOrder.amount - event.params.amount;
        context.Order.set({
            ...buyOrder,
            amount: newAmount,
            status: newAmount === 0n ? "FILLED" : "OPEN",
        });
    }

    const sellOrder = await context.Order.get(event.params.sellOrderId.toString());
    if (sellOrder) {
        const newAmount = sellOrder.amount - event.params.amount;
        context.Order.set({
            ...sellOrder,
            amount: newAmount,
            status: newAmount === 0n ? "FILLED" : "OPEN",
        });
    }

    // Day 5: 更新 K 线 (1m)
    const resolution = "1m";
    // 向下取整到最近的分钟
    const timestamp = event.block.timestamp - (event.block.timestamp % 60);
    const candleId = `${resolution}-${timestamp}`;

    const existingCandle = await context.Candle.get(candleId);

    if (!existingCandle) {
        // 新 K 线：使用上一根 K 线的 close 作为 open
        const latestCandleState = await context.LatestCandle.get("1");
        const openPrice = latestCandleState ? latestCandleState.closePrice : event.params.price;
        
        const candle: Candle = {
            id: candleId,
            resolution,
            timestamp,
            openPrice: openPrice,
            highPrice: event.params.price > openPrice ? event.params.price : openPrice,
            lowPrice: event.params.price < openPrice ? event.params.price : openPrice,
            closePrice: event.params.price,
            volume: event.params.amount,
        };
        context.Candle.set(candle);
    } else {
        // 更新现有 K 线
        const newHigh = event.params.price > existingCandle.highPrice ? event.params.price : existingCandle.highPrice;
        const newLow = event.params.price < existingCandle.lowPrice ? event.params.price : existingCandle.lowPrice;

        context.Candle.set({
            ...existingCandle,
            highPrice: newHigh,
            lowPrice: newLow,
            closePrice: event.params.price,
            volume: existingCandle.volume + event.params.amount,
        });
    }

    // 更新全局最新价格状态
    context.LatestCandle.set({
        id: "1",
        closePrice: event.params.price,
        timestamp: event.block.timestamp
    });
});

/**
 * Day 3: 处理持仓更新事件
 */
Exchange.PositionUpdated.handler(async ({ event, context }) => {
    const position: Position = {
        id: event.params.trader,
        trader: event.params.trader,
        size: event.params.size,
        entryPrice: event.params.entryPrice,
    };
    context.Position.set(position);
});

/**
 * Day 6: 处理全局资金费率更新事件
 */
Exchange.FundingUpdated.handler(async ({ event, context }) => {
    const entity: FundingEvent = {
        id: `${event.transaction.hash}-${event.logIndex}`,
        eventType: "GLOBAL_UPDATE",
        trader: undefined, // Envio 生成的类型期望 undefined 而不是 null
        cumulativeRate: event.params.cumulativeFundingRate,
        payment: undefined, // Envio 生成的类型期望 undefined 而不是 null
        timestamp: event.block.timestamp,
    };
    context.FundingEvent.set(entity);
});

/**
 * Day 6: 处理用户资金费支付事件
 */
Exchange.FundingPaid.handler(async ({ event, context }) => {
    const entity: FundingEvent = {
        id: `${event.transaction.hash}-${event.logIndex}`,
        eventType: "USER_PAID",
        trader: event.params.trader.toLowerCase(), // 统一转为小写，与其他事件一致
        cumulativeRate: undefined, // Envio 生成的类型期望 undefined 而不是 null
        payment: event.params.amount,
        timestamp: event.block.timestamp,
    };
    context.FundingEvent.set(entity);
});

/**
 * Day 7: 处理清算事件
 */
Exchange.Liquidated.handler(async ({ event, context }) => {
    const entity: Liquidation = {
        id: `${event.transaction.hash}-${event.logIndex}`,
        trader: event.params.trader,
        liquidator: event.params.liquidator,
        amount: event.params.amount,
        fee: event.params.reward,
        timestamp: event.block.timestamp,
        txHash: event.transaction.hash,
    };
    context.Liquidation.set(entity);
    
    // 清算后持仓应该归零或减少
    const position = await context.Position.get(event.params.trader);
    if (position) {
        const newSize = position.size > 0n 
            ? position.size - event.params.amount 
            : position.size + event.params.amount;
        context.Position.set({
            ...position,
            size: newSize,
        });
    }
});

/**
 * Day 8+: 处理推荐人注册事件
 * 注意：需要先运行 pnpm codegen 生成类型后才能启用
 */
// Exchange.ReferralRegistered.handler(async ({ event, context }) => {
//     const referrer = event.params.referrer.toLowerCase();
//     
//     // 更新或创建返佣统计
//     let stat = await context.ReferralStat.get(referrer);
//     if (!stat) {
//         stat = {
//             id: referrer,
//             referrer: referrer,
//             inviteCount: 0,
//             totalRebateEarned: 0n,
//             lastUpdated: event.block.timestamp,
//         };
//     }
//     
//     context.ReferralStat.set({
//         ...stat,
//         inviteCount: stat.inviteCount + 1,
//         lastUpdated: event.block.timestamp,
//     });
// });

/**
 * Day 8+: 处理返佣支付事件
 * 注意：需要先运行 pnpm codegen 生成类型后才能启用
 */
// Exchange.RebatePaid.handler(async ({ event, context }) => {
//     const referrer = event.params.referrer.toLowerCase();
//     
//     // 创建返佣支付记录
//     const payment: RebatePayment = {
//         id: `${event.transaction.hash}-${event.logIndex}`,
//         trader: event.params.trader,
//         referrer: referrer,
//         feeAmount: event.params.feeAmount,
//         rebateAmount: event.params.rebateAmount,
//         timestamp: event.block.timestamp,
//         txHash: event.transaction.hash,
//     };
//     context.RebatePayment.set(payment);
//     
//     // 更新返佣统计
//     let stat = await context.ReferralStat.get(referrer);
//     if (!stat) {
//         stat = {
//             id: referrer,
//             referrer: referrer,
//             inviteCount: 0,
//             totalRebateEarned: 0n,
//             lastUpdated: event.block.timestamp,
//         };
//     }
//     
//     context.ReferralStat.set({
//         ...stat,
//         totalRebateEarned: stat.totalRebateEarned + event.params.rebateAmount,
//         lastUpdated: event.block.timestamp,
//     });
// });

/**
 * Day 8+: 处理VIP等级升级事件
 * 注意：需要先运行 pnpm codegen 生成类型后才能启用
 */
// Exchange.VIPLevelUpgraded.handler(async ({ event, context }) => {
//     const change: VIPLevelChange = {
//         id: `${event.transaction.hash}-${event.logIndex}`,
//         trader: event.params.trader,
//         oldLevel: Number(event.params.oldLevel),
//         newLevel: Number(event.params.newLevel),
//         timestamp: event.block.timestamp,
//         txHash: event.transaction.hash,
//     };
//     context.VIPLevelChange.set(change);
// });

/**
 * Day 8+: 处理交易手续费事件，更新用户交易量
 * 注意：需要先运行 pnpm codegen 生成类型后才能启用
 */
// Exchange.TradingFeeCharged.handler(async ({ event, context }) => {
//     const trader = event.params.trader.toLowerCase();
//     const notional = event.params.notional; // 名义价值 = 交易量
//     
//     // 更新或创建用户交易量记录
//     let volume = await context.UserVolume.get(trader);
//     if (!volume) {
//         volume = {
//             id: trader,
//             trader: trader,
//             volume30Days: 0n,
//             lastUpdated: event.block.timestamp,
//         };
//     }
//     
//     // 注意：这里只是简单累加，实际应该使用30天滚动窗口
//     // 完整的30天计算应该在Keeper或链上完成
//     context.UserVolume.set({
//         ...volume,
//         volume30Days: volume.volume30Days + notional,
//         lastUpdated: event.block.timestamp,
//     });
// });
