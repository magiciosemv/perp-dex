# 手续费+VIP系统实现说明

## 概述

本系统实现了完整的交易手续费管理和VIP等级系统，VIP等级与手续费折扣直接关联，鼓励用户增加交易量以获得更好的费率。

## 系统架构

### 模块结构

```
ExchangeStorage (基础存储)
  └── FundingModule (资金费率)
      └── PricingModule (价格管理)
          └── FeeModule (手续费模块)
              └── VIPModule (VIP等级管理)
                  └── LiquidationModule (清算模块)
                      └── OrderBookModule (订单簿模块)
```

## VIP等级系统

### VIP等级定义

系统包含5个VIP等级，每个等级对应不同的手续费折扣：

| VIP等级 | 折扣率 | 说明 |
|---------|--------|------|
| Bronze (青铜) | 0% | 默认等级，无折扣 |
| Silver (白银) | 5% | 30天累计交易量 ≥ 1,000 MON |
| Gold (黄金) | 10% | 30天累计交易量 ≥ 10,000 MON |
| Platinum (白金) | 20% | 30天累计交易量 ≥ 100,000 MON |
| Diamond (钻石) | 30% | 30天累计交易量 ≥ 1,000,000 MON |

### VIP升级机制

1. **自动升级**：每次交易后自动检查并升级VIP等级
2. **30天滚动窗口**：基于过去30天的累计交易量
3. **自动清理**：过期（超过30天）的交易量记录会自动清理
4. **手动检查**：用户可以调用 `checkVIPUpgrade()` 主动更新VIP等级

### VIP升级阈值（可配置）

```solidity
vipVolumeThresholds[0] = 1000 ether;      // Bronze -> Silver
vipVolumeThresholds[1] = 10000 ether;      // Silver -> Gold
vipVolumeThresholds[2] = 100000 ether;    // Gold -> Platinum
vipVolumeThresholds[3] = 1000000 ether;   // Platinum -> Diamond
```

## 手续费系统

### 手续费类型

系统区分两种手续费类型：

1. **Maker费率**（提供流动性）
   - 默认：0.2% (20 bps)
   - 适用于：订单簿中已存在的订单，被新订单匹配时

2. **Taker费率**（消耗流动性）
   - 默认：0.5% (50 bps)
   - 适用于：新进入的订单，立即与订单簿匹配时

### 手续费计算

实际手续费计算公式：

```
实际费率 = 基础费率 × VIP折扣率 / 10000
手续费 = 名义价值 × 实际费率 / 10000
```

**示例**：
- 用户VIP等级：Gold (10%折扣)
- 交易类型：Taker
- 名义价值：10,000 MON
- 基础Taker费率：0.5% (50 bps)
- 实际费率：50 × 9000 / 10000 = 45 bps (0.45%)
- 手续费：10,000 × 45 / 10000 = 45 MON

### 手续费扣除

- 手续费从用户保证金中扣除
- 如果保证金不足，扣除全部可用保证金
- 手续费累计到 `totalFeeCollected`
- 手续费可配置为发送到指定地址或销毁（默认销毁）

## 核心功能

### 1. 交易手续费扣除

在 `_executeTrade()` 函数中：
- 自动判断Maker/Taker角色
- 计算并扣除双方手续费
- 更新交易量用于VIP升级

### 2. VIP等级管理

**自动升级流程**：
```
交易执行
  ↓
更新交易量记录
  ↓
清理过期记录（30天前）
  ↓
重新计算累计交易量
  ↓
检查VIP升级条件
  ↓
如果满足，升级并触发事件
```

### 3. 交易量追踪

- 按天记录交易量（`volumeHistory[trader][day]`）
- 30天滚动窗口计算累计交易量
- 自动清理过期数据，节省gas

## 管理员功能

### 设置手续费参数

```solidity
function setFeeParams(
    uint256 makerFeeBps,    // Maker费率（基点）
    uint256 takerFeeBps,    // Taker费率（基点）
    address recipient       // 手续费接收地址（0=销毁）
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

**限制**：
- Maker/Taker费率最大10% (1000 bps)

### 设置VIP升级阈值

```solidity
function setVIPThresholds(
    uint256[4] calldata thresholds  // [Bronze->Silver, Silver->Gold, Gold->Platinum, Platinum->Diamond]
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

### 手动设置VIP等级

```solidity
function setVIPLevel(
    address trader,
    VIPLevel level
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

用于特殊活动或奖励特定用户。

## 视图函数

### 获取用户VIP信息

```solidity
// 获取VIP等级
function getVIPLevel(address trader) external view returns (VIPLevel)

// 获取累计交易量（30天）
function getCumulativeVolume(address trader) external view returns (uint256)

// 获取距离下一级VIP所需的交易量
function getVolumeToNextVIP(address trader) external view returns (uint256)
```

### 获取手续费信息

```solidity
// 获取手续费折扣率
function getFeeDiscount(address trader) external view returns (uint256 discountBps)

// 获取实际费率
function getActualFeeRate(address trader, bool isMaker) external view returns (uint256 feeBps)
```

### 获取完整账户信息

```solidity
function getAccountInfo(address trader)
    external
    view
    returns (
        uint256 margin_,
        Position memory position_,
        VIPLevel vipLevel_,
        uint256 cumulativeVolume_
    )
```

## 事件

### VIP相关事件

```solidity
event VIPLevelUpgraded(
    address indexed trader,
    VIPLevel oldLevel,
    VIPLevel newLevel
);
```

### 手续费相关事件

```solidity
event TradingFeeCharged(
    address indexed trader,
    uint256 notional,
    uint256 feeAmount,
    bool isMaker,
    VIPLevel vipLevel
);

event FeeParamsUpdated(
    uint256 makerFeeBps,
    uint256 takerFeeBps,
    address feeRecipient
);

event VIPThresholdsUpdated(uint256[4] thresholds);
```

## 使用示例

### 用户主动检查VIP升级

```solidity
// 用户调用检查VIP升级
exchange.checkVIPUpgrade();
```

### 查询用户VIP状态

```solidity
// 获取VIP等级
VIPLevel level = exchange.getVIPLevel(userAddress);

// 获取累计交易量
uint256 volume = exchange.getCumulativeVolume(userAddress);

// 获取距离下一级所需交易量
uint256 needed = exchange.getVolumeToNextVIP(userAddress);
```

### 管理员配置

```solidity
// 设置手续费：Maker 0.15%, Taker 0.4%，发送到金库地址
exchange.setFeeParams(15, 40, treasuryAddress);

// 调整VIP升级阈值
uint256[4] memory thresholds = [
    500 ether,    // Bronze -> Silver
    5000 ether,   // Silver -> Gold
    50000 ether,  // Gold -> Platinum
    500000 ether  // Platinum -> Diamond
];
exchange.setVIPThresholds(thresholds);
```

## 设计特点

### 1. 模块化设计
- 手续费和VIP功能独立模块，易于维护和扩展

### 2. Gas优化
- 按天记录交易量，减少存储操作
- 自动清理过期数据，避免存储膨胀

### 3. 灵活的配置
- 所有参数可配置（费率、阈值、接收地址）
- 支持管理员手动设置VIP等级

### 4. 完整的追踪
- 详细的交易量历史记录
- 完整的事件日志
- 丰富的视图函数

## 注意事项

1. **交易量计算**：基于名义价值（amount × price / 1e18）
2. **时间窗口**：30天滚动窗口，每天的交易量单独记录
3. **VIP降级**：系统不支持自动降级，一旦升级将保持（除非管理员手动调整）
4. **手续费不足**：如果保证金不足支付手续费，将扣除全部可用保证金
5. **清算交易**：清算时的交易也会计算手续费和更新交易量

## 未来扩展

可能的扩展方向：
1. 基于持仓量的VIP升级（持有一定数量的代币）
2. 推荐奖励系统（推荐用户获得VIP加成）
3. 手续费返佣机制
4. 多层级VIP特权（除了手续费折扣，还有其他特权）
5. NFT VIP卡系统
