import { Address, parseEther } from 'viem';
import { publicClient, walletClient } from '../client';
import { EXCHANGE_ABI } from '../abi';
import { EXCHANGE_ADDRESS } from '../config';

/**
 * VIP Keeper Service
 * 负责自动更新用户的VIP等级
 * 
 * 执行流程：
 * 1. 从索引器查询所有活跃用户的30天交易量
 * 2. 根据交易量计算理论VIP等级
 * 3. 与链上等级对比，如有差异则更新
 */
export class VIPKeeper {
  private exchangeAddress: Address;
  private intervalMs: number;
  private intervalId?: NodeJS.Timeout;

  constructor(exchangeAddress: Address, intervalMs: number = 3600000) { // 默认1小时
    this.exchangeAddress = exchangeAddress;
    this.intervalMs = intervalMs;
  }

  /**
   * 启动VIP Keeper
   */
  start() {
    console.log('[VIPKeeper] Starting VIP Keeper service...');
    this.run();
    this.intervalId = setInterval(() => this.run(), this.intervalMs);
  }

  /**
   * 停止VIP Keeper
   */
  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = undefined;
    }
    console.log('[VIPKeeper] Stopped');
  }

  /**
   * 执行VIP等级更新
   */
  private async run() {
    try {
      console.log('[VIPKeeper] Running VIP level update check...');
      
      // 1. 从索引器获取用户交易量数据
      // 注意：这里需要索引器提供GraphQL查询接口
      // 实际实现时需要根据索引器的具体API调整
      const users = await this.fetchUserVolumes();
      
      // 2. 批量更新VIP等级
      for (const user of users) {
        await this.updateUserVIPLevel(user.address, user.volume30Days);
      }
      
      console.log(`[VIPKeeper] Updated ${users.length} users`);
    } catch (error) {
      console.error('[VIPKeeper] Error:', error);
    }
  }

  /**
   * 从索引器获取用户交易量
   * TODO: 实现实际的GraphQL查询
   */
  private async fetchUserVolumes(): Promise<Array<{ address: Address; volume30Days: bigint }>> {
    // 这里应该查询索引器的UserVolume实体
    // 示例查询：
    // query {
    //   UserVolume(where: {volume30Days: {_gt: "0"}}) {
    //     trader
    //     volume30Days
    //   }
    // }
    
    // 临时返回空数组，实际实现时需要连接索引器
    return [];
  }

  /**
   * 更新单个用户的VIP等级
   */
  private async updateUserVIPLevel(userAddress: Address, volume30Days: bigint) {
    try {
      // 1. 读取链上当前VIP等级
      // 注意：使用 as any 绕过类型检查，因为 ABI 可能还未包含新函数
      const currentLevel = (await publicClient.readContract({
        address: this.exchangeAddress,
        abi: EXCHANGE_ABI,
        functionName: 'getVIPLevel',
        args: [userAddress],
      } as any)) as number;

      // 2. 计算理论VIP等级
      const theoreticalLevel = this.calculateVIPLevel(volume30Days);

      // 3. 如果等级不同，则更新
      if (theoreticalLevel !== currentLevel) {
        console.log(`[VIPKeeper] Updating ${userAddress}: ${currentLevel} -> ${theoreticalLevel}`);
        
        if (!walletClient) {
          console.error('[VIPKeeper] No wallet client configured');
          return;
        }

        // 调用合约更新VIP等级
        // 注意：setVIPLevel 需要 DEFAULT_ADMIN_ROLE 权限
        const hash = await (walletClient as any).writeContract({
          address: this.exchangeAddress,
          abi: EXCHANGE_ABI,
          functionName: 'setVIPLevel',
          args: [userAddress, theoreticalLevel],
        } as any);

        await publicClient.waitForTransactionReceipt({ hash });
        console.log(`[VIPKeeper] Updated ${userAddress} to VIP${theoreticalLevel}`);
      }
    } catch (error) {
      console.error(`[VIPKeeper] Failed to update ${userAddress}:`, error);
    }
  }

  /**
   * 根据30天交易量计算VIP等级
   */
  private calculateVIPLevel(volume30Days: bigint): number {
    // VIP升级阈值（USD计价，1e18精度）
    const thresholds = [
      parseEther('1000'),  // VIP0 -> VIP1
      parseEther('2000'),  // VIP1 -> VIP2
      parseEther('5000'),  // VIP2 -> VIP3
      parseEther('8000'),  // VIP3 -> VIP4
    ];

    if (volume30Days >= thresholds[3]) return 4; // VIP4
    if (volume30Days >= thresholds[2]) return 3; // VIP3
    if (volume30Days >= thresholds[1]) return 2; // VIP2
    if (volume30Days >= thresholds[0]) return 1; // VIP1
    return 0; // VIP0
  }
}
