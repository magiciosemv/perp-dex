import React, { useState } from 'react';
import { observer } from 'mobx-react-lite';
import { useExchangeStore } from '../store/exchangeStore';
import { VIPLevel } from '../types';
import { VIPInfo } from './VIPInfo';
import { VIPProgress } from './VIPProgress';
import { VIPPrivileges } from './VIPPrivileges';
import { ReferralCenter } from './ReferralCenter';

export const VIPPanel: React.FC = observer(() => {
  const store = useExchangeStore();
  const { account, vipInfo } = store;
  const [activeTab, setActiveTab] = useState<'info' | 'privileges' | 'referral'>('info');

  if (!account) {
    return (
      <div className="h-full bg-[#0B0E14] border border-white/10 rounded-lg p-4 flex items-center justify-center">
        <div className="text-center text-gray-500">
          <div className="text-4xl mb-2">👤</div>
          <div className="text-sm">请连接钱包查看VIP信息</div>
        </div>
      </div>
    );
  }

  if (!vipInfo) {
    return (
      <div className="h-full bg-[#0B0E14] border border-white/10 rounded-lg p-4 flex items-center justify-center">
        <div className="text-center text-gray-500">
          <div className="animate-spin text-2xl mb-2">⏳</div>
          <div className="text-sm mb-2">加载VIP信息中...</div>
          <div className="text-xs text-gray-600 mt-2">
            如果长时间未加载，请检查：
            <br />
            1. 合约是否已部署VIP功能
            <br />
            2. 浏览器控制台是否有错误
            <br />
            3. RPC连接是否正常
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full bg-[#0B0E14] border border-white/10 rounded-lg flex flex-col overflow-hidden min-h-0">
      {/* Tab Header */}
      <div className="flex border-b border-white/10">
        <button
          onClick={() => setActiveTab('info')}
          className={`flex-1 px-3 py-2 text-xs font-medium transition-colors ${
            activeTab === 'info'
              ? 'text-nebula-violet border-b-2 border-nebula-violet bg-white/5'
              : 'text-gray-400 hover:text-gray-300 hover:bg-white/5'
          }`}
        >
          VIP信息
        </button>
        <button
          onClick={() => setActiveTab('privileges')}
          className={`flex-1 px-3 py-2 text-xs font-medium transition-colors ${
            activeTab === 'privileges'
              ? 'text-nebula-violet border-b-2 border-nebula-violet bg-white/5'
              : 'text-gray-400 hover:text-gray-300 hover:bg-white/5'
          }`}
        >
          特权
        </button>
        <button
          onClick={() => setActiveTab('referral')}
          className={`flex-1 px-3 py-2 text-xs font-medium transition-colors ${
            activeTab === 'referral'
              ? 'text-nebula-violet border-b-2 border-nebula-violet bg-white/5'
              : 'text-gray-400 hover:text-gray-300 hover:bg-white/5'
          }`}
        >
          返佣
        </button>
      </div>

      {/* Tab Content */}
      <div className="flex-1 overflow-hidden">
        {activeTab === 'info' ? (
          <div className="h-full overflow-y-auto p-4 space-y-4">
            <VIPInfo />
            <VIPProgress />
            
            {/* 手续费信息 */}
            <div className="mt-4 p-4 rounded-lg bg-white/5 border border-white/10">
              <h3 className="text-sm font-semibold text-gray-300 mb-3">当前手续费率</h3>
              <div className="space-y-2 text-xs">
                <div className="text-xs text-gray-500 mb-2">
                  固定费率模式，根据VIP等级自动调整
                </div>
                <div className="h-px bg-white/10 my-2" />
                <div className="flex justify-between items-center">
                  <span className="text-gray-300">交易费率</span>
                  <span className="text-nebula-violet font-mono font-semibold">
                    {vipInfo.makerFeeRate.toFixed(3)}% ({vipInfo.makerFeeRate * 100} bps)
                  </span>
                </div>
                {vipInfo.level > VIPLevel.VIP0 && (
                  <div className="mt-2 pt-2 border-t border-white/10">
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-gray-400">相比VIP 0节省</span>
                      <span className="text-xs text-green-400 font-semibold">
                        {((0.10 - vipInfo.makerFeeRate) / 0.10 * 100).toFixed(0)}%
                      </span>
                    </div>
                  </div>
                )}
                <div className="mt-2 pt-2 border-t border-white/10">
                  <div className="text-xs text-gray-400">
                    VIP等级越高，费率越低
                  </div>
                </div>
              </div>
            </div>
          </div>
        ) : activeTab === 'privileges' ? (
          <div className="h-full overflow-y-auto p-4">
            <VIPPrivileges />
          </div>
        ) : (
          <div className="h-full overflow-hidden">
            <ReferralCenter />
          </div>
        )}
      </div>
    </div>
  );
});
