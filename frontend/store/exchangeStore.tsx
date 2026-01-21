import React, { createContext, useContext, useEffect } from 'react';
import { makeAutoObservable, runInAction } from 'mobx';
import { Address, Hash, parseAbiItem, parseEther, formatEther } from 'viem';
import { EXCHANGE_ABI } from '../onchain/abi';
import { EXCHANGE_ADDRESS, EXCHANGE_DEPLOY_BLOCK } from '../onchain/config';
import { chain, getWalletClient, publicClient, fallbackAccount, ACCOUNTS } from '../onchain/client';
import { OrderBookItem, OrderSide, OrderType, PositionSnapshot, Trade, CandleData, VIPLevel, VIPInfo } from '../types';
// Day 2: 启用 IndexerClient
import { client, GET_CANDLES, GET_RECENT_TRADES, GET_POSITIONS, GET_OPEN_ORDERS, GET_MY_TRADES } from './IndexerClient';

type OrderStruct = {
  id: bigint;
  trader: Address;
  isBuy: boolean;
  price: bigint;
  amount: bigint;
  initialAmount: bigint;
  timestamp: bigint;
  next: bigint;
};

type OrderBookState = {
  bids: OrderBookItem[];
  asks: OrderBookItem[];
};

export type OpenOrder = {
  id: bigint;
  isBuy: boolean;
  price: bigint;
  amount: bigint;
  initialAmount: bigint;
  timestamp: bigint;
  trader: Address;
};

class ExchangeStore {
  account?: Address;
  accountIndex = 0; // New observable state
  margin = 0n;

  position?: PositionSnapshot;
  markPrice = 0n;
  indexPrice = 0n;
  initialMarginBps = 100n; // Default 1%
  fundingRate = 0; // Estimated hourly funding rate
  orderBook: OrderBookState = { bids: [], asks: [] };
  trades: Trade[] = [];
  candles: CandleData[] = [];
  myOrders: OpenOrder[] = [];
  myTrades: Trade[] = [];
  syncing = false;
  cancellingOrderId?: bigint; // Day 2: 正在取消的订单 ID
  error?: string;
  walletClient = getWalletClient();
  
  // VIP相关状态
  vipInfo?: VIPInfo;
  baseMakerFeeBps = 0n; // 新版本不再使用
  baseTakerFeeBps = 0n; // 新版本不再使用
  private vipInfoLoading = false; // 防止重复加载
  private vipInfoLastLoad = 0; // 上次加载时间
  private contractErrorCount = 0; // 合约错误计数
  private maxContractErrors = 3; // 最大错误次数，超过后停止重试
  private contractValid = true; // 合约是否有效
  
  // 返佣相关状态
  referrer?: Address; // 当前用户的推荐人
  referralStats?: {
    inviteCount: number;
    totalRebateEarned: bigint;
  };

  constructor() {
    makeAutoObservable(this);
    
    // 立即设置默认VIP信息，确保界面能立即显示（不等待异步加载）
    runInAction(() => {
      this.vipInfo = {
        level: VIPLevel.VIP0,
        levelName: 'VIP 0',
        discountPercent: 0,
        cumulativeVolume: 0n,
        volumeToNext: 0n,
        makerFeeRate: 0.10,
        takerFeeRate: 0.10,
      };
    });
    
    this.autoConnect();
    this.refresh();
    // 定时刷新（静默模式，不触发 syncing 状态变化）
    setInterval(() => {
      this.refresh(true).catch(() => { });
    }, 2000); // 从 500ms 改为 2000ms，减少请求频率
    console.info('[store] 交易所 store 初始化完成，VIP信息已设置默认值');
  }

  ensureContract() {
    if (!EXCHANGE_ADDRESS) throw new Error('Set VITE_EXCHANGE_ADDRESS');
    return EXCHANGE_ADDRESS;
  }

  // 检查合约是否有效（是否有代码）
  private async checkContractValid(address: Address): Promise<boolean> {
    try {
      const code = await publicClient.getBytecode({ address });
      // 如果合约代码为空或只有0x，说明合约不存在
      return code !== undefined && code !== '0x' && code.length > 2;
    } catch (e) {
      console.error('[checkContractValid] 检查合约代码失败:', e);
      return false;
    }
  }

  autoConnect = async () => {
    // Check URL params first
    const params = new URLSearchParams(window.location.search);
    const urlAccount = params.get('account');
    if (urlAccount && urlAccount.startsWith('0x')) {
      runInAction(() => (this.account = urlAccount as Address));
      return;
    }

    if (fallbackAccount) {
      runInAction(() => (this.account = fallbackAccount.address));
      return;
    }

  };

  connectWallet = async () => {
    if (!this.walletClient) {
      runInAction(() => (this.error = 'No wallet configured'));
      return;
    }
    if ((this.walletClient as any).account?.address) {
      runInAction(() => (this.account = (this.walletClient as any).account.address));
    } else if (fallbackAccount) {
      runInAction(() => (this.account = fallbackAccount.address));
    }
  };

  switchAccount = () => {
    this.accountIndex = (this.accountIndex + 1) % ACCOUNTS.length;
    const newAccount = ACCOUNTS[this.accountIndex];
    this.walletClient = getWalletClient(newAccount);
    runInAction(() => {
      this.account = newAccount.address;
      this.refresh();
    });
  };

  mapOrder(data: any): OrderStruct {
    // 优先检查命名属性（viem 通常返回带命名属性的数组）
    if (data && typeof data.price !== 'undefined') {
      return {
        id: data.id,
        trader: data.trader,
        isBuy: data.isBuy,
        price: data.price,
        amount: data.amount,
        initialAmount: data.initialAmount,
        timestamp: data.timestamp,
        next: data.next,
      };
    }

    if (Array.isArray(data)) {
      return {
        id: data[0],
        trader: data[1],
        isBuy: data[2],
        price: data[3],
        amount: data[4],
        initialAmount: data[5],
        timestamp: data[6],
        next: data[7],
      };
    }
    return data as OrderStruct;
  }

  loadOrderChain = async (headId?: bigint | null) => {
    const head: OrderStruct[] = [];
    if (!headId || headId === 0n) return head;
    const visited = new Set<string>();
    let current: bigint | undefined | null = headId;
    for (let i = 0; i < 128 && typeof current === 'bigint' && current !== 0n; i++) {
      if (visited.has(current.toString())) break;
      visited.add(current.toString());
      const raw = await publicClient.readContract({
        abi: EXCHANGE_ABI,
        address: this.ensureContract(),
        functionName: 'orders',
        args: [current],
      } as any);
      const data = this.mapOrder(raw);
      if (data.id === 0n) break;
      head.push(data);
      current = data.next;
    }
    return head;
  };

  formatOrderBook = (orders: OrderStruct[], isBuy: boolean): OrderBookItem[] => {
    // 1. Filter valid orders
    const filtered = orders.filter((o) => o.isBuy === isBuy && o.amount > 0n);

    // 2. Aggregate by price
    const aggregated = new Map<number, number>();
    filtered.forEach((o) => {
      const price = Number(formatEther(o.price));
      const size = Number(formatEther(o.amount));
      aggregated.set(price, (aggregated.get(price) || 0) + size);
    });

    // 3. Convert to array
    const rows = Array.from(aggregated.entries()).map(([price, size]) => ({
      price,
      size,
      total: 0,
      depth: 0,
    }));

    // 4. Sort: Bids Descending / Asks Ascending
    rows.sort((a, b) => (isBuy ? b.price - a.price : a.price - b.price));

    // 5. Calculate cumulative total
    let running = 0;
    const result = rows.map((r) => {
      running += r.size;
      return { ...r, total: running };
    });

    // 6. Calculate relative depth
    const maxTotal = result.length > 0 ? result[result.length - 1].total : 0;
    return result.map((r) => ({
      ...r,
      depth: maxTotal > 0 ? Math.min(100, Math.round((r.total / maxTotal) * 100)) : 0,
    }));
  };

  // ============================================
  // Day 5: 从 Indexer 获取 K 线数据
  // ============================================
  loadCandles = async () => {
    try {
      const result = await client.query(GET_CANDLES, {}).toPromise();
      if (result.data?.Candle) {
        const candles = result.data.Candle.map((c: any) => ({
          time: new Date(c.timestamp * 1000).toISOString(),
          open: Number(formatEther(c.openPrice)),
          high: Number(formatEther(c.highPrice)),
          low: Number(formatEther(c.lowPrice)),
          close: Number(formatEther(c.closePrice)),
        }));
        runInAction(() => { this.candles = candles; });
      }
    } catch (e) {
      console.error('[loadCandles] error:', e);
    }
  };

  // ============================================
  // Day 5: 从 Indexer 获取最近成交（失败时从链上读取）
  // ============================================
  loadTrades = async (): Promise<Trade[]> => {
    try {
      const result = await client.query(GET_RECENT_TRADES, {}).toPromise();
      if (result.data?.Trade && result.data.Trade.length > 0) {
        const trades = result.data.Trade.map((t: any) => ({
          id: t.id,
          price: Number(formatEther(t.price)),
          amount: Number(formatEther(t.amount)),
          time: new Date(t.timestamp * 1000).toLocaleTimeString(),
          side: BigInt(t.buyOrderId) > BigInt(t.sellOrderId) ? 'buy' : 'sell',
        }));
        runInAction(() => { this.trades = trades; });
        return trades;
      }
    } catch (e) {
      console.warn('[loadTrades] Indexer failed, reading from chain:', e);
    }

    // 备用方案：从链上直接读取事件
    try {
      const address = this.ensureContract();
      const logs = await publicClient.getLogs({
        address,
        event: parseAbiItem('event TradeExecuted(uint256 indexed buyOrderId, uint256 indexed sellOrderId, uint256 price, uint256 amount, address buyer, address seller)'),
        fromBlock: BigInt(EXCHANGE_DEPLOY_BLOCK || 0),
      });

      const trades: Trade[] = logs
        .slice(-50) // 最近 50 笔
        .reverse() // 最新的在前
        .map((log) => ({
          id: `${log.transactionHash}-${log.logIndex}`,
          price: Number(formatEther(log.args.price || 0n)),
          amount: Number(formatEther(log.args.amount || 0n)),
          time: new Date(Number(log.blockNumber) * 1000).toLocaleTimeString(), // 近似时间
          side: (log.args.buyOrderId || 0n) > (log.args.sellOrderId || 0n) ? 'buy' : 'sell',
        }));

      runInAction(() => { this.trades = trades; });
      return trades;
    } catch (e) {
      console.error('[loadTrades] chain read error:', e);
    return [];
    }
  };

  // ============================================
  // Day 2: 从 Indexer 获取用户订单
  // ============================================
  loadMyOrders = async (trader: Address): Promise<OpenOrder[]> => {
    try {
      // 注意: indexer 存储的地址是小写格式，需要转换
      const result = await client.query(GET_OPEN_ORDERS, { trader: trader.toLowerCase() }).toPromise();
      const orders = result.data?.Order || [];
      return orders.map((o: any) => ({
        id: BigInt(o.id),
        isBuy: o.isBuy,
        price: BigInt(o.price),
        amount: BigInt(o.amount),
        initialAmount: BigInt(o.initialAmount),
        timestamp: BigInt(o.timestamp),
        trader: trader,
      }));
    } catch (e) {
      console.error('[loadMyOrders] error:', e);
      return [];
    }
  };

  // ============================================
  // Day 5: 从 Indexer 获取用户的成交历史
  // ============================================
  loadMyTrades = async (trader: Address): Promise<Trade[]> => {
    try {
      const result = await client.query(GET_MY_TRADES, { trader: trader.toLowerCase() }).toPromise();
      if (!result.data?.Trade) return [];
      const trades = result.data.Trade.map((t: any) => ({
        id: t.id,
        price: Number(formatEther(t.price)),
        amount: Number(formatEther(t.amount)),
        time: new Date(t.timestamp * 1000).toLocaleTimeString(),
        side: t.buyer.toLowerCase() === trader.toLowerCase() ? 'buy' : 'sell',
      }));
      runInAction(() => { this.myTrades = trades; });
      return trades;
    } catch (e) {
      console.error('[loadMyTrades] error:', e);
    return [];
    }
  };

  refresh = async (silent = false) => {
    try {
      if (!silent) {
        runInAction(() => {
          this.syncing = true;
          this.error = undefined;
        });
      }
      
      // 检查合约地址是否存在
      if (!EXCHANGE_ADDRESS) {
        console.warn('[refresh] 合约地址未配置，跳过刷新');
        return;
      }
      
      // 简化合约有效性检查：只在首次检查，失败也不阻止后续调用
      if (this.contractErrorCount === 0 && this.contractValid) {
        try {
          const isValid = await this.checkContractValid(EXCHANGE_ADDRESS);
          runInAction(() => {
            this.contractValid = isValid;
            if (!isValid) {
              console.warn('[refresh] 合约地址可能无效，但仍会尝试调用');
            } else {
              this.contractErrorCount = 0;
            }
          });
        } catch (e) {
          console.warn('[refresh] 合约有效性检查失败，继续尝试调用:', e);
        }
      }
      
      const address = EXCHANGE_ADDRESS;
      const [mark, index, bestBid, bestAsk, imBps] = await Promise.all([
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'markPrice' } as any) as Promise<bigint>,
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'indexPrice' } as any) as Promise<bigint>,
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'bestBuyId' } as any) as Promise<bigint>,
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'bestSellId' } as any) as Promise<bigint>,
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'initialMarginBps' } as any) as Promise<bigint>,
      ]);
      
      // 成功调用后重置错误计数和错误状态
      runInAction(() => {
        this.contractErrorCount = 0;
        this.contractValid = true;
        if (this.error?.includes('合约')) {
          this.error = undefined; // 清除合约相关错误
        }
      });
      console.debug('[orderbook] head ids', {
        bestBid: bestBid?.toString?.(),
        bestAsk: bestAsk?.toString?.(),
        address,
      });
      // Day 6: 计算资金费率
      const m = Number(formatEther(mark));
      const i = Number(formatEther(index));
      let fundingRate = 0;
      if (i > 0) {
        const premiumIndex = (m - i) / i;
        const interestRate = 0.0001; // 0.01%
        const clampRange = 0.0005;   // 0.05%
        let diff = interestRate - premiumIndex;
        if (diff > clampRange) diff = clampRange;
        if (diff < -clampRange) diff = -clampRange;
        fundingRate = premiumIndex + diff;
      }

      runInAction(() => {
        this.markPrice = mark;
        this.indexPrice = index;
        this.initialMarginBps = imBps;
        this.fundingRate = fundingRate;
      });

      if (this.account) {
        // ============================================
        // Day 1: 读取用户保证金余额和持仓
        // ============================================
        try {
          const [m, pos] = await Promise.all([
            publicClient.readContract({
              abi: EXCHANGE_ABI,
              address,
              functionName: 'margin',
              args: [this.account],
            } as any) as Promise<bigint>,
            publicClient.readContract({
              abi: EXCHANGE_ABI,
              address,
              functionName: 'getPosition',
              args: [this.account],
            } as any) as Promise<PositionSnapshot>,
          ]);

          runInAction(() => {
            this.margin = m;
            this.position = pos;
          });

          // 加载VIP信息和返佣信息（总是尝试加载，即使合约可能无效）
          // 注意：loadVIPInfo 内部会处理错误并设置默认值
          await Promise.all([
            this.loadVIPInfo(this.account).catch(e => {
              console.error('[refresh] loadVIPInfo 失败:', e);
              // 即使失败也设置默认值
              if (!this.vipInfo) {
                runInAction(() => {
                  this.vipInfo = {
                    level: VIPLevel.VIP0,
                    levelName: 'VIP 0',
                    discountPercent: 0,
                    cumulativeVolume: 0n,
                    volumeToNext: 0n,
                    makerFeeRate: 0.10,
                    takerFeeRate: 0.10,
                  };
                });
              }
            }),
            this.loadReferralInfo(this.account).catch(e => {
              console.error('[refresh] loadReferralInfo 失败:', e);
            }),
          ]);
        } catch (e) {
          console.error('[refresh] 读取用户数据失败:', e);
          const errorMsg = e instanceof Error ? e.message : String(e);
          
          // 检查是否是合约无效的错误
          if (errorMsg.includes('execution reverted') || 
              errorMsg.includes('invalid') || 
              errorMsg.includes('empty') ||
              errorMsg.includes('Contract address is invalid')) {
            runInAction(() => {
              this.contractErrorCount++;
              if (this.contractErrorCount >= this.maxContractErrors) {
                this.contractValid = false;
                this.error = '合约调用失败次数过多，请检查合约是否已部署';
                console.error('[refresh] 合约无效，停止后续调用');
                
                // 设置默认值，避免界面一直加载
                if (!this.vipInfo) {
                  this.vipInfo = {
                    level: VIPLevel.VIP0,
                    levelName: 'VIP 0',
                    discountPercent: 0,
                    cumulativeVolume: 0n,
                    volumeToNext: 0n,
                    makerFeeRate: 0.10,
                    takerFeeRate: 0.10,
                  };
                }
              }
            });
          }
        }
      }

      let bidsRaw: OrderStruct[] = [];
      let asksRaw: OrderStruct[] = [];
      try {
        [bidsRaw, asksRaw] = await Promise.all([this.loadOrderChain(bestBid), this.loadOrderChain(bestAsk)]);
      } catch (inner) {
        const msg = (inner as Error)?.message || 'Failed to load orderbook';
        console.error('[orderbook] loadOrderChain error', msg);
        // 订单簿加载失败不应该阻止其他功能，只记录错误
        runInAction(() => {
          if (!this.error) {
            this.error = msg;
          }
        });
      }

      const scanned: OrderStruct[] = [];
      const SCAN_LIMIT = 20;
      for (let i = 1; i <= SCAN_LIMIT; i++) {
        try {
          const id = BigInt(i);
          const raw = await publicClient.readContract({
            abi: EXCHANGE_ABI,
            address,
            functionName: 'orders',
            args: [id],
          } as any);
          const data = this.mapOrder(raw);
          console.debug('[orderbook] slot', i, data);
          if (data.id !== 0n) scanned.push(data);
        } catch (inner) {
          console.error('[orderbook] scan error', i.toString(), (inner as Error)?.message);
          break;
        }
      }
      console.debug(
        '[orderbook] scanned raw',
        scanned.map((o) => ({
          id: o.id.toString(),
          p: o.price.toString(),
          a: o.amount.toString(),
          isBuy: o.isBuy,
          next: o.next.toString(),
        })),
      );
      const merged = new Map<bigint, OrderStruct>();
      [...bidsRaw, ...asksRaw, ...scanned].forEach((o) => {
        if (o && o.id) merged.set(o.id, o);
      });
      const allOrders = Array.from(merged.values());
      const bids = allOrders.filter((o) => o.isBuy && o.amount > 0n);
      const asks = allOrders.filter((o) => !o.isBuy && o.amount > 0n);
      console.debug('[orderbook] bids/asks', {
        bids: bids.map((o) => ({ id: o.id.toString(), p: o.price.toString(), a: o.amount.toString() })),
        asks: asks.map((o) => ({ id: o.id.toString(), p: o.price.toString(), a: o.amount.toString() })),
        merged: merged.size,
      });
      runInAction(() => {
        this.orderBook = { bids: this.formatOrderBook(bids, true), asks: this.formatOrderBook(asks, false) };
      });

      // Day 5: 加载成交和 K 线数据
      await this.loadTrades();
      this.loadCandles();

      // Day 2: 从 Indexer 获取我的订单
      if (this.account) {
        const orders = await this.loadMyOrders(this.account);
        runInAction(() => { this.myOrders = orders; });
      }

      // Day 5: 从 Indexer 获取我的成交历史
      if (this.account) {
        await this.loadMyTrades(this.account);
      }
    } catch (e) {
      if (!silent) {
        runInAction(() => (this.error = (e as Error)?.message || 'Failed to sync exchange data'));
      }
    } finally {
      if (!silent) {
        runInAction(() => (this.syncing = false));
      }
    }
  };

  // ============================================
  // Day 1: 实现充值函数
  // ============================================
  deposit = async (ethAmount: string) => {
    if (!this.walletClient || !this.account) throw new Error('Connect wallet before depositing');
    const hash = await this.walletClient.writeContract({
      account: this.account,
      chain: this.walletClient.chain,
      address: this.ensureContract(),
      abi: EXCHANGE_ABI,
      functionName: 'deposit',
      value: parseEther(ethAmount),
    } as any);
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    if (receipt.status !== 'success') throw new Error('Transaction failed');
    await this.refresh();
  };

  // ============================================
  // Day 1: 实现提现函数
  // ============================================
  withdraw = async (amount: string) => {
    if (!this.walletClient || !this.account) throw new Error('Connect wallet before withdrawing');
    const parsed = parseEther(amount || '0');
    const hash = await this.walletClient.writeContract({
      account: this.account,
      chain: this.walletClient.chain,
      address: this.ensureContract(),
      abi: EXCHANGE_ABI,
      functionName: 'withdraw',
      args: [parsed],
    });
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    if (receipt.status !== 'success') throw new Error('Transaction failed');
    await this.refresh();
  };

  // ============================================
  // Day 2: 实现下单函数
  // ============================================
  placeOrder = async (params: { side: OrderSide; orderType?: OrderType; price?: string; amount: string; hintId?: string }) => {
    const { side, orderType = OrderType.LIMIT, price, amount, hintId } = params;
    if (!this.walletClient || !this.account) throw new Error('Connect wallet before placing orders');

    // 处理市价单：使用 markPrice 加滑点
    const currentPrice = this.markPrice > 0n ? this.markPrice : parseEther('1500');
    const parsedPrice = price ? parseEther(price) : currentPrice;
    const effectivePrice =
      orderType === OrderType.MARKET
        ? side === OrderSide.BUY
          ? currentPrice + parseEther('100')  // 买单加滑点
          : currentPrice - parseEther('100') > 0n ? currentPrice - parseEther('100') : 1n
        : parsedPrice;

    const parsedAmount = parseEther(amount);
    const parsedHint = hintId ? BigInt(hintId) : 0n;

    const hash = await this.walletClient.writeContract({
      account: this.account,
      address: this.ensureContract(),
      abi: EXCHANGE_ABI,
      functionName: 'placeOrder',
      args: [side === OrderSide.BUY, effectivePrice, parsedAmount, parsedHint],
      chain: undefined,
    } as any);

    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    if (receipt.status !== 'success') throw new Error('Transaction failed');
    await this.refresh();
  }

  // ============================================
  // Day 2: 实现取消订单函数
  // ============================================
  // ============================================
  // VIP相关方法
  // ============================================
  loadVIPInfo = async (trader: Address) => {
    console.log('[loadVIPInfo] 被调用，trader:', trader);
    
    // 防抖：如果正在加载，跳过
    if (this.vipInfoLoading) {
      console.log('[loadVIPInfo] 正在加载中，跳过重复调用');
      return;
    }
    
    // 防抖：如果最近5秒内加载过，跳过（但首次加载不受限制，因为vipInfoLastLoad初始为0）
    const now = Date.now();
    if (this.vipInfoLastLoad > 0 && now - this.vipInfoLastLoad < 5000) {
      console.log('[loadVIPInfo] 最近已加载，跳过（5秒内）');
      return;
    }

    this.vipInfoLoading = true;
    this.vipInfoLastLoad = now;

    console.log('[loadVIPInfo] 开始加载VIP信息，trader:', trader);
    
    // 如果合约地址未配置，直接设置默认值
    if (!EXCHANGE_ADDRESS) {
      console.warn('[loadVIPInfo] 合约地址未配置，使用默认值');
      runInAction(() => {
        this.vipInfo = {
          level: VIPLevel.VIP0,
          levelName: 'VIP 0',
          discountPercent: 0,
          cumulativeVolume: 0n,
          volumeToNext: 0n,
          makerFeeRate: 0.10,
          takerFeeRate: 0.10,
        };
        this.vipInfoLoading = false;
      });
      console.log('[loadVIPInfo] 已设置默认VIP信息（合约地址未配置）');
      return;
    }
    
    const address = EXCHANGE_ADDRESS;
    console.log('[loadVIPInfo] 合约地址:', address);
    
    try {
      
      // 检查合约是否有VIP相关函数（通过检查ABI）
      const hasVIPFunctions = EXCHANGE_ABI.some(
        (item: any) => item.type === 'function' && 
        (item.name === 'getVIPLevel' || item.name === 'vipLevels')
      );

      if (!hasVIPFunctions) {
        console.warn('[loadVIPInfo] VIP functions not found in ABI, using defaults');
        // 合约还没有VIP功能，设置默认值
        runInAction(() => {
          this.vipInfo = {
            level: VIPLevel.VIP0,
            levelName: 'VIP 0',
            discountPercent: 0,
            cumulativeVolume: 0n,
            volumeToNext: 0n,
            makerFeeRate: 0.10, // VIP0费率
            takerFeeRate: 0.10,
          };
          this.vipInfoLoading = false;
        });
        console.log('[loadVIPInfo] 已设置默认VIP信息（ABI中无VIP函数）');
        return;
      }

      console.log('[loadVIPInfo] 开始调用合约函数...');
      
      // 添加超时保护（10秒，增加超时时间）
      const timeoutPromise = new Promise<never>((_, reject) => {
        setTimeout(() => {
          console.error('[loadVIPInfo] 超时：10秒内未完成加载');
          reject(new Error('VIP info load timeout after 10s'));
        }, 10000);
      });

      // 并行读取所有VIP相关信息，带超时保护
      // 注意：新版本只使用固定费率，不再需要 baseMakerFeeBps/baseTakerFeeBps
      const result = await Promise.race([
        Promise.all([
          publicClient.readContract({
            abi: EXCHANGE_ABI,
            address,
            functionName: 'getVIPLevel',
            args: [trader],
          } as any) as Promise<number>,
          publicClient.readContract({
            abi: EXCHANGE_ABI,
            address,
            functionName: 'getCumulativeVolume',
            args: [trader],
          } as any) as Promise<bigint>,
          publicClient.readContract({
            abi: EXCHANGE_ABI,
            address,
            functionName: 'getVolumeToNextVIP',
            args: [trader],
          } as any) as Promise<bigint>,
          publicClient.readContract({
            abi: EXCHANGE_ABI,
            address,
            functionName: 'getActualFeeRate',
            args: [trader, false], // 使用taker费率（新版本统一费率）
          } as any) as Promise<bigint>,
        ]),
        timeoutPromise,
      ]) as [number, bigint, bigint, bigint];

      const [vipLevel, cumulativeVolume, volumeToNext, feeRateBps] = result;
      console.log('[loadVIPInfo] 合约调用成功:', { vipLevel, cumulativeVolume, volumeToNext, feeRateBps });

      const levelNames = ['VIP 0', 'VIP 1', 'VIP 2', 'VIP 3', 'VIP 4'];
      
      const level = vipLevel as VIPLevel;
      const levelName = levelNames[level] || 'Unknown';
      // 费率从 bps (基点) 转换为百分比：bps / 10000 = 百分比
      const feeRatePercent = Number(feeRateBps) / 10000;

      runInAction(() => {
        this.vipInfo = {
          level,
          levelName,
          discountPercent: 0, // 新版本不再使用折扣
          cumulativeVolume,
          volumeToNext,
          makerFeeRate: feeRatePercent, // 新版本统一费率
          takerFeeRate: feeRatePercent,
        };
        // 新版本不再使用baseMakerFeeBps和baseTakerFeeBps
        this.baseMakerFeeBps = 0n;
        this.baseTakerFeeBps = 0n;
        this.vipInfoLoading = false;
      });
      console.log('[loadVIPInfo] VIP信息已更新:', this.vipInfo);
    } catch (e) {
      console.error('[loadVIPInfo] 错误详情:', e);
      const errorMessage = e instanceof Error ? e.message : String(e);
      console.error('[loadVIPInfo] 错误消息:', errorMessage);
      
      // 检查是否是合约无效错误（但不阻止设置默认值）
      if (errorMessage.includes('execution reverted') || 
          errorMessage.includes('Contract address is invalid')) {
        runInAction(() => {
          this.contractErrorCount++;
          if (this.contractErrorCount >= this.maxContractErrors) {
            this.contractValid = false;
            console.error('[loadVIPInfo] 合约无效，停止重试');
          }
        });
      }
      
      // 无论什么错误，都设置默认值，确保界面能显示
      runInAction(() => {
        // 总是设置默认值，确保界面能显示（即使之前有值，错误时也重置为默认值）
        this.vipInfo = {
          level: VIPLevel.VIP0,
          levelName: 'VIP 0',
          discountPercent: 0,
          cumulativeVolume: 0n,
          volumeToNext: 0n,
          makerFeeRate: 0.10, // VIP0费率
          takerFeeRate: 0.10,
        };
        this.vipInfoLoading = false;
      });
      console.log('[loadVIPInfo] 已设置默认VIP信息（错误恢复）');
    }
  };

  checkVIPUpgrade = async () => {
    if (!this.account) return;
    try {
      const address = this.ensureContract();
      const walletClient = await this.walletClient;
      if (!walletClient) throw new Error('No wallet client');
      
      const hash = await (walletClient as any).writeContract({
        abi: EXCHANGE_ABI,
        address,
        functionName: 'checkVIPUpgrade',
        chain: undefined,
      } as any);
      await publicClient.waitForTransactionReceipt({ hash });
      await this.loadVIPInfo(this.account);
    } catch (e) {
      console.error('[checkVIPUpgrade] error:', e);
      throw e;
    }
  };

  // ============================================
  // 返佣相关方法
  // ============================================
  loadReferralInfo = async (trader: Address) => {
    try {
      const address = this.ensureContract();
      
      // 检查合约是否有返佣相关函数
      const hasReferralFunctions = EXCHANGE_ABI.some(
        (item: any) => item.type === 'function' && item.name === 'getReferrer'
      );

      if (!hasReferralFunctions) {
        return;
      }

      // 读取推荐人
      const referrerAddr = await publicClient.readContract({
        abi: EXCHANGE_ABI,
        address,
        functionName: 'getReferrer',
        args: [trader],
      } as any) as Address;

      runInAction(() => {
        this.referrer = referrerAddr !== '0x0000000000000000000000000000000000000000' ? referrerAddr : undefined;
      });

      // TODO: 从索引器获取返佣统计
      // 这里需要索引器提供GraphQL查询接口
    } catch (e) {
      console.error('[loadReferralInfo] error:', e);
    }
  };

  registerReferral = async (referrer: Address) => {
    if (!this.account) throw new Error('Connect wallet first');
    try {
      const address = this.ensureContract();
      const walletClient = await this.walletClient;
      if (!walletClient) throw new Error('No wallet client');
      
      const hash = await (walletClient as any).writeContract({
        abi: EXCHANGE_ABI,
        address,
        functionName: 'registerReferral',
        args: [referrer],
        chain: undefined,
      } as any);
      await publicClient.waitForTransactionReceipt({ hash });
      
      // 重新加载返佣信息
      await this.loadReferralInfo(this.account);
    } catch (e) {
      console.error('[registerReferral] error:', e);
      throw e;
    }
  };

  cancelOrder = async (orderId: bigint) => {
    if (!this.walletClient || !this.account) throw new Error('Connect wallet before cancelling orders');
    runInAction(() => { this.cancellingOrderId = orderId; });
    try {
      const hash = await this.walletClient.writeContract({
        account: this.account,
        address: this.ensureContract(),
        abi: EXCHANGE_ABI,
        functionName: 'cancelOrder',
        args: [orderId],
        chain: undefined,
      } as any);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status !== 'success') throw new Error('Transaction failed');
      await this.refresh();
    } finally {
      runInAction(() => { this.cancellingOrderId = undefined; });
    }
  }
}

const ExchangeStoreContext = createContext<ExchangeStore | null>(null);

export const ExchangeStoreProvider: React.FC<React.PropsWithChildren> = ({ children }) => {
  const storeRef = React.useRef<ExchangeStore>();
  if (!storeRef.current) {
    storeRef.current = new ExchangeStore();
  }
  useEffect(() => {
    // ensure initial refresh
    storeRef.current?.refresh().catch(() => { });
  }, []);
  return <ExchangeStoreContext.Provider value={storeRef.current}>{children}</ExchangeStoreContext.Provider>;
};

export const useExchangeStore = () => {
  const ctx = useContext(ExchangeStoreContext);
  if (!ctx) throw new Error('useExchangeStore must be used within ExchangeStoreProvider');
  return ctx;
};
