import React, { useState, useEffect } from 'react';
import { observer } from 'mobx-react-lite';
import { useExchangeStore } from '../store/exchangeStore';
import { Address, formatEther } from 'viem';

export const ReferralCenter: React.FC = observer(() => {
  const { account, registerReferral, referrer, referralStats } = useExchangeStore();
  const [referrerInput, setReferrerInput] = useState('');
  const [registering, setRegistering] = useState(false);
  const [copied, setCopied] = useState(false);

  // 检查URL参数中的推荐人
  useEffect(() => {
    if (account && !referrer) {
      const params = new URLSearchParams(window.location.search);
      const refParam = params.get('ref');
      if (refParam && refParam.startsWith('0x') && refParam.length === 42) {
        setReferrerInput(refParam);
      }
    }
  }, [account, referrer]);

  // 生成邀请链接
  const referralLink = account
    ? `${window.location.origin}${window.location.pathname}?ref=${account}`
    : '';

  const handleCopyLink = async () => {
    if (referralLink) {
      await navigator.clipboard.writeText(referralLink);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleRegister = async () => {
    if (!referrerInput || !referrerInput.startsWith('0x') || referrerInput.length !== 42) {
      alert('请输入有效的推荐人地址');
      return;
    }

    if (referrerInput.toLowerCase() === account?.toLowerCase()) {
      alert('不能绑定自己为推荐人');
      return;
    }

    setRegistering(true);
    try {
      await registerReferral(referrerInput as Address);
      setReferrerInput('');
    } catch (error: any) {
      console.error('Register referral failed:', error);
      alert(error?.message || '绑定失败，可能已经绑定过推荐人');
    } finally {
      setRegistering(false);
    }
  };

  if (!account) {
    return (
      <div className="h-full bg-[#0B0E14] border border-white/10 rounded-lg p-4 flex items-center justify-center">
        <div className="text-center text-gray-500">
          <div className="text-4xl mb-2">👤</div>
          <div className="text-sm">请连接钱包查看返佣信息</div>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full bg-[#0B0E14] border border-white/10 rounded-lg flex flex-col overflow-hidden">
      <div className="p-4 border-b border-white/10">
        <h2 className="text-lg font-bold text-gray-200">邀请返佣中心</h2>
        <p className="text-xs text-gray-400 mt-1">邀请好友交易，获得10%手续费返佣</p>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-6">
        {/* 我的推荐人 */}
        <div className="p-4 rounded-lg bg-white/5 border border-white/10">
          <h3 className="text-sm font-semibold text-gray-300 mb-3">我的推荐人</h3>
          {referrer ? (
            <div className="flex items-center justify-between">
              <div>
                <div className="text-xs text-gray-400">推荐人地址</div>
                <div className="text-sm font-mono text-gray-200 mt-1">
                  {referrer.slice(0, 6)}...{referrer.slice(-4)}
                </div>
              </div>
              <div className="text-green-400 text-xs">✓ 已绑定</div>
            </div>
          ) : (
            <div className="space-y-3">
              <div className="text-xs text-gray-400 mb-2">
                绑定推荐人后，您交易时推荐人将获得10%手续费返佣
              </div>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={referrerInput}
                  onChange={(e) => setReferrerInput(e.target.value)}
                  placeholder="0x..."
                  className="flex-1 px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-sm text-gray-200 placeholder-gray-500 focus:outline-none focus:border-nebula-violet"
                />
                <button
                  onClick={handleRegister}
                  disabled={registering || !referrerInput}
                  className="px-4 py-2 bg-nebula-violet hover:bg-nebula-violet/80 disabled:opacity-50 disabled:cursor-not-allowed text-white text-sm rounded-lg transition-colors"
                >
                  {registering ? '绑定中...' : '绑定'}
                </button>
              </div>
              <div className="text-xs text-gray-500">
                ⚠️ 注意：绑定后无法更改
              </div>
            </div>
          )}
        </div>

        {/* 我的邀请链接 */}
        <div className="p-4 rounded-lg bg-white/5 border border-white/10">
          <h3 className="text-sm font-semibold text-gray-300 mb-3">我的邀请链接</h3>
          <div className="space-y-3">
            <div className="flex gap-2">
              <input
                type="text"
                value={referralLink}
                readOnly
                className="flex-1 px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-xs text-gray-400 font-mono"
              />
              <button
                onClick={handleCopyLink}
                className="px-4 py-2 bg-nebula-violet hover:bg-nebula-violet/80 text-white text-sm rounded-lg transition-colors"
              >
                {copied ? '已复制' : '复制'}
              </button>
            </div>
            <div className="text-xs text-gray-400">
              分享此链接给好友，好友通过链接注册并交易，您将获得10%手续费返佣
            </div>
          </div>
        </div>

        {/* 返佣统计 */}
        {referralStats && (
          <div className="p-4 rounded-lg bg-white/5 border border-white/10">
            <h3 className="text-sm font-semibold text-gray-300 mb-3">返佣统计</h3>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <div className="text-xs text-gray-400 mb-1">已邀请人数</div>
                <div className="text-lg font-bold text-nebula-violet">
                  {referralStats.inviteCount}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-400 mb-1">累计返佣</div>
                <div className="text-lg font-bold text-green-400">
                  {Number(formatEther(referralStats.totalRebateEarned)).toFixed(4)} MON
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 返佣说明 */}
        <div className="p-4 rounded-lg bg-blue-900/20 border border-blue-500/30">
          <h3 className="text-sm font-semibold text-blue-400 mb-2">返佣规则</h3>
          <ul className="text-xs text-gray-400 space-y-1">
            <li>• 被邀请人交易时，您将获得其手续费的10%作为返佣</li>
            <li>• 返佣直接增加到您的保证金余额</li>
            <li>• 返佣实时到账，无需等待</li>
            <li>• 推荐人绑定后无法更改，请谨慎选择</li>
          </ul>
        </div>
      </div>
    </div>
  );
});
