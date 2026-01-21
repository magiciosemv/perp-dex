# 快速参考

## 启动命令

\`\`\`bash
# 一键启动所有服务
./quickstart.sh

# 停止所有服务
./scripts/stop.sh

# 检查服务状态
./scripts/check-services.sh

# 重新部署合约
./scripts/run-anvil-deploy.sh
\`\`\`

## VIP等级

| 等级 | 交易量 | 费率 |
|------|--------|------|
| VIP 0 | < 1,000 USD | 10 bps |
| VIP 1 | ≥ 1,000 USD | 9 bps |
| VIP 2 | ≥ 2,000 USD | 8 bps |
| VIP 3 | ≥ 5,000 USD | 6 bps |
| VIP 4 | ≥ 8,000 USD | 5 bps |

## 返佣规则

- 返佣比例：10%
- 分配方式：90%项目方 + 10%推荐人
- 到账方式：实时到账（直接增加保证金）

## 访问地址

- 前端：http://localhost:3000
- Anvil RPC：http://127.0.0.1:8545
- 索引器：http://localhost:8080/v1/graphql

## 重要文件

- 合约配置：\`contract/src/core/ExchangeStorage.sol\`
- 前端配置：\`frontend/.env.local\`
- 索引器配置：\`indexer/config.yaml\`
