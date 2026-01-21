import React from 'react';
import { observer } from 'mobx-react-lite';
import { useExchangeStore } from '../store/exchangeStore';
import { VIPLevel, VIPPrivilege } from '../types';

const ALL_PRIVILEGES: Array<{ level: VIPLevel; privileges: VIPPrivilege[] }> = [
  {
    level: VIPLevel.VIP0,
    privileges: [
      {
        name: '基础交易',
        description: '享受标准交易功能，费率 0.10%',
        icon: '📊',
        available: true,
      },
    ],
  },
  {
    level: VIPLevel.VIP1,
    privileges: [
      {
        name: '费率优惠',
        description: '交易费率降至 0.09%',
        icon: '💰',
        available: true,
      },
      {
        name: '优先客服支持',
        description: '获得优先客服响应',
        icon: '💬',
        available: true,
      },
    ],
  },
  {
    level: VIPLevel.VIP2,
    privileges: [
      {
        name: '更低费率',
        description: '交易费率降至 0.08%',
        icon: '💎',
        available: true,
      },
      {
        name: '专属交易工具',
        description: '访问高级交易工具和指标',
        icon: '🔧',
        available: true,
      },
    ],
  },
  {
    level: VIPLevel.VIP3,
    privileges: [
      {
        name: '超低费率',
        description: '交易费率降至 0.06%',
        icon: '💠',
        available: true,
      },
      {
        name: 'API优先访问',
        description: 'API调用优先级提升',
        icon: '⚡',
        available: true,
      },
      {
        name: '专属活动邀请',
        description: '受邀参加专属交易活动',
        icon: '🎁',
        available: true,
      },
    ],
  },
  {
    level: VIPLevel.VIP4,
    privileges: [
      {
        name: '最低费率',
        description: '交易费率降至 0.05%',
        icon: '👑',
        available: true,
      },
      {
        name: '专属客户经理',
        description: '一对一专属客户服务',
        icon: '🤝',
        available: true,
      },
      {
        name: '定制化服务',
        description: '根据需求定制交易方案',
        icon: '⭐',
        available: true,
      },
      {
        name: '最高优先级',
        description: '所有服务最高优先级',
        icon: '🚀',
        available: true,
      },
    ],
  },
];

export const VIPPrivileges: React.FC = observer(() => {
  const { vipInfo } = useExchangeStore();

  if (!vipInfo) {
    return null;
  }

  // 获取当前等级及以下所有特权
  const availablePrivileges = ALL_PRIVILEGES
    .filter((p) => p.level <= vipInfo.level)
    .flatMap((p) => p.privileges);

  // 获取下一级特权（如果存在）
  const nextLevelPrivileges = ALL_PRIVILEGES.find((p) => p.level === vipInfo.level + 1);

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-sm font-semibold text-gray-300 mb-3">当前特权</h3>
        <div className="space-y-2">
          {availablePrivileges.map((privilege, idx) => (
            <div
              key={idx}
              className="flex items-start gap-3 p-3 rounded-lg bg-white/5 border border-white/10"
            >
              <div className="text-2xl">{privilege.icon}</div>
              <div className="flex-1">
                <div className="text-sm font-medium text-gray-200">{privilege.name}</div>
                <div className="text-xs text-gray-400 mt-0.5">{privilege.description}</div>
              </div>
              <div className="text-green-400 text-xs">✓</div>
            </div>
          ))}
        </div>
      </div>

      {nextLevelPrivileges && vipInfo.level < VIPLevel.VIP4 && (
        <div>
          <h3 className="text-sm font-semibold text-gray-400 mb-3">下一级特权</h3>
          <div className="space-y-2">
            {nextLevelPrivileges.privileges.map((privilege, idx) => (
              <div
                key={idx}
                className="flex items-start gap-3 p-3 rounded-lg bg-white/5 border border-white/5 opacity-60"
              >
                <div className="text-2xl">{privilege.icon}</div>
                <div className="flex-1">
                  <div className="text-sm font-medium text-gray-400">{privilege.name}</div>
                  <div className="text-xs text-gray-500 mt-0.5">{privilege.description}</div>
                </div>
                <div className="text-gray-500 text-xs">🔒</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
});
