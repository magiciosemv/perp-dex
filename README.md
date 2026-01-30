# Monad Perp Exchange 课程

> ⚠️ 本仓库仅供教学与练习，不可用于生产环境。

基于 Monad 的永续合约交易所开发教程，覆盖完整的 DeFi 协议开发流程。

## 🎯 课程概览

7 天渐进式学习路径，从基础到完整系统：

| Day | 主题 | 核心内容 |
|-----|------|----------|
| **Day 1** | 保证金系统 | `deposit`, `withdraw`, 余额管理 |
| **Day 2** | 订单簿结构 | 链表实现, `placeOrder`, 价格优先级 |
| **Day 3** | 撮合引擎 | 买卖匹配, 持仓更新, PnL 计算 |
| **Day 4** | 价格预言机 | `updateIndexPrice`, 标记价计算 |
| **Day 5** | 资金费率 | Funding Rate 公式, 多空结算 |
| **Day 6** | 清算系统 | 健康度检查, 强制平仓, 奖励机制 |
| **Day 7** | 集成测试 | 端到端流程验证 |

## 📁 项目结构

```
├── contract/          # Solidity 智能合约 (Foundry)
│   ├── src/           # 主合约和模块
│   │   ├── core/      # 核心存储（包含VIP和返佣）
│   │   └── modules/   # 功能模块
│   │       ├── FeeModule.sol        # 手续费模块（固定费率+返佣）
│   │       ├── VIPModule.sol        # VIP等级管理
│   │       ├── ReferralModule.sol   # 返佣系统
│   │       └── ...
│   └── test/          # Day1-7 测试用例
├── frontend/          # React 交易界面
│   ├── components/
│   │   ├── VIPInfo.tsx          # VIP信息显示
│   │   ├── VIPPanel.tsx         # VIP面板（信息/特权/返佣）
│   │   ├── VIPProgress.tsx      # VIP升级进度
│   │   ├── VIPPrivileges.tsx    # VIP特权列表
│   │   └── ReferralCenter.tsx   # 返佣中心
│   └── store/         # MobX状态管理
├── indexer/           # Envio 事件索引器
│   ├── schema.graphql # 包含VIP和返佣实体
│   └── src/
├── keeper/            # 价格更新 & 清算服务
│   ├── src/services/
│   │   └── VIPKeeper.ts  # VIP等级自动更新
│   └── src/index.ts
├── scripts/           # 部署和运行脚本
└── docs/              # 课程文档
    ├── COMPLETE_SETUP_GUIDE.md              # 完整启动指南
    ├── COMMERCIAL_EXTENSION_IMPLEMENTATION.md  # 商业化扩展实施说明
    ├── IMPLEMENTATION_SUMMARY.md            # 实施总结
    └── ...
```

## 🚀 快速开始

### 前提条件

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil)
- [Node.js](https://nodejs.org/) >= 18
- [pnpm](https://pnpm.io/) (用于 indexer)
- [Docker](https://www.docker.com/) (索引器需要)
- [jq](https://stedolan.github.io/jq/) (推荐，用于JSON处理)

### 一键启动

```bash
# 启动所有服务（Anvil + 合约 + 索引器 + 前端 + Keeper）
./quickstart.sh

# 检查服务状态
./scripts/check-services.sh
```

**详细启动说明请参考**: [完整启动指南](docs/COMPLETE_SETUP_GUIDE.md)

### 手动运行

```bash
# 1. 安装合约依赖
cd contract && forge install

# 2. 运行测试
forge test

# 3. 按 Day 运行特定测试
forge test --match-contract Day1MarginTest -vvv
forge test --match-contract Day2OrderbookTest -vvv
# ... Day3-7
```

## 🖥️ 前端界面

React + Vite 构建的交易界面，包含以下组件：

| 组件 | 功能 |
|------|------|
| **Header** | 钱包连接、余额显示、VIP徽章 |
| **OrderForm** | 下单表单（买/卖、价格、数量） |
| **OrderBook** | 实时订单簿（买卖盘） |
| **Positions** | 持仓管理、PnL 显示 |
| **TradingChart** | K线图（通过索引器） |
| **VIPPanel** | VIP信息、特权、返佣中心 ✨ |

### 前端运行

```bash
cd frontend
cp .env.example .env.local  # 配置环境变量（通常自动生成）
npm install
npm run dev
```

### 环境变量

```env
VITE_RPC_URL=http://127.0.0.1:8545
VITE_CHAIN_ID=31337
VITE_EXCHANGE_ADDRESS=0x<部署后的合约地址>
```

## 📖 测试驱动学习

每个 Day 的测试文件对应一个功能模块：

```bash
# Day 1: 保证金存取
forge test --match-contract Day1MarginTest -vvv

# Day 2: 订单簿插入与优先级
forge test --match-contract Day2OrderbookTest -vvv

# Day 3: 撮合与持仓
forge test --match-contract Day3MatchingTest -vvv

# Day 4: 价格更新
forge test --match-contract Day4PriceUpdateTest -vvv

# Day 5: 资金费率
forge test --match-contract Day6FundingTest -vvv

# Day 6: 清算机制
forge test --match-contract Day6LiquidationTest -vvv

# Day 7: 端到端集成
forge test --match-contract Day7IntegrationTest -vvv
```

## 🏗️ 核心模块

| 模块 | 文件 | 职责 |
|------|------|------|
| **MarginModule** | `src/modules/MarginModule.sol` | 保证金存取、余额检查 |
| **OrderBookModule** | `src/modules/OrderBookModule.sol` | 订单簿链表、插入/删除 |
| **PricingModule** | `src/modules/PricingModule.sol` | 标记价、指数价更新 |
| **FundingModule** | `src/modules/FundingModule.sol` | 资金费率计算与结算 |
| **LiquidationModule** | `src/modules/LiquidationModule.sol` | 健康度检查、强制平仓 |
| **FeeModule** | `src/modules/FeeModule.sol` | 手续费计算和扣除（固定费率+返佣） |
| **VIPModule** | `src/modules/VIPModule.sol` | VIP等级管理和升级 |
| **ReferralModule** | `src/modules/ReferralModule.sol` | 推荐人绑定和返佣管理 |

## 🌟 商业化扩展功能（Day 8+）

### VIP等级体系

基于30天交易量自动判定VIP等级：

| 等级 | 交易量门槛 (30天) | 费率 |
|------|------------------|------|
| VIP 0 | < 1,000 USD | 10 bps (0.10%) |
| VIP 1 | ≥ 1,000 USD | 9 bps (0.09%) |
| VIP 2 | ≥ 2,000 USD | 8 bps (0.08%) |
| VIP 3 | ≥ 5,000 USD | 6 bps (0.06%) |
| VIP 4 | ≥ 8,000 USD | 5 bps (0.05%) |

### 返佣系统

- **推荐人绑定**：每个用户只能绑定一个推荐人（不可更改）
- **返佣比例**：10%手续费返佣给推荐人
- **手续费分配**：90%项目方 + 10%推荐人
- **实时到账**：返佣直接增加到推荐人保证金

### 前端功能

- **VIP信息面板**：显示等级、交易量、费率、升级进度
- **返佣中心**：邀请链接生成、推荐人绑定、返佣统计
- **自动识别**：通过URL参数（`?ref=0x...`）自动识别推荐人


### 课程文档
- [Day 1: 保证金系统](docs/day1-guide.md)
- [Day 2: 订单簿结构](docs/day2-guide.md)
- [Day 3: 撮合引擎](docs/day3-guide.md)
- [Day 4: 价格预言机](docs/day4-guide.md)
- [Day 5: 资金费率](docs/day5-guide.md)
- [Day 6: 清算系统](docs/day6-guide.md)
- [Day 7: 集成测试](docs/day7-guide.md)

## ⚠️ 声明

本项目仅用于教学目的，包含以下简化：

- 使用简化的资金费率公式
- 无时间加权平均价格 (TWAP)
- 无保险基金机制
- 单一交易对
- 测试私钥为 Anvil 公开默认值
- VIP交易量计算假设 1 USD = 1 MON（实际部署需调整）

**请勿用于真实资金交易。**

## License

MIT
