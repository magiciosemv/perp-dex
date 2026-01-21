#!/usr/bin/env bash
# 检查所有服务状态
set -euo pipefail

echo "=================================================="
echo "   服务状态检查"
echo "=================================================="

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_service() {
    local name=$1
    local command=$2
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} $name: 运行中"
        return 0
    else
        echo -e "${RED}❌${NC} $name: 未运行"
        return 1
    fi
}

# 1. 检查 Anvil
echo ""
echo "1. 区块链服务"
check_service "Anvil" "cast chain-id --rpc-url http://127.0.0.1:8545"

# 2. 检查合约
if [ -f "frontend/.env.local" ]; then
    EXCHANGE=$(grep VITE_EXCHANGE_ADDRESS frontend/.env.local | cut -d'=' -f2)
    if [ -n "$EXCHANGE" ]; then
        if cast code "$EXCHANGE" --rpc-url http://127.0.0.1:8545 >/dev/null 2>&1; then
            echo -e "${GREEN}✅${NC} 合约: 已部署 ($EXCHANGE)"
            
            # 检查VIP功能
            if cast call "$EXCHANGE" "getVIPLevel(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:8545 >/dev/null 2>&1; then
                echo -e "${GREEN}✅${NC} VIP功能: 可用"
            else
                echo -e "${YELLOW}⚠️${NC} VIP功能: 不可用（合约可能未包含VIP功能）"
            fi
        else
            echo -e "${RED}❌${NC} 合约: 部署失败或地址无效"
        fi
    else
        echo -e "${RED}❌${NC} 合约: 地址未配置"
    fi
else
    echo -e "${RED}❌${NC} 合约: .env.local 文件不存在"
fi

# 3. 检查前端
echo ""
echo "2. 前端服务"
check_service "前端 (Vite)" "curl -s http://localhost:3000 >/dev/null"

# 4. 检查索引器
echo ""
echo "3. 索引器服务"
check_service "PostgreSQL" "docker ps | grep postgres"
check_service "索引器 (Envio)" "curl -s http://localhost:8080/v1/graphql -X POST -H 'Content-Type: application/json' -d '{\"query\":\"{ __typename }\"}' >/dev/null"

# 5. 检查 Keeper
echo ""
echo "4. Keeper 服务"
# 检查 keeper 目录下的 ts-node 进程
# 方法1: 检查进程的工作目录或命令行是否包含 keeper
KEEPER_RUNNING=false
if ps aux | grep -E "[t]s-node.*keeper" 2>/dev/null | grep -v grep | grep -q .; then
    KEEPER_RUNNING=true
elif ps aux | grep -E "[t]s-node.*src/index" 2>/dev/null | grep -v grep | grep -q "keeper"; then
    KEEPER_RUNNING=true
elif pgrep -f "ts-node.*keeper" >/dev/null 2>&1; then
    KEEPER_RUNNING=true
fi

# 方法2: 检查进程的 cwd 是否在 keeper 目录
if [ "$KEEPER_RUNNING" = false ]; then
    for pid in $(pgrep -f "ts-node.*src/index" 2>/dev/null); do
        if [ -n "$pid" ]; then
            cwd=$(readlink -f /proc/$pid/cwd 2>/dev/null || echo "")
            if echo "$cwd" | grep -q "keeper"; then
                KEEPER_RUNNING=true
                break
            fi
        fi
    done
fi

if [ "$KEEPER_RUNNING" = true ]; then
    echo -e "${GREEN}✅${NC} Keeper: 运行中"
else
    echo -e "${YELLOW}⚠️${NC} Keeper: 未运行（可选服务）"
    echo "   提示: 如果 keeper 在运行但检测不到，请检查进程: ps aux | grep ts-node | grep keeper"
fi

# 6. 检查文件
echo ""
echo "5. 配置文件"
if [ -f "frontend/.env.local" ]; then
    echo -e "${GREEN}✅${NC} frontend/.env.local: 存在"
else
    echo -e "${RED}❌${NC} frontend/.env.local: 不存在"
fi

if [ -f "frontend/onchain/ExchangeABI.ts" ]; then
    echo -e "${GREEN}✅${NC} frontend/onchain/ExchangeABI.ts: 存在"
    
    # 检查ABI中是否有VIP函数
    if grep -q "getVIPLevel\|getCumulativeVolume" frontend/onchain/ExchangeABI.ts 2>/dev/null; then
        echo -e "${GREEN}✅${NC} ABI包含VIP函数"
    else
        echo -e "${YELLOW}⚠️${NC} ABI不包含VIP函数（需要重新部署）"
    fi
else
    echo -e "${RED}❌${NC} frontend/onchain/ExchangeABI.ts: 不存在"
fi

echo ""
echo "=================================================="
echo "   检查完成"
echo "=================================================="
echo ""
echo "如果发现问题，请参考："
echo "  - docs/COMPLETE_SETUP_GUIDE.md (完整启动指南)"
echo "  - docs/fee-vip-system.md (VIP系统说明)"
echo ""
