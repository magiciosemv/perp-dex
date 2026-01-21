# VIP 扩展系统文档

> 本文档详细说明 Perp-DEX 项目中 VIP 等级系统的完整架构、实现细节和项目结构。

## 📋 目录

- [概述](#概述)
- [项目结构](#项目结构)
- [VIP 系统架构](#vip-系统架构)
- [智能合约实现](#智能合约实现)
- [前端实现](#前端实现)
- [索引器实现](#索引器实现)
- [Keeper 服务](#keeper-服务)
- [配置与部署](#配置与部署)
- [API 参考](#api-参考)

---

## 概述

VIP 扩展系统是基于用户**30天累计交易量**的等级体系，提供不同等级的手续费优惠。系统采用**固定费率模式**（而非折扣模式），每个 VIP 等级对应固定的手续费率。

### 核心特性

- ✅ **5个VIP等级**（VIP 0-4），基于30天交易量自动升级
- ✅ **固定费率体系**：每个等级对应固定手续费率（10 bps - 5 bps）
- ✅ **自动升级机制**：交易时自动检查并升级VIP等级
- ✅ **30天滚动窗口**：自动清理过期交易量记录
- ✅ **返佣系统集成**：10%手续费返佣给推荐人
- ✅ **完整前端展示**：VIP信息、进度、特权可视化

### VIP 等级体系

| 等级 | 交易量门槛 (30天) | 手续费率 | 费率 (BPS) | 说明 |
|------|------------------|---------|-----------|------|
| **VIP 0** | < 1,000 USD | 0.10% | 10 bps | 默认初始等级 |
| **VIP 1** | ≥ 1,000 USD | 0.09% | 9 bps | 入门门槛 |
| **VIP 2** | ≥ 2,000 USD | 0.08% | 8 bps | 进阶门槛 |
| **VIP 3** | ≥ 5,000 USD | 0.06% | 6 bps | 核心用户 |
| **VIP 4** | ≥ 8,000 USD | 0.05% | 5 bps | 顶级用户 |

---

## 项目结构

### 整体目录结构

```
perpm-course/
├── contract/                    # 智能合约
│   ├── src/
│   │   ├── core/
│   │   │   └── ExchangeStorage.sol    # 基础存储，包含VIP枚举和映射
│   │   ├── modules/
│   │   │   ├── FeeModule.sol          # 手续费计算，VIP费率配置
│   │   │   ├── VIPModule.sol          # VIP等级管理和升级逻辑
│   │   │   ├── ReferralModule.sol     # 返佣系统（继承VIPModule）
│   │   │   └── ...
│   │   └── Exchange.sol               # 主合约，集成所有模块
│   └── test/
│       └── ...
│
├── frontend/                    # React 前端
│   ├── components/
│   │   ├── VIPInfo.tsx               # VIP信息展示组件
│   │   ├── VIPProgress.tsx            # VIP进度条组件
│   │   ├── VIPPrivileges.tsx         # VIP特权列表组件
│   │   ├── VIPPanel.tsx              # VIP面板（整合所有VIP组件）
│   │   └── ReferralCenter.tsx        # 返佣中心组件
│   ├── store/
│   │   ├── exchangeStore.tsx         # MobX状态管理，包含VIP数据加载
│   │   └── IndexerClient.ts          # GraphQL客户端
│   ├── types.ts                      # TypeScript类型定义（VIPLevel等）
│   └── ...
│
├── indexer/                     # Envio 索引器
│   ├── schema.graphql               # GraphQL Schema（UserVolume, VIPLevelChange）
│   ├── src/
│   │   └── EventHandlers.ts          # 事件处理器（VIPLevelUpgraded等）
│   └── config.yaml                   # 索引器配置（事件定义）
│
├── keeper/                      # Keeper 服务
│   ├── src/
│   │   ├── services/
│   │   │   └── VIPKeeper.ts          # VIP等级自动更新服务
│   │   └── index.ts                  # 服务入口
│   └── ...
│
└── docs/                        # 文档
    └── vip-extension.md            # 本文档
```

### 模块依赖关系

```
ExchangeStorage (基础存储)
  └── FundingModule (资金费率)
      └── PricingModule (价格管理)
          └── FeeModule (手续费模块)
              ├── VIP费率配置 (tierFeeBps)
              ├── VIP升级阈值 (vipVolumeThresholds)
              └── 手续费计算（基于VIP等级）
                  └── VIPModule (VIP等级管理)
                      ├── 交易量更新 (_updateTradingVolume)
                      ├── VIP升级检查 (_checkAndUpgradeVIP)
                      └── ReferralModule (返佣系统)
                          └── LiquidationModule (清算模块)
                              └── OrderBookModule (订单簿模块)
```

---

## VIP 系统架构

### 数据流

```
用户交易
  ↓
OrderBookModule._executeTrade()
  ↓
LiquidationModule._updatePosition()
  ↓
VIPModule._updateTradingVolume()
  ├── 清理30天前的记录
  ├── 记录本次交易量
  ├── 重新计算累计交易量
  └── 检查并升级VIP等级
      ↓
FeeModule._chargeTradingFee()
  ├── 根据VIP等级获取费率
  ├── 计算手续费
  ├── 扣除用户保证金
  └── 分配返佣（如有推荐人）
```

### 核心存储结构

#### 智能合约存储

```solidity
// VIP等级枚举
enum VIPLevel {
    VIP0, VIP1, VIP2, VIP3, VIP4
}

// 用户VIP等级映射
mapping(address => VIPLevel) public vipLevels;

// 用户累计交易量（30天）
mapping(address => uint256) public cumulativeTradingVolume;

// 交易量历史记录（按天存储）
mapping(address => mapping(uint256 => uint256)) public volumeHistory;

// 交易量时间戳列表（用于清理）
mapping(address => uint256[]) public volumeTimestamps;

// VIP等级固定费率
mapping(VIPLevel => uint256) public tierFeeBps;

// VIP升级阈值
uint256[4] public vipVolumeThresholds;
```

#### 索引器存储（GraphQL）

```graphql
# 用户交易量统计
type UserVolume @entity {
  id: ID!                    # trader address
  trader: String!
  volume30Days: BigInt!      # 30天累计交易量（USD计价）
  lastUpdated: Int!
}

# VIP等级变更记录
type VIPLevelChange @entity {
  id: ID!
  trader: String!
  oldLevel: Int!
  newLevel: Int!
  timestamp: Int!
  txHash: String!
}
```

---

## 智能合约实现

### 1. ExchangeStorage.sol（基础存储）

**位置**: `contract/src/core/ExchangeStorage.sol`

**核心定义**:

```solidity
/// @notice VIP 等级枚举 (VIP 0-4，基于30天交易量)
enum VIPLevel {
    VIP0,  // < 1,000 USD: 10 bps (0.10%)
    VIP1,  // ≥ 1,000 USD: 9 bps (0.09%)
    VIP2,  // ≥ 2,000 USD: 8 bps (0.08%)
    VIP3,  // ≥ 5,000 USD: 6 bps (0.06%)
    VIP4   // ≥ 8,000 USD: 5 bps (0.05%)
}

/// @notice 用户VIP等级映射
mapping(address => VIPLevel) public vipLevels;

/// @notice VIP等级对应的固定费率 (基点)
mapping(VIPLevel => uint256) public tierFeeBps;

/// @notice VIP升级所需的最小交易量阈值
uint256[4] public vipVolumeThresholds;

/// @notice VIP等级升级事件
event VIPLevelUpgraded(address indexed trader, VIPLevel oldLevel, VIPLevel newLevel);
```

### 2. FeeModule.sol（手续费模块）

**位置**: `contract/src/modules/FeeModule.sol`

**核心功能**:

- **初始化VIP费率配置**:
  ```solidity
  function _initializeFeeParams() internal {
      tierFeeBps[VIPLevel.VIP0] = 10;  // 10 bps
      tierFeeBps[VIPLevel.VIP1] = 9;   // 9 bps
      tierFeeBps[VIPLevel.VIP2] = 8;   // 8 bps
      tierFeeBps[VIPLevel.VIP3] = 6;   // 6 bps
      tierFeeBps[VIPLevel.VIP4] = 5;   // 5 bps
      
      vipVolumeThresholds[0] = 1000 ether;  // VIP0 -> VIP1
      vipVolumeThresholds[1] = 2000 ether;  // VIP1 -> VIP2
      vipVolumeThresholds[2] = 5000 ether;  // VIP2 -> VIP3
      vipVolumeThresholds[3] = 8000 ether;  // VIP3 -> VIP4
  }
  ```

- **手续费计算**:
  ```solidity
  function _calculateTradingFee(address trader, uint256 notional, bool isMaker) 
      internal view returns (uint256 feeAmount) {
      VIPLevel level = vipLevels[trader];
      uint256 feeBps = tierFeeBps[level];
      feeAmount = (notional * feeBps) / 10000;
  }
  ```

### 3. VIPModule.sol（VIP等级管理）

**位置**: `contract/src/modules/VIPModule.sol`

**核心功能**:

#### 3.1 交易量更新

```solidity
function _updateTradingVolume(address trader, uint256 volume) internal {
    // 1. 清理30天前的交易量记录
    _cleanOldVolumeRecords(trader);
    
    // 2. 记录本次交易量（按天存储）
    uint256 currentDay = block.timestamp / 1 days;
    volumeHistory[trader][currentDay] += volume;
    
    // 3. 重新计算累计交易量
    _recalculateCumulativeVolume(trader);
    
    // 4. 检查并升级VIP等级
    _checkAndUpgradeVIP(trader);
}
```

#### 3.2 VIP升级逻辑

```solidity
function _checkAndUpgradeVIP(address trader) internal {
    VIPLevel currentLevel = vipLevels[trader];
    uint256 volume = cumulativeTradingVolume[trader];
    
    VIPLevel newLevel = VIPLevel.VIP0;
    
    // 从高到低检查阈值
    if (volume >= vipVolumeThresholds[3]) {
        newLevel = VIPLevel.VIP4;  // ≥ 8000 USD
    } else if (volume >= vipVolumeThresholds[2]) {
        newLevel = VIPLevel.VIP3;  // ≥ 5000 USD
    } else if (volume >= vipVolumeThresholds[1]) {
        newLevel = VIPLevel.VIP2;  // ≥ 2000 USD
    } else if (volume >= vipVolumeThresholds[0]) {
        newLevel = VIPLevel.VIP1;  // ≥ 1000 USD
    } else {
        newLevel = VIPLevel.VIP0;  // < 1000 USD
    }
    
    // 仅升级，不降级
    if (uint256(newLevel) > uint256(currentLevel)) {
        vipLevels[trader] = newLevel;
        emit VIPLevelUpgraded(trader, currentLevel, newLevel);
    }
}
```

#### 3.3 30天滚动窗口

```solidity
function _cleanOldVolumeRecords(address trader) internal {
    uint256 cutoffTime = block.timestamp - VOLUME_WINDOW; // 30 days
    uint256 cutoffDay = cutoffTime / 1 days;
    
    uint256[] storage timestamps = volumeTimestamps[trader];
    uint256 i = 0;
    
    while (i < timestamps.length) {
        if (timestamps[i] < cutoffDay) {
            delete volumeHistory[trader][timestamps[i]];
            timestamps[i] = timestamps[timestamps.length - 1];
            timestamps.pop();
        } else {
            i++;
        }
    }
}
```

#### 3.4 公共接口

```solidity
/// @notice 手动检查并升级VIP等级
function checkVIPUpgrade() external;

/// @notice 获取用户VIP等级
function getVIPLevel(address trader) external view returns (VIPLevel);

/// @notice 获取用户累计交易量（30天）
function getCumulativeVolume(address trader) external view returns (uint256);

/// @notice 获取距离下一级VIP所需的交易量
function getVolumeToNextVIP(address trader) external view returns (uint256);

/// @notice 管理员手动设置用户VIP等级
function setVIPLevel(address trader, VIPLevel level) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### 4. 集成点

**交易执行时自动更新VIP**:

在 `LiquidationModule._executeTrade()` 中：

```solidity
// 更新交易量（用于VIP升级）
uint256 notional = (amount * price) / 1e18;
_updateTradingVolume(buyer, notional);
_updateTradingVolume(seller, notional);
```

---

## 前端实现

### 1. 类型定义

**位置**: `frontend/types.ts`

```typescript
// VIP等级枚举
export enum VIPLevel {
  VIP0 = 0,  // < 1,000 USD: 10 bps (0.10%)
  VIP1 = 1,  // ≥ 1,000 USD: 9 bps (0.09%)
  VIP2 = 2,  // ≥ 2,000 USD: 8 bps (0.08%)
  VIP3 = 3,  // ≥ 5,000 USD: 6 bps (0.06%)
  VIP4 = 4,  // ≥ 8,000 USD: 5 bps (0.05%)
}

// VIP信息接口
export interface VIPInfo {
  level: VIPLevel;
  levelName: string;
  discountPercent: number;
  cumulativeVolume: bigint;
  volumeToNext: bigint;
  makerFeeRate: number;
  takerFeeRate: number;
}
```

### 2. 状态管理（MobX）

**位置**: `frontend/store/exchangeStore.tsx`

#### 2.1 VIP状态

```typescript
class ExchangeStore {
  // VIP相关状态
  vipInfo?: VIPInfo;
  private vipInfoLoading = false;
  private vipInfoLastLoad = 0;
  
  constructor() {
    // 立即设置默认VIP信息，确保界面能立即显示
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
}
```

#### 2.2 VIP信息加载

```typescript
loadVIPInfo = async (trader: Address) => {
  // 防抖：5秒内不重复加载
  if (this.vipInfoLoading) return;
  const now = Date.now();
  if (this.vipInfoLastLoad > 0 && now - this.vipInfoLastLoad < 5000) return;
  
  this.vipInfoLoading = true;
  this.vipInfoLastLoad = now;
  
  try {
    const address = this.ensureContract();
    
    // 超时保护：10秒
    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('超时')), 10000)
    );
    
    const result = await Promise.race([
      Promise.all([
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'getVIPLevel', args: [trader] } as any) as Promise<number>,
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'getCumulativeVolume', args: [trader] } as any) as Promise<bigint>,
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'getVolumeToNextVIP', args: [trader] } as any) as Promise<bigint>,
        publicClient.readContract({ abi: EXCHANGE_ABI, address, functionName: 'getFeeRateBps', args: [trader] } as any) as Promise<bigint>,
      ]),
      timeoutPromise,
    ]);
    
    const [vipLevel, cumulativeVolume, volumeToNext, feeRateBps] = result;
    
    const levelNames = ['VIP 0', 'VIP 1', 'VIP 2', 'VIP 3', 'VIP 4'];
    const feeRates = [0.10, 0.09, 0.08, 0.06, 0.05];
    
    runInAction(() => {
      this.vipInfo = {
        level: vipLevel as VIPLevel,
        levelName: levelNames[vipLevel] || 'VIP 0',
        discountPercent: 0, // 固定费率模式，无折扣概念
        cumulativeVolume: cumulativeVolume as bigint,
        volumeToNext: volumeToNext as bigint,
        makerFeeRate: Number(feeRateBps) / 10000,
        takerFeeRate: Number(feeRateBps) / 10000,
      };
    });
  } catch (e) {
    console.error('[loadVIPInfo] error:', e);
    // 错误时设置默认值，确保UI有内容显示
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
  } finally {
    this.vipInfoLoading = false;
  }
};
```

### 3. UI组件

#### 3.1 VIPInfo.tsx（VIP信息展示）

**位置**: `frontend/components/VIPInfo.tsx`

**功能**:
- 显示当前VIP等级（带图标和颜色）
- 显示当前手续费率
- 显示30天累计交易量
- 显示相比VIP 0节省的费用

**关键配置**:

```typescript
const VIP_COLORS = {
  [VIPLevel.VIP0]: 'text-gray-400',
  [VIPLevel.VIP1]: 'text-blue-400',
  [VIPLevel.VIP2]: 'text-green-400',
  [VIPLevel.VIP3]: 'text-purple-400',
  [VIPLevel.VIP4]: 'text-yellow-400',
};

const VIP_FEE_RATES = {
  [VIPLevel.VIP0]: 0.10,
  [VIPLevel.VIP1]: 0.09,
  [VIPLevel.VIP2]: 0.08,
  [VIPLevel.VIP3]: 0.06,
  [VIPLevel.VIP4]: 0.05,
};
```

#### 3.2 VIPProgress.tsx（VIP进度条）

**位置**: `frontend/components/VIPProgress.tsx`

**功能**:
- 显示当前VIP等级
- 显示距离下一级所需的交易量
- 进度条可视化

#### 3.3 VIPPrivileges.tsx（VIP特权列表）

**位置**: `frontend/components/VIPPrivileges.tsx`

**功能**:
- 列出每个VIP等级的特权
- 高亮当前等级已解锁的特权

#### 3.4 VIPPanel.tsx（VIP面板）

**位置**: `frontend/components/VIPPanel.tsx`

**功能**:
- 整合所有VIP相关组件
- 提供标签页切换（VIP信息、特权、返佣）

---

## 索引器实现

### 1. GraphQL Schema

**位置**: `indexer/schema.graphql`

```graphql
# 用户交易量统计（30天滚动窗口）
type UserVolume @entity {
  id: ID!                    # trader address
  trader: String!
  volume30Days: BigInt!      # 30天累计交易量（USD计价）
  lastUpdated: Int!
}

# VIP等级变更记录
type VIPLevelChange @entity {
  id: ID!
  trader: String!
  oldLevel: Int!
  newLevel: Int!
  timestamp: Int!
  txHash: String!
}
```

### 2. 事件配置

**位置**: `indexer/config.yaml`

```yaml
events:
  # Day 8+: VIP和返佣事件
  - event: VIPLevelUpgraded(address indexed trader, uint8 oldLevel, uint8 newLevel)
  - event: TradingFeeCharged(address indexed trader, uint256 notional, uint256 feeAmount, bool isMaker, uint8 vipLevel)
```

### 3. 事件处理器

**位置**: `indexer/src/EventHandlers.ts`

```typescript
// 注意：需要先运行 pnpm codegen 生成类型后才能启用

Exchange.VIPLevelUpgraded.handler(async ({ event, context }) => {
    const change: VIPLevelChange = {
        id: `${event.transaction.hash}-${event.logIndex}`,
        trader: event.params.trader.toLowerCase(),
        oldLevel: Number(event.params.oldLevel),
        newLevel: Number(event.params.newLevel),
        timestamp: event.block.timestamp,
        txHash: event.transaction.hash,
    };
    context.VIPLevelChange.set(change);
});

Exchange.TradingFeeCharged.handler(async ({ event, context }) => {
    const trader = event.params.trader.toLowerCase();
    const notional = event.params.notional;
    
    // 更新或创建用户交易量记录
    let volume = await context.UserVolume.get(trader);
    if (!volume) {
        volume = {
            id: trader,
            trader: trader,
            volume30Days: 0n,
            lastUpdated: event.block.timestamp,
        };
    }
    
    // 注意：这里只是简单累加，实际应该使用30天滚动窗口
    context.UserVolume.set({
        ...volume,
        volume30Days: volume.volume30Days + notional,
        lastUpdated: event.block.timestamp,
    });
});
```

---

## Keeper 服务

### VIPKeeper.ts

**位置**: `keeper/src/services/VIPKeeper.ts`

**功能**:
- 定期（默认1小时）检查用户VIP等级
- 从索引器获取用户30天交易量
- 计算理论VIP等级
- 如果与链上等级不一致，调用 `setVIPLevel` 更新

**实现要点**:

```typescript
export class VIPKeeper {
  constructor(exchangeAddress: Address, intervalMs: number = 3600000) {
    // 默认1小时执行一次
  }
  
  start() {
    this.run();
    this.intervalId = setInterval(() => this.run(), this.intervalMs);
  }
  
  private async run() {
    // 1. 从索引器获取用户交易量
    const users = await this.fetchUserVolumes();
    
    // 2. 批量更新VIP等级
    for (const user of users) {
      await this.updateUserVIPLevel(user.address, user.volume30Days);
    }
  }
  
  private calculateVIPLevel(volume30Days: bigint): number {
    const thresholds = [
      parseEther('1000'),  // VIP0 -> VIP1
      parseEther('2000'),  // VIP1 -> VIP2
      parseEther('5000'),  // VIP2 -> VIP3
      parseEther('8000'),  // VIP3 -> VIP4
    ];
    
    if (volume30Days >= thresholds[3]) return 4;
    if (volume30Days >= thresholds[2]) return 3;
    if (volume30Days >= thresholds[1]) return 2;
    if (volume30Days >= thresholds[0]) return 1;
    return 0;
  }
}
```

**集成**: 在 `keeper/src/index.ts` 中启动：

```typescript
import { VIPKeeper } from './services/VIPKeeper';

const vipKeeper = new VIPKeeper(EXCHANGE_ADDRESS, 3600000); // 1小时
vipKeeper.start();
```

---

## 配置与部署

### 1. 智能合约初始化

在 `Exchange.sol` 构造函数中：

```solidity
constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(OPERATOR_ROLE, msg.sender);
    lastFundingTime = block.timestamp;
    _initializeFeeParams(); // 初始化VIP费率配置
}
```

### 2. 前端环境变量

**位置**: `frontend/.env.local`

```bash
VITE_RPC_URL=http://127.0.0.1:8545
VITE_CHAIN_ID=31337
VITE_EXCHANGE_ADDRESS=0x...  # 部署后的合约地址
VITE_INDEXER_URL=http://localhost:8080/v1/graphql  # 可选
```

### 3. 索引器配置

**位置**: `indexer/config.yaml`

```yaml
networks:
  - id: 31337
    start_block: 0
    rpc_config:
      url: http://127.0.0.1:8545
    contracts:
      - name: Exchange
        address:
          - 0x...  # 实际部署地址
```

### 4. Keeper配置

**位置**: `keeper/.env`

```bash
PRIVATE_KEY=0x...  # Keeper钱包私钥（需要有DEFAULT_ADMIN_ROLE）
RPC_URL=http://127.0.0.1:8545
EXCHANGE_ADDRESS=0x...  # 合约地址
```

---

## API 参考

### 智能合约接口

#### 查询接口

```solidity
/// @notice 获取用户VIP等级
function getVIPLevel(address trader) external view returns (VIPLevel);

/// @notice 获取用户累计交易量（30天）
function getCumulativeVolume(address trader) external view returns (uint256);

/// @notice 获取距离下一级VIP所需的交易量
function getVolumeToNextVIP(address trader) external view returns (uint256);

/// @notice 获取用户的VIP费率（基点）
function getFeeRateBps(address trader) external view returns (uint256);
```

#### 操作接口

```solidity
/// @notice 手动检查并升级VIP等级
function checkVIPUpgrade() external;

/// @notice 管理员手动设置用户VIP等级
function setVIPLevel(address trader, VIPLevel level) external onlyRole(DEFAULT_ADMIN_ROLE);
```

#### 管理员接口

```solidity
/// @notice 设置VIP等级费率
function setTierFeeBps(VIPLevel tier, uint256 feeBps) external onlyRole(DEFAULT_ADMIN_ROLE);

/// @notice 设置VIP升级阈值
function setVIPThresholds(uint256[4] calldata thresholds) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### GraphQL 查询

#### 查询用户交易量

```graphql
query GetUserVolume($trader: String!) {
  UserVolume(where: { trader: { _eq: $trader } }) {
    trader
    volume30Days
    lastUpdated
  }
}
```

#### 查询VIP等级变更历史

```graphql
query GetVIPLevelChanges($trader: String!) {
  VIPLevelChange(
    where: { trader: { _eq: $trader } }
    order_by: { timestamp: desc }
    limit: 10
  ) {
    id
    trader
    oldLevel
    newLevel
    timestamp
    txHash
  }
}
```

---

## 总结

VIP 扩展系统是一个完整的、基于交易量的等级体系，包含：

1. **智能合约层**：VIP等级管理、交易量跟踪、自动升级
2. **前端层**：VIP信息展示、进度可视化、特权列表
3. **索引器层**：事件索引、交易量统计、历史记录
4. **Keeper层**：自动同步VIP等级

系统采用**固定费率模式**，每个VIP等级对应固定的手续费率，简化了费率计算逻辑，同时保持了清晰的等级区分。

---

**文档版本**: v1.0  
**最后更新**: 2025-01-XX  
**维护者**: Perp-DEX 开发团队
