import { formatEther } from 'viem';
import { walletClient, publicClient } from '../client';
import { EXCHANGE_ABI } from '../abi';
import { EXCHANGE_ADDRESS as ADDRESS } from '../config';

/**
 * Liquidator Service
 * 
 * 负责监控用户健康度并执行清算。
 */
export class Liquidator {
    private intervalId: NodeJS.Timeout | null = null;
    private isRunning = false;
    private activeTraders = new Set<string>();

    constructor(private intervalMs: number = 10000) { }

    async start() {
        if (this.isRunning) return;
        this.isRunning = true;
        console.log(`[Liquidator] Starting liquidation checks every ${this.intervalMs}ms...`);

        // Day 7: 监听事件以跟踪活跃交易者
        const unwatchOrderPlaced = publicClient.watchContractEvent({
            address: ADDRESS as `0x${string}`,
            abi: EXCHANGE_ABI,
            eventName: 'OrderPlaced',
            onLogs: (logs) => {
                logs.forEach(log => {
                    if (log.args.trader) {
                        this.activeTraders.add(log.args.trader.toLowerCase());
                    }
                });
            },
        });

        const unwatchTradeExecuted = publicClient.watchContractEvent({
            address: ADDRESS as `0x${string}`,
            abi: EXCHANGE_ABI,
            eventName: 'TradeExecuted',
            onLogs: (logs) => {
                logs.forEach(log => {
                    if (log.args.buyer) this.activeTraders.add(log.args.buyer.toLowerCase());
                    if (log.args.seller) this.activeTraders.add(log.args.seller.toLowerCase());
                });
            },
        });

        this.intervalId = setInterval(() => this.checkHealth(), this.intervalMs);
    }

    stop() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
        this.isRunning = false;
        console.log('[Liquidator] Stopped.');
    }

    /**
     * 检查所有活跃交易者的健康度
     * Day 7: 遍历活跃交易者，检查是否可清算
     */
    private async checkHealth() {
        if (this.activeTraders.size === 0) {
            console.log('[Liquidator] No active traders to check.');
            return;
        }

        console.log(`[Liquidator] Checking health for ${this.activeTraders.size} traders...`);

        for (const trader of Array.from(this.activeTraders)) {
            try {
                // 读取持仓
                const position = await publicClient.readContract({
                    address: ADDRESS as `0x${string}`,
                    abi: EXCHANGE_ABI,
                    functionName: 'getPosition',
                    args: [trader as `0x${string}`],
                }) as any;

                // 如果持仓为 0，跳过
                if (position.size === 0n) continue;

                // 检查是否可清算
                const canLiq = await publicClient.readContract({
                    address: ADDRESS as `0x${string}`,
                    abi: EXCHANGE_ABI,
                    functionName: 'canLiquidate',
                    args: [trader as `0x${string}`],
                }) as boolean;

                if (canLiq) {
                    console.log(`[Liquidator] Liquidating trader ${trader}...`);
                    try {
                        // 执行清算（amount=0 表示全部清算）
                        const hash = await walletClient.writeContract({
                            address: ADDRESS as `0x${string}`,
                            abi: EXCHANGE_ABI,
                            functionName: 'liquidate',
                            args: [trader as `0x${string}`, 0n],
                        });
                        await publicClient.waitForTransactionReceipt({ hash });
                        console.log(`[Liquidator] Liquidation successful, tx: ${hash}`);
                        // 清算后移除该交易者
                        this.activeTraders.delete(trader);
                    } catch (e: any) {
                        console.error(`[Liquidator] Failed to liquidate ${trader}:`, e?.message || e);
                    }
                }
            } catch (e) {
                console.error(`[Liquidator] Error checking trader ${trader}:`, e);
            }
        }
    }
}
