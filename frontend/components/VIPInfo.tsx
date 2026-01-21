import React from 'react';
import { observer } from 'mobx-react-lite';
import { useExchangeStore } from '../store/exchangeStore';
import { VIPLevel } from '../types';
import { formatEther } from 'viem';

const VIP_COLORS: Record<VIPLevel, { bg: string; text: string; border: string; gradient: string }> = {
  [VIPLevel.VIP0]: {
    bg: 'bg-gray-800/20',
    text: 'text-gray-300',
    border: 'border-gray-400/50',
    gradient: 'from-gray-400 to-gray-600',
  },
  [VIPLevel.VIP1]: {
    bg: 'bg-blue-900/20',
    text: 'text-blue-400',
    border: 'border-blue-500/50',
    gradient: 'from-blue-500 to-blue-700',
  },
  [VIPLevel.VIP2]: {
    bg: 'bg-green-900/20',
    text: 'text-green-400',
    border: 'border-green-500/50',
    gradient: 'from-green-500 to-green-700',
  },
  [VIPLevel.VIP3]: {
    bg: 'bg-purple-900/20',
    text: 'text-purple-400',
    border: 'border-purple-500/50',
    gradient: 'from-purple-500 to-purple-700',
  },
  [VIPLevel.VIP4]: {
    bg: 'bg-yellow-900/20',
    text: 'text-yellow-400',
    border: 'border-yellow-500/50',
    gradient: 'from-yellow-500 via-orange-500 to-yellow-700',
  },
};

const VIP_ICONS: Record<VIPLevel, string> = {
  [VIPLevel.VIP0]: '⭐',
  [VIPLevel.VIP1]: '🌟',
  [VIPLevel.VIP2]: '💫',
  [VIPLevel.VIP3]: '✨',
  [VIPLevel.VIP4]: '👑',
};

const VIP_NAMES: Record<VIPLevel, string> = {
  [VIPLevel.VIP0]: 'VIP 0',
  [VIPLevel.VIP1]: 'VIP 1',
  [VIPLevel.VIP2]: 'VIP 2',
  [VIPLevel.VIP3]: 'VIP 3',
  [VIPLevel.VIP4]: 'VIP 4',
};

const VIP_FEE_RATES: Record<VIPLevel, number> = {
  [VIPLevel.VIP0]: 0.10,  // 10 bps
  [VIPLevel.VIP1]: 0.09,  // 9 bps
  [VIPLevel.VIP2]: 0.08,  // 8 bps
  [VIPLevel.VIP3]: 0.06,  // 6 bps
  [VIPLevel.VIP4]: 0.05,  // 5 bps
};

export const VIPInfo: React.FC = observer(() => {
  const { vipInfo, account } = useExchangeStore();

  if (!account || !vipInfo) {
    return null;
  }

  const colors = VIP_COLORS[vipInfo.level];
  const icon = VIP_ICONS[vipInfo.level];
  const levelName = VIP_NAMES[vipInfo.level];
  const feeRate = VIP_FEE_RATES[vipInfo.level];
  const volume = Number(formatEther(vipInfo.cumulativeVolume));
  const volumeToNext = Number(formatEther(vipInfo.volumeToNext));

  return (
    <div className={`p-4 rounded-lg border ${colors.bg} ${colors.border}`}>
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className={`text-3xl bg-gradient-to-br ${colors.gradient} bg-clip-text text-transparent`}>
            {icon}
          </div>
          <div>
            <div className={`text-lg font-bold ${colors.text}`}>
              {levelName}
            </div>
            <div className="text-xs text-gray-400">
              费率: {feeRate.toFixed(2)}% ({feeRate * 100} bps)
            </div>
            {vipInfo.level > VIPLevel.VIP0 && (
              <div className="text-xs text-green-400 mt-0.5">
                相比VIP 0节省 {((0.10 - feeRate) / 0.10 * 100).toFixed(0)}%
              </div>
            )}
          </div>
        </div>
        {vipInfo.level < VIPLevel.VIP4 && (
          <div className="text-xs text-gray-400 text-right">
            <div>距离下一级</div>
            <div className={`font-mono ${colors.text}`}>
              {volumeToNext > 0 ? `$${volumeToNext.toFixed(2)}` : '已达标'}
            </div>
          </div>
        )}
      </div>

      <div className="grid grid-cols-2 gap-4 mt-4">
        <div>
          <div className="text-xs text-gray-400 mb-1">30天累计交易量</div>
          <div className={`font-mono font-semibold ${colors.text}`}>
            ${volume.toFixed(2)}
          </div>
        </div>
        <div>
          <div className="text-xs text-gray-400 mb-1">当前手续费率</div>
          <div className={`font-mono text-sm ${colors.text}`}>
            {feeRate.toFixed(2)}% ({feeRate * 100} bps)
          </div>
        </div>
      </div>
    </div>
  );
});
