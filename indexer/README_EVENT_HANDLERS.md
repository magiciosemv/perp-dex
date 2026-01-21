# 索引器事件处理器启用说明

## 问题

索引器启动时出现错误，因为新添加的事件（ReferralRegistered、RebatePaid、VIPLevelUpgraded、TradingFeeCharged）的类型还没有生成。

## 解决方案

### 步骤 1: 确保合约已部署

```bash
# 重新部署合约（包含新事件）
cd /home/magic/MonCode/perpm-course
./scripts/run-anvil-deploy.sh
```

### 步骤 2: 重新生成索引器代码

```bash
cd indexer

# 清理旧的生成文件
rm -rf generated/

# 重新生成代码（这会从合约ABI读取事件定义）
pnpm codegen
```

### 步骤 3: 启用事件处理器

编辑 `indexer/src/EventHandlers.ts`，取消注释以下事件处理器：

1. `Exchange.ReferralRegistered.handler` (约237行)
2. `Exchange.RebatePaid.handler` (约262行)
3. `Exchange.VIPLevelUpgraded.handler` (约299行)
4. `Exchange.TradingFeeCharged.handler` (约314行)

### 步骤 4: 重启索引器

```bash
# 停止当前索引器（Ctrl+C）

# 重新启动
pnpm dev
```

## 临时方案

如果codegen仍然失败，可以：

1. **暂时注释掉新的事件处理器**（已自动完成）
2. **索引器可以正常启动**，但不会索引VIP和返佣相关事件
3. **合约功能仍然正常**，只是索引器暂时不记录这些事件

## 验证

索引器成功启动后，应该能看到：

```
[INFO] The indexer storage is ready. Starting indexing!
```

然后可以访问 GraphQL Playground: http://localhost:8080/v1/graphql

## 注意事项

- 索引器需要从合约ABI中读取事件定义
- 如果合约地址或ABI发生变化，需要重新运行 `pnpm codegen`
- 新事件必须在 `indexer/config.yaml` 中定义
