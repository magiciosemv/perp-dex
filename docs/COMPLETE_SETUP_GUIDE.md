# 完整项目启动指南

> 详细说明如何启动所有服务，包括VIP和手续费系统

## 📋 目录

- [环境准备](#环境准备)
- [完整启动流程](#完整启动流程)
- [服务检查清单](#服务检查清单)
- [VIP功能验证](#vip功能验证)
- [故障排查](#故障排查)
- [项目完善说明](#项目完善说明)

---

## 环境准备

### 必需软件安装

#### 1. Foundry（智能合约开发工具）

```bash
# 安装 Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 验证安装
forge --version
cast --version
anvil --version
```

#### 2. Node.js 和包管理器

```bash
# 检查 Node.js 版本（需要 >= 18）
node --version

# 安装 pnpm（用于 indexer）
npm install -g pnpm

# 验证
pnpm --version
```

#### 3. Docker（索引器需要）

```bash
# 检查 Docker
docker --version
docker compose version

# 确保 Docker 服务运行
sudo systemctl start docker  # Linux
# 或启动 Docker Desktop (macOS/Windows)
```

#### 4. jq（JSON处理工具，强烈推荐）

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# 验证
jq --version
```

### 验证所有工具

```bash
# 运行验证脚本
forge --version && \
cast --version && \
anvil --version && \
node --version && \
pnpm --version && \
docker --version && \
jq --version && \
echo "✅ 所有工具已安装"
```

---

## 完整启动流程

### 方法一：一键启动（推荐）

```bash
# 1. 进入项目目录
cd /home/magic/MonCode/perpm-course

# 2. 一键启动所有服务
./quickstart.sh
```

**这个脚本会自动：**
1. ✅ 停止旧服务并清理
2. ✅ 启动 Anvil 本地链
3. ✅ 编译并部署智能合约（包含VIP功能）
4. ✅ 生成前端配置文件（.env.local）
5. ✅ 复制合约ABI到前端
6. ✅ 启动 Docker（PostgreSQL）
7. ✅ 启动索引器（Envio）
8. ✅ 启动前端界面
9. ✅ 启动 Keeper 服务
10. ✅ 等待服务就绪后填充测试数据

**等待时间**：约 30-60 秒

**访问地址**：
- 前端界面: http://localhost:3000
- Anvil RPC: http://127.0.0.1:8545
- 索引器 GraphQL: http://localhost:8080/v1/graphql

---

### 方法二：手动分步启动

如果一键启动遇到问题，可以分步执行：

#### 步骤 1: 停止旧服务并清理

```bash
./scripts/stop.sh
```

这会停止所有运行中的服务。

#### 步骤 2: 启动 Anvil 并部署合约

```bash
./scripts/run-anvil-deploy.sh
```

**这个脚本会：**
- 启动 Anvil（端口 8545）
- 编译智能合约
- 部署 MonadPerpExchange 合约（包含VIP功能）
- 自动生成 `frontend/.env.local`
- 复制 ABI 到 `frontend/onchain/ExchangeABI.ts`
- 更新索引器配置

**重要检查点**：
```bash
# 检查 .env.local 是否生成
cat frontend/.env.local

# 应该包含：
# VITE_EXCHANGE_ADDRESS=0x...
# VITE_RPC_URL=http://127.0.0.1:8545
# VITE_CHAIN_ID=31337

# 检查 ABI 是否生成
ls -la frontend/onchain/ExchangeABI.ts

# 检查合约是否部署成功
cast call $(grep VITE_EXCHANGE_ADDRESS frontend/.env.local | cut -d'=' -f2) "markPrice()" --rpc-url http://127.0.0.1:8545
```

#### 步骤 3: 启动索引器

```bash
cd indexer

# 安装依赖（首次运行）
pnpm install

# 生成代码
pnpm codegen

# 启动 Docker 服务（PostgreSQL）
docker compose -f generated/docker-compose.yaml up -d

# 等待 PostgreSQL 就绪（约5秒）
sleep 5

# 启动索引器（开发模式）
TUI_OFF=true HASURA_CONSOLE_ENABLED=false BROWSER=none pnpm dev
```

**检查索引器**：
```bash
# 在另一个终端检查索引器日志
tail -f output/logs/indexer.log

# 或访问 GraphQL Playground
# http://localhost:8080/v1/graphql
```

#### 步骤 4: 启动前端

```bash
cd frontend

# 安装依赖（首次运行）
npm install

# 启动开发服务器
npm run dev
```

**检查前端**：
- 访问 http://localhost:3000
- 打开浏览器开发者工具（F12）
- 查看 Console 是否有错误

#### 步骤 5: 启动 Keeper 服务（可选）

```bash
cd keeper

# 安装依赖（首次运行）
npm install

# 创建 .env 文件（如果不存在）
cat > .env <<EOF
RPC_URL=http://127.0.0.1:8545
EXCHANGE_ADDRESS=$(grep VITE_EXCHANGE_ADDRESS ../frontend/.env.local | cut -d'=' -f2)
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
EOF

# 启动 Keeper
npm run start
```

#### 步骤 6: 填充测试数据

```bash
# 返回项目根目录
cd ..

# 运行数据填充脚本
./scripts/seed.sh
```

这会创建一些测试订单和交易。

---

## 服务检查清单

### ✅ 服务状态检查

#### 1. Anvil 本地链

```bash
# 检查 Anvil 是否运行
curl http://127.0.0.1:8545

# 或使用 cast
cast chain-id --rpc-url http://127.0.0.1:8545
# 应该返回: 31337

# 检查进程
ps aux | grep anvil
```

#### 2. 智能合约

```bash
# 读取合约地址
EXCHANGE=$(grep VITE_EXCHANGE_ADDRESS frontend/.env.local | cut -d'=' -f2)

# 检查合约是否部署
cast code $EXCHANGE --rpc-url http://127.0.0.1:8545

# 检查标记价格（应该返回一个数字）
cast call $EXCHANGE "markPrice()" --rpc-url http://127.0.0.1:8545

# 检查VIP相关函数是否存在
cast call $EXCHANGE "getVIPLevel(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:8545
# 应该返回: 0 (Bronze)
```

#### 3. 前端服务

```bash
# 检查前端是否运行
curl http://localhost:3000

# 检查进程
ps aux | grep "vite\|node.*dev"
```

#### 4. 索引器

```bash
# 检查 Docker 容器
docker ps | grep postgres

# 检查索引器进程
ps aux | grep "envio\|indexer"

# 检查 GraphQL 端点
curl http://localhost:8080/v1/graphql -X POST -H "Content-Type: application/json" -d '{"query":"{ __typename }"}'
```

#### 5. Keeper 服务

```bash
# 检查进程
ps aux | grep "keeper\|ts-node"
```

---

## VIP功能验证

### 1. 检查合约VIP功能

```bash
# 设置合约地址
EXCHANGE=$(grep VITE_EXCHANGE_ADDRESS frontend/.env.local | cut -d'=' -f2)
ALICE="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# 检查VIP等级（应该返回 0 = Bronze）
cast call $EXCHANGE "getVIPLevel(address)" $ALICE --rpc-url http://127.0.0.1:8545

# 检查累计交易量（应该返回 0）
cast call $EXCHANGE "getCumulativeVolume(address)" $ALICE --rpc-url http://127.0.0.1:8545

# 检查基础费率
cast call $EXCHANGE "baseMakerFeeBps()" --rpc-url http://127.0.0.1:8545
cast call $EXCHANGE "baseTakerFeeBps()" --rpc-url http://127.0.0.1:8545

# 检查实际费率
cast call $EXCHANGE "getActualFeeRate(address,bool)" $ALICE true --rpc-url http://127.0.0.1:8545
cast call $EXCHANGE "getActualFeeRate(address,bool)" $ALICE false --rpc-url http://127.0.0.1:8545
```

### 2. 检查前端ABI

```bash
# 检查 ABI 文件是否存在
ls -la frontend/onchain/ExchangeABI.ts

# 检查 ABI 中是否包含VIP函数
grep -i "getVIPLevel\|getCumulativeVolume\|getActualFeeRate" frontend/onchain/ExchangeABI.ts
```

### 3. 前端验证步骤

1. **打开浏览器**
   - 访问 http://localhost:3000
   - 打开开发者工具（F12）

2. **连接钱包**
   - 点击 Header 右侧 "Connect Wallet"
   - 或使用测试账户按钮（Alice/Bob/Carol）

3. **检查VIP信息**
   - 右侧应该显示 VIP 面板
   - Header 应该显示 VIP 等级徽章
   - 如果显示"加载VIP信息中..."，检查 Console 错误

4. **查看 Console 日志**
   ```javascript
   // 应该看到类似日志
   [loadVIPInfo] VIP functions not found in ABI, using defaults
   // 或
   [loadVIPInfo] error: ...
   ```

### 4. 测试VIP功能

```bash
# 1. 存入保证金
cast send $EXCHANGE "deposit()" --value 100ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8545

# 2. 设置价格
cast send $EXCHANGE "updateIndexPrice(uint256)" 1500ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8545

# 3. 创建交易（增加交易量）
cast send $EXCHANGE "placeOrder(bool,uint256,uint256,uint256)" \
  true 1500ether 1ether 0 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8545

# 4. 检查交易量是否更新
cast call $EXCHANGE "getCumulativeVolume(address)" $ALICE --rpc-url http://127.0.0.1:8545
```

---

## 故障排查

### 问题 1: VIP信息一直加载

**症状**：前端显示"加载VIP信息中..."，一直不显示内容

**可能原因**：
1. 合约ABI中没有VIP函数
2. RPC连接失败
3. 合约调用超时

**解决步骤**：

#### 步骤 1: 检查ABI

```bash
# 检查 ABI 文件
cat frontend/onchain/ExchangeABI.ts | grep -i "getVIPLevel"

# 如果没有输出，说明ABI没有VIP函数
# 需要重新编译和部署合约
```

#### 步骤 2: 重新编译合约

```bash
cd contract

# 清理缓存
forge clean

# 重新编译
forge build

# 检查编译输出
ls -la out/Exchange.sol/MonadPerpExchange.json
```

#### 步骤 3: 重新部署

```bash
# 停止服务
./scripts/stop.sh

# 重新部署
./scripts/run-anvil-deploy.sh
```

#### 步骤 4: 检查前端ABI

```bash
# 确认 ABI 已更新
grep -i "getVIPLevel" frontend/onchain/ExchangeABI.ts

# 如果还是没有，手动复制
cd contract
jq '.abi' out/Exchange.sol/MonadPerpExchange.json > ../frontend/onchain/ExchangeABI.json
```

#### 步骤 5: 重启前端

```bash
cd frontend

# 停止前端（Ctrl+C）

# 清理缓存
rm -rf node_modules/.vite

# 重新启动
npm run dev
```

### 问题 2: 合约函数调用失败

**症状**：Console 显示 "execution reverted" 或 "function not found"

**解决**：

```bash
# 1. 确认合约地址正确
cat frontend/.env.local | grep VITE_EXCHANGE_ADDRESS

# 2. 测试合约调用
EXCHANGE=$(grep VITE_EXCHANGE_ADDRESS frontend/.env.local | cut -d'=' -f2)
cast call $EXCHANGE "markPrice()" --rpc-url http://127.0.0.1:8545

# 3. 如果失败，重新部署合约
./scripts/stop.sh
./scripts/run-anvil-deploy.sh
```

### 问题 3: 前端无法连接

**症状**：前端显示 "Set VITE_EXCHANGE_ADDRESS"

**解决**：

```bash
# 1. 检查 .env.local 文件
cat frontend/.env.local

# 2. 如果文件不存在或内容错误，重新部署
./scripts/run-anvil-deploy.sh

# 3. 手动创建（如果自动生成失败）
cat > frontend/.env.local <<EOF
VITE_RPC_URL=http://127.0.0.1:8545
VITE_CHAIN_ID=31337
VITE_EXCHANGE_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
VITE_EXCHANGE_DEPLOY_BLOCK=0
VITE_TEST_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
EOF
```

### 问题 4: 索引器无法启动

**症状**：索引器日志显示连接错误

**解决**：

```bash
# 1. 检查 Docker
docker ps

# 2. 重启 Docker 服务
cd indexer
docker compose -f generated/docker-compose.yaml down -v
docker compose -f generated/docker-compose.yaml up -d

# 3. 等待数据库就绪
sleep 10

# 4. 重新生成代码
pnpm codegen

# 5. 重启索引器
pnpm dev
```

### 问题 5: 端口被占用

**症状**：服务启动失败，提示端口被占用

**解决**：

```bash
# 检查端口占用
lsof -ti:8545  # Anvil
lsof -ti:3000  # 前端
lsof -ti:8080  # 索引器

# 杀死占用进程
kill -9 $(lsof -ti:8545)
kill -9 $(lsof -ti:3000)
kill -9 $(lsof -ti:8080)

# 或使用停止脚本
./scripts/stop.sh
```

---

## 项目完善说明

### 已实现的功能

#### 1. 智能合约
- ✅ 保证金管理（存入/提取）
- ✅ 订单簿系统（限价单）
- ✅ 撮合引擎
- ✅ 价格预言机
- ✅ 资金费率结算
- ✅ 清算系统
- ✅ **VIP等级系统**（5个等级）
- ✅ **手续费系统**（Maker/Taker，VIP折扣）

#### 2. 前端界面
- ✅ 交易界面（下单、订单簿、持仓）
- ✅ K线图（通过索引器）
- ✅ **VIP信息面板**（等级、交易量、手续费）
- ✅ **VIP特权展示**
- ✅ **VIP升级进度**

#### 3. 后端服务
- ✅ 事件索引器（Envio）
- ✅ Keeper服务（价格更新、清算）

### 项目结构

```
perpm-course/
├── contract/              # 智能合约
│   ├── src/
│   │   ├── core/
│   │   │   └── ExchangeStorage.sol  # 包含VIP存储
│   │   ├── modules/
│   │   │   ├── FeeModule.sol        # 手续费模块
│   │   │   ├── VIPModule.sol        # VIP模块
│   │   │   └── ...
│   │   └── Exchange.sol
│   ├── test/
│   └── script/
├── frontend/             # 前端界面
│   ├── components/
│   │   ├── VIPInfo.tsx
│   │   ├── VIPPanel.tsx
│   │   ├── VIPPrivileges.tsx
│   │   └── VIPProgress.tsx
│   ├── store/
│   │   └── exchangeStore.tsx  # 包含VIP加载逻辑
│   └── onchain/
│       └── ExchangeABI.ts     # 合约ABI
├── indexer/              # 事件索引器
├── keeper/               # Keeper服务
├── scripts/              # 启动脚本
└── docs/                 # 文档
    ├── fee-vip-system.md
    ├── frontend-vip-implementation.md
    └── COMPLETE_SETUP_GUIDE.md
```

### 启动顺序

```
1. Anvil (本地链)
   ↓
2. 合约部署
   ↓
3. Docker (PostgreSQL)
   ↓
4. 索引器 (Envio)
   ↓
5. 前端 (Vite)
   ↓
6. Keeper (可选)
```

### 服务依赖关系

```
前端 → Anvil RPC → 合约
前端 → 索引器 GraphQL → PostgreSQL
Keeper → Anvil RPC → 合约
索引器 → Anvil RPC → 合约事件
```

---

## 快速参考

### 常用命令

```bash
# 一键启动
./quickstart.sh

# 停止所有服务
./scripts/stop.sh

# 重新部署合约
./scripts/run-anvil-deploy.sh

# 填充测试数据
./scripts/seed.sh

# 查看日志
tail -f output/logs/anvil.log
tail -f output/logs/indexer.log
tail -f output/logs/frontend.log
```

### 重要文件

- `frontend/.env.local` - 前端配置
- `frontend/onchain/ExchangeABI.ts` - 合约ABI
- `indexer/config.yaml` - 索引器配置
- `contract/broadcast/.../run-latest.json` - 部署记录

### 访问地址

- 前端: http://localhost:3000
- Anvil RPC: http://127.0.0.1:8545
- 索引器: http://localhost:8080/v1/graphql

---

## 下一步

1. ✅ 所有服务已启动
2. ✅ VIP功能已验证
3. 📝 查看详细文档：
   - [手续费+VIP系统实现说明](fee-vip-system.md)
   - [前端VIP系统实现说明](frontend-vip-implementation.md)
   - [使用指南](USAGE_GUIDE.md)

**祝使用愉快！** 🚀
