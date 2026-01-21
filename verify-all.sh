#!/bin/bash
set -e

echo "=== 1. 运行合约测试 ==="
cd contract
forge test --match-contract "Day" -vvv

echo ""
echo "=== 2. 检查服务状态 ==="
echo "Anvil: $(lsof -ti:8545 >/dev/null 2>&1 && echo '✅ 运行中' || echo '❌ 未运行')"
echo "Indexer: $(curl -s http://localhost:8080/health >/dev/null 2>&1 && echo '✅ 运行中' || echo '❌ 未运行')"
echo "Frontend: $(curl -s http://localhost:3000 >/dev/null 2>&1 && echo '✅ 运行中' || echo '❌ 未运行')"

echo ""
echo "=== 3. 验证合约地址 ==="
if [ -f "../frontend/.env.local" ]; then
  echo "合约地址: $(grep VITE_EXCHANGE_ADDRESS ../frontend/.env.local | cut -d'=' -f2)"
else
  echo "❌ frontend/.env.local 不存在，请先运行部署脚本"
fi

echo ""
echo "=== 验证完成 ==="
