import React from 'react';
import { observer } from 'mobx-react-lite';
import { useExchangeStore } from '../store/exchangeStore';
import { VIPLevel } from '../types';
import { formatEther } from 'viem';

const VIP_THRESHOLDS = [
  { level: VIPLevel.VIP1, threshold: 1000 },   // VIP0 -> VIP1: 1000 USD
  { level: VIPLevel.VIP2, threshold: 2000 },   // VIP1 -> VIP2: 2000 USD
  { level: VIPLevel.VIP3, threshold: 5000 },   // VIP2 -> VIP3: 5000 USD
  { level: VIPLevel.VIP4, threshold: 8000 },   // VIP3 -> VIP4: 8000 USD
];

export const VIPProgress: React.FC = observer(() => {
  const { vipInfo, checkVIPUpgrade } = useExchangeStore();
  const [upgrading, setUpgrading] = React.useState(false);

  if (!vipInfo) {
    return null;
  }

  // 如果已经是最高级，不显示进度
  if (vipInfo.level >= VIPLevel.VIP4) {
    return (
      <div className="p-4 rounded-lg bg-gradient-to-br from-yellow-900/20 to-orange-900/20 border border-yellow-500/50">
        <div className="text-center">
          <div className="text-4xl mb-2">👑</div>
          <div className="text-lg font-bold text-yellow-400 mb-1">VIP 4</div>
          <div className="text-xs text-gray-400">您已达到最高VIP等级</div>
        </div>
      </div>
    );
  }

  // 找到下一个等级
  const nextLevel = vipInfo.level + 1;
  const nextThreshold = VIP_THRESHOLDS.find((t) => t.level === nextLevel);
  
  if (!nextThreshold) {
    return null;
  }

  const currentVolume = Number(formatEther(vipInfo.cumulativeVolume));
  const threshold = nextThreshold.threshold;
  const progress = Math.min(100, (currentVolume / threshold) * 100);
  const remaining = Math.max(0, threshold - currentVolume);

  const handleUpgrade = async () => {
    setUpgrading(true);
    try {
      await checkVIPUpgrade();
    } catch (e) {
      console.error('Upgrade check failed:', e);
    } finally {
      setUpgrading(false);
    }
  };

  return (
    <div className="p-4 rounded-lg bg-white/5 border border-white/10">
      <div className="flex items-center justify-between mb-3">
        <div>
          <div className="text-sm font-semibold text-gray-300">升级进度</div>
          <div className="text-xs text-gray-400 mt-0.5">
            前往 VIP {nextLevel}
          </div>
        </div>
        <button
          onClick={handleUpgrade}
          disabled={upgrading}
          className="px-3 py-1.5 text-xs bg-nebula-violet/20 hover:bg-nebula-violet/30 text-nebula-violet rounded-lg border border-nebula-violet/50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {upgrading ? '检查中...' : '检查升级'}
        </button>
      </div>

      <div className="mb-2">
        <div className="flex justify-between text-xs mb-1">
          <span className="text-gray-400">
            ${currentVolume.toFixed(2)} / ${threshold.toFixed(0)}
          </span>
          <span className="text-gray-400">
            {progress.toFixed(1)}%
          </span>
        </div>
        <div className="w-full bg-gray-800 rounded-full h-2 overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-nebula-violet to-nebula-pink transition-all duration-300"
            style={{ width: `${progress}%` }}
          />
        </div>
      </div>

      <div className="text-xs text-gray-400 text-center">
        还需交易 <span className="text-nebula-violet font-mono">${remaining.toFixed(2)}</span> 即可升级
      </div>
    </div>
  );
});
