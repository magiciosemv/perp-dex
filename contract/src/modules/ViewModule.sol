// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/ExchangeStorage.sol";

/// @notice Read-only helpers for offchain consumers.
/// @dev Day 1: 这些是视图函数，用于读取合约状态
abstract contract ViewModule is ExchangeStorage {
    
    /// @notice 获取订单详情
    /// @param id 订单 ID
    /// @return 订单结构体
    function getOrder(uint256 id) external view virtual returns (Order memory) {
        // 直接从存储中返回订单
        return orders[id];
    }

    /// @notice 获取用户账户保证金
    /// @param trader 用户地址
    /// @return 账户保证金数量
    function margin(address trader) external view virtual returns (uint256) {
        // 返回账户的保证金余额
        return accounts[trader].margin;
    }

    /// @notice 获取用户持仓
    /// @param trader 用户地址
    /// @return 持仓结构体
    function getPosition(address trader) external view virtual returns (Position memory) {
        // 返回账户当前持仓
        return accounts[trader].position;
    }

    /// @notice 获取用户账户信息（包括保证金、持仓、VIP等级）
    /// @param trader 用户地址
    /// @return margin_ 保证金余额
    /// @return position_ 持仓信息
    /// @return vipLevel_ VIP等级
    /// @return cumulativeVolume_ 30天累计交易量
    function getAccountInfo(address trader)
        external
        view
        virtual
        returns (
            uint256 margin_,
            Position memory position_,
            VIPLevel vipLevel_,
            uint256 cumulativeVolume_
        )
    {
        margin_ = accounts[trader].margin;
        position_ = accounts[trader].position;
        vipLevel_ = vipLevels[trader];
        cumulativeVolume_ = cumulativeTradingVolume[trader];
    }
}
