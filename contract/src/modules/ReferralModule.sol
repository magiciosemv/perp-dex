// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VIPModule.sol";

/// @notice Referral system for user invitations and rebates.
/// @dev 推荐人系统和返佣模块
abstract contract ReferralModule is VIPModule {

    /// @notice 注册推荐人
    /// @param referrer 推荐人地址
    /// @dev 每个用户只能绑定一次，且不能绑定自己
    function registerReferral(address referrer) external virtual {
        require(referrer != address(0), "invalid referrer");
        require(referrer != msg.sender, "cannot refer self");
        require(referrers[msg.sender] == address(0), "already registered");

        referrers[msg.sender] = referrer;
        emit ReferralRegistered(msg.sender, referrer);
    }

    /// @notice 获取用户的推荐人
    /// @param user 用户地址
    /// @return 推荐人地址，如果未绑定则返回 address(0)
    function getReferrer(address user) external view virtual returns (address) {
        return referrers[user];
    }

    /// @notice 设置返佣比例 (仅管理员)
    /// @param rebateBps 返佣比例 (基点, 1000 = 10%)
    function setReferralRebateBps(uint256 rebateBps) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(rebateBps <= 5000, "rebate too high"); // 最大50%
        referralRebateBps = rebateBps;
        emit FeeParamsUpdated(0, 0, feeReceiver);
    }

    /// @notice 设置项目方收款地址 (仅管理员)
    /// @param receiver 收款地址
    function setFeeReceiver(address receiver) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(receiver != address(0), "invalid receiver");
        feeReceiver = receiver;
        emit FeeParamsUpdated(0, 0, feeReceiver);
    }
}
