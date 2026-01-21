export interface CandleData {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface OrderBookItem {
  price: number;
  size: number;
  total: number;
  depth: number; // percentage for visual bar
}

export interface Trade {
  id: string;
  price: number;
  amount: number;
  time: string;
  side: 'buy' | 'sell';
  buyer?: string;
  seller?: string;
  txHash?: string;
}

export enum OrderSide {
  BUY = 'buy',
  SELL = 'sell'
}

export enum OrderType {
  MARKET = 'Market',
  LIMIT = 'Limit'
}

export interface PositionSnapshot {
  size: bigint;
  entryPrice: bigint;
}

export interface DisplayPosition {
  symbol: string;
  leverage?: number;
  size: number;
  entryPrice: number;
  markPrice: number;
  liqPrice?: number;
  pnl: number;
  pnlPercent: number;
  side: 'long' | 'short';
}

// VIP等级枚举（VIP 0-4体系）
export enum VIPLevel {
  VIP0 = 0,  // < 1,000 USD: 10 bps (0.10%)
  VIP1 = 1,  // ≥ 1,000 USD: 9 bps (0.09%)
  VIP2 = 2,  // ≥ 2,000 USD: 8 bps (0.08%)
  VIP3 = 3,  // ≥ 5,000 USD: 6 bps (0.06%)
  VIP4 = 4,  // ≥ 8,000 USD: 5 bps (0.05%)
}

// VIP等级信息
export interface VIPInfo {
  level: VIPLevel;
  levelName: string;
  discountPercent: number;
  cumulativeVolume: bigint;
  volumeToNext: bigint;
  makerFeeRate: number;
  takerFeeRate: number;
}

// VIP特权
export interface VIPPrivilege {
  name: string;
  description: string;
  icon: string;
  available: boolean;
}
