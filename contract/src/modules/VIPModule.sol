// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FeeModule.sol";

/// @notice VIP level management and upgrade logic.
/// @dev VIP等级管理和升级模块
abstract contract VIPModule is FeeModule {

    /// @notice 30天时间窗口 (秒)
    uint256 public constant VOLUME_WINDOW = 30 days;

    /// @notice 更新用户交易量并检查VIP升级
    /// @param trader 交易者地址
    /// @param volume 本次交易量 (名义价值)
    function _updateTradingVolume(address trader, uint256 volume) internal {
        // 直接累加交易量
        cumulativeTradingVolume[trader] += volume;
        
        // 检查并升级VIP等级
        _checkAndUpgradeVIP(trader);
    }

    /// @notice 清理30天前的交易量记录
    /// @param trader 交易者地址
    function _cleanOldVolumeRecords(address trader) internal {
        // 简化版本：当前版本不追踪30天滚动窗口，直接使用累计交易量
        // 在生产版本中应该实现30天滚动窗口
    }

    /// @notice 重新计算累计交易量（30天滚动窗口）
    /// @param trader 交易者地址
    function _recalculateCumulativeVolume(address trader) internal {
        // 简化版本：不需要重新计算，使用直接累计的值
    }

    /// @notice 检查并升级VIP等级
    /// @param trader 交易者地址
    function _checkAndUpgradeVIP(address trader) internal {
        VIPLevel currentLevel = vipLevels[trader];
        uint256 volume = cumulativeTradingVolume[trader];

        VIPLevel newLevel = VIPLevel.VIP0;

        // 根据累计交易量确定VIP等级（从高到低检查）
        if (volume >= vipVolumeThresholds[3]) {
            // ≥ 8000 USD -> VIP4
            newLevel = VIPLevel.VIP4;
        } else if (volume >= vipVolumeThresholds[2]) {
            // ≥ 5000 USD -> VIP3
            newLevel = VIPLevel.VIP3;
        } else if (volume >= vipVolumeThresholds[1]) {
            // ≥ 2000 USD -> VIP2
            newLevel = VIPLevel.VIP2;
        } else if (volume >= vipVolumeThresholds[0]) {
            // ≥ 1000 USD -> VIP1
            newLevel = VIPLevel.VIP1;
        } else {
            // < 1000 USD -> VIP0
            newLevel = VIPLevel.VIP0;
        }

        // 如果等级提升，更新并触发事件
        if (uint256(newLevel) > uint256(currentLevel)) {
            vipLevels[trader] = newLevel;
            emit VIPLevelUpgraded(trader, currentLevel, newLevel);
        }
    }

    /// @notice 手动检查并升级VIP等级（外部调用）
    /// @dev 用户可以主动调用此函数来更新VIP等级
    function checkVIPUpgrade() external {
        _cleanOldVolumeRecords(msg.sender);
        _recalculateCumulativeVolume(msg.sender);
        _checkAndUpgradeVIP(msg.sender);
    }

    /// @notice 获取用户VIP等级
    /// @param trader 交易者地址
    /// @return level VIP等级
    function getVIPLevel(address trader) external view returns (VIPLevel level) {
        return vipLevels[trader];
    }

    /// @notice 获取用户累计交易量（30天）
    /// @param trader 交易者地址
    /// @return volume 累计交易量
    function getCumulativeVolume(address trader) external view returns (uint256 volume) {
        // 直接返回缓存的累计交易量，避免重复计算
        return cumulativeTradingVolume[trader];
    }

    /// @notice 获取用户距离下一级VIP所需的交易量
    /// @param trader 交易者地址
    /// @return requiredVolume 所需交易量，如果已经是最高级则返回0
    function getVolumeToNextVIP(address trader) external view returns (uint256 requiredVolume) {
        VIPLevel currentLevel = vipLevels[trader];
        
        // 如果已经是VIP4，返回0
        if (currentLevel == VIPLevel.VIP4) {
            return 0;
        }

        uint256 currentVolume = cumulativeTradingVolume[trader];
        uint256 nextThreshold = vipVolumeThresholds[uint256(currentLevel)];

        if (currentVolume >= nextThreshold) {
            return 0; // 应该已经升级了
        }

        return nextThreshold - currentVolume;
    }

    /// @notice 管理员手动设置用户VIP等级（用于特殊活动等）
    /// @param trader 交易者地址
    /// @param level VIP等级
    function setVIPLevel(address trader, VIPLevel level) external onlyRole(DEFAULT_ADMIN_ROLE) {
        VIPLevel oldLevel = vipLevels[trader];
        vipLevels[trader] = level;
        emit VIPLevelUpgraded(trader, oldLevel, level);
    }
}
