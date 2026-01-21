// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PricingModule.sol";

/// @notice Trading fee calculation and charging module.
/// @dev 手续费计算和扣除模块
abstract contract FeeModule is PricingModule {

    /// @notice 初始化手续费参数
    /// @dev 在构造函数中调用
    function _initializeFeeParams() internal {
        // 设置VIP等级固定费率 (基点)
        tierFeeBps[VIPLevel.VIP0] = 10;  // 10 bps (0.10%)
        tierFeeBps[VIPLevel.VIP1] = 9;   // 9 bps (0.09%)
        tierFeeBps[VIPLevel.VIP2] = 8;    // 8 bps (0.08%)
        tierFeeBps[VIPLevel.VIP3] = 6;   // 6 bps (0.06%)
        tierFeeBps[VIPLevel.VIP4] = 5;   // 5 bps (0.05%)

        // 设置VIP升级阈值 (30天累计交易量，USD计价，1e18精度)
        // 假设 1 USD = 1 MON (实际部署时需要根据价格调整)
        vipVolumeThresholds[0] = 1000 ether;  // VIP0 -> VIP1: 1000 USD
        vipVolumeThresholds[1] = 2000 ether;  // VIP1 -> VIP2: 2000 USD
        vipVolumeThresholds[2] = 5000 ether;  // VIP2 -> VIP3: 5000 USD
        vipVolumeThresholds[3] = 8000 ether;  // VIP3 -> VIP4: 8000 USD

        // 默认项目方收款地址为部署者地址（后续可通过setFeeReceiver修改）
        feeReceiver = msg.sender;
    }

    /// @notice 计算交易手续费
    /// @param trader 交易者地址
    /// @param notional 名义价值 (amount * price / 1e18)
    /// @param isMaker 是否为Maker（提供流动性，当前版本统一费率）
    /// @return feeAmount 手续费金额
    function _calculateTradingFee(
        address trader,
        uint256 notional,
        bool isMaker
    ) internal view returns (uint256 feeAmount) {
        // 1. 获取用户VIP等级
        VIPLevel level = vipLevels[trader];

        // 2. 获取该等级对应的固定费率
        uint256 feeBps = tierFeeBps[level];

        // 3. 计算手续费 = 名义价值 * 费率 / 10000
        feeAmount = (notional * feeBps) / 10000;

        return feeAmount;
    }

    /// @notice 扣除交易手续费（包含返佣逻辑）
    /// @param trader 交易者地址
    /// @param notional 名义价值
    /// @param isMaker 是否为Maker
    /// @return feeAmount 实际扣除的手续费金额
    function _chargeTradingFee(
        address trader,
        uint256 notional,
        bool isMaker
    ) internal returns (uint256 feeAmount) {
        // 1. 计算手续费
        feeAmount = _calculateTradingFee(trader, notional, isMaker);

        // 如果手续费为0，直接返回
        if (feeAmount == 0) {
            return 0;
        }

        // 2. 从用户保证金中扣除手续费
        Account storage account = accounts[trader];
        if (account.margin >= feeAmount) {
            account.margin -= feeAmount;
        } else {
            // 如果保证金不足，扣除全部可用保证金
            feeAmount = account.margin;
            account.margin = 0;
        }

        // 3. 累计手续费收入
        totalFeeCollected += feeAmount;

        // 4. 处理返佣和手续费分配
        address referrer = referrers[trader];
        uint256 rebateAmount = 0;
        uint256 projectAmount = feeAmount;

        if (referrer != address(0) && referralRebateBps > 0) {
            // 计算返佣金额
            rebateAmount = (feeAmount * referralRebateBps) / 10000;
            projectAmount = feeAmount - rebateAmount;

            // 将返佣增加到推荐人的保证金
            if (rebateAmount > 0) {
                accounts[referrer].margin += rebateAmount;
                totalRebatePaid += rebateAmount;
                emit RebatePaid(trader, referrer, feeAmount, rebateAmount);
            }
        }

        // 5. 将项目方收入发送到收款地址
        if (projectAmount > 0 && feeReceiver != address(0)) {
            (bool success, ) = feeReceiver.call{value: projectAmount}("");
            require(success, "fee transfer failed");
        }

        // 6. 触发事件
        emit TradingFeeCharged(trader, notional, feeAmount, isMaker, vipLevels[trader]);

        return feeAmount;
    }

    /// @notice 设置VIP等级费率 (仅管理员)
    /// @param tier VIP等级
    /// @param feeBps 费率 (基点)
    function setTierFeeBps(VIPLevel tier, uint256 feeBps) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(feeBps <= 1000, "fee too high"); // 最大10%
        tierFeeBps[tier] = feeBps;
        emit FeeParamsUpdated(0, 0, feeReceiver); // 保留事件，但不再使用maker/taker费率
    }

    /// @notice 设置VIP升级阈值 (仅管理员)
    /// @param thresholds VIP升级阈值数组 [Bronze->Silver, Silver->Gold, Gold->Platinum, Platinum->Diamond]
    function setVIPThresholds(uint256[4] calldata thresholds) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        vipVolumeThresholds = thresholds;
        emit VIPThresholdsUpdated(thresholds);
    }

    /// @notice 获取用户的VIP费率
    /// @param trader 交易者地址
    /// @return feeBps 费率 (基点)
    function getActualFeeRate(address trader, bool) external view returns (uint256 feeBps) {
        VIPLevel level = vipLevels[trader];
        return tierFeeBps[level];
    }

    /// @notice 获取返佣比例
    /// @return rebateBps 返佣比例 (基点)
    function getReferralRebateBps() external view returns (uint256) {
        return referralRebateBps;
    }
}
