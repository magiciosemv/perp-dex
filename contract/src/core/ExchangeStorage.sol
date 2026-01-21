// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ExchangeStorage
/// @notice 永续合约交易所的共享状态、结构体、事件和角色定义
/// @dev 所有模块继承此合约以共享存储布局
abstract contract ExchangeStorage is AccessControl, ReentrancyGuard {
    
    // ============================================
    // 角色定义
    // ============================================
    
    /// @notice 操作员角色，可以更新价格
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ============================================
    // 常量配置
    // ============================================
    
    /// @notice 抵押品符号 (Monad 原生代币)
    string public constant COLLATERAL_SYMBOL = "MON";
    
    /// @notice 抵押品精度
    uint8 public constant COLLATERAL_DECIMALS = 18;

    // ============================================
    // 数据结构
    // ============================================

    /// @notice 订单结构体
    /// @dev 使用链表存储，next 指向下一个订单 ID
    struct Order {
        uint256 id;           // 订单 ID
        address trader;       // 交易者地址
        bool isBuy;           // 是否为买单
        uint256 price;        // 价格 (1e18 精度)
        uint256 amount;       // 剩余数量 (1e18 精度)
        uint256 initialAmount;// 初始数量
        uint256 timestamp;    // 创建时间戳
        uint256 next;         // 链表中下一个订单 ID
    }

    /// @notice 持仓结构体
    struct Position {
        int256 size;          // 持仓数量 (正=多头, 负=空头)
        uint256 entryPrice;   // 入场价格 (加权平均)
    }

    /// @notice 账户结构体
    struct Account {
        uint256 margin;       // 账户保证金 (MON)
        Position position;    // 用户持仓
    }

    // ============================================
    // 订单簿状态
    // ============================================

    /// @notice 订单存储 (订单ID => 订单)
    mapping(uint256 => Order) public orders;
    
    /// @notice 最优买单 ID (链表头)
    uint256 public bestBuyId;
    
    /// @notice 最优卖单 ID (链表头)
    uint256 public bestSellId;
    
    /// @notice 订单 ID 计数器
    uint256 internal orderIdCounter;

    // ============================================
    // 账户状态
    // ============================================

    /// @notice 用户账户 (地址 => 账户)
    mapping(address => Account) internal accounts;
    
    /// @notice 用户挂单数量 (用于限制最大挂单数)
    mapping(address => uint256) public pendingOrderCount;

    // ============================================
    // 资金费率状态
    // ============================================

    /// @notice 累计资金费率 (1e18 精度)
    int256 public cumulativeFundingRate;
    
    /// @notice 用户上次结算时的资金费率指数
    mapping(address => int256) public lastFundingIndex;
    
    /// @notice 上次资金费率结算时间
    uint256 public lastFundingTime;
    
    /// @notice 标记价格 (1e18 精度)
    uint256 public markPrice;
    
    /// @notice 指数价格 (1e18 精度)
    uint256 public indexPrice;
    
    /// @notice 资金费率结算间隔 (默认 1 小时)
    uint256 public fundingInterval = 1 hours;
    
    /// @notice 每个周期最大资金费率 (0 表示无上限, 1e18 精度)
    int256 public maxFundingRatePerInterval;

    // ============================================
    // 风控参数
    // ============================================

    /// @notice 初始保证金率 (基点, 100 = 1%, 支持最高 100 倍杠杆)
    uint256 public initialMarginBps = 100;
    
    /// @notice 维持保证金率 (基点, 50 = 0.5%)
    uint256 public maintenanceMarginBps = 50;
    
    /// @notice 清算费率 (基点, 125 = 1.25%)
    uint256 public liquidationFeeBps = 125;
    
    /// @notice 最小清算奖励 (激励清算者)
    uint256 public minLiquidationFee = 0.01 ether;
    
    /// @notice 每用户最大挂单数 (简化最坏情况保证金计算)
    uint256 public constant MAX_PENDING_ORDERS = 10;

    // ============================================
    // VIP 和手续费状态
    // ============================================

    /// @notice VIP 等级枚举 (VIP 0-4，基于30天交易量)
    enum VIPLevel {
        VIP0,  // < 1,000 USD: 10 bps (0.10%)
        VIP1,  // ≥ 1,000 USD: 9 bps (0.09%)
        VIP2,  // ≥ 2,000 USD: 8 bps (0.08%)
        VIP3,  // ≥ 5,000 USD: 6 bps (0.06%)
        VIP4   // ≥ 8,000 USD: 5 bps (0.05%)
    }

    /// @notice 用户VIP等级 (地址 => VIP等级)
    mapping(address => VIPLevel) public vipLevels;

    /// @notice 用户累计交易量 (地址 => 30天累计交易量，1e18精度，USD计价)
    mapping(address => uint256) public cumulativeTradingVolume;

    /// @notice 用户交易量记录 (地址 => 时间戳 => 交易量)
    /// @dev 用于30天滚动窗口计算
    mapping(address => mapping(uint256 => uint256)) public volumeHistory;

    /// @notice 用户交易量时间戳列表 (用于清理过期数据)
    mapping(address => uint256[]) public volumeTimestamps;

    /// @notice VIP等级对应的固定费率 (基点)
    /// @dev VIP0=10 bps, VIP1=9 bps, VIP2=8 bps, VIP3=6 bps, VIP4=5 bps
    mapping(VIPLevel => uint256) public tierFeeBps;

    /// @notice VIP升级所需的最小交易量阈值 (USD计价，1e18精度)
    /// @dev [0]=VIP0->VIP1: 1000 USD, [1]=VIP1->VIP2: 2000 USD, [2]=VIP2->VIP3: 5000 USD, [3]=VIP3->VIP4: 8000 USD
    uint256[4] public vipVolumeThresholds;

    /// @notice 项目方手续费接收地址
    address public feeReceiver;

    /// @notice 返佣比例 (基点, 默认1000 = 10%)
    uint256 public referralRebateBps = 1000;

    /// @notice 用户推荐人映射 (用户地址 => 推荐人地址)
    mapping(address => address) public referrers;

    /// @notice 累计手续费收入
    uint256 public totalFeeCollected;

    /// @notice 累计返佣支出
    uint256 public totalRebatePaid;

    // ============================================
    // 事件定义
    // ============================================

    /// @notice 保证金充值事件
    event MarginDeposited(address indexed trader, uint256 amount);
    
    /// @notice 保证金提现事件
    event MarginWithdrawn(address indexed trader, uint256 amount);
    event Liquidated(address indexed trader, address indexed liquidator, uint256 amount, uint256 reward);
    
    /// @notice 订单创建事件
    event OrderPlaced(uint256 indexed id, address indexed trader, bool isBuy, uint256 price, uint256 amount);
    
    /// @notice 订单移除事件 (成交或取消)
    event OrderRemoved(uint256 indexed id);
    
    /// @notice 成交事件
    event TradeExecuted(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        uint256 price,
        uint256 amount,
        address buyer,
        address seller
    );
    
    /// @notice 标记价格更新事件
    event MarkPriceUpdated(uint256 markPrice, uint256 indexPrice);
    
    /// @notice 资金费率更新事件
    event FundingUpdated(int256 cumulativeFundingRate, uint256 timestamp);
    
    /// @notice 资金费率参数更新事件
    event FundingParamsUpdated(uint256 interval, int256 maxRatePerInterval);
    
    /// @notice 资金费支付事件
    event FundingPaid(address indexed trader, int256 amount);

    /// @notice 操作员更新事件
    event OperatorUpdated(address operator);

    /// @notice 持仓更新事件
    event PositionUpdated(address indexed trader, int256 size, uint256 entryPrice);

    /// @notice VIP等级升级事件
    event VIPLevelUpgraded(address indexed trader, VIPLevel oldLevel, VIPLevel newLevel);

    /// @notice 交易手续费扣除事件
    event TradingFeeCharged(
        address indexed trader,
        uint256 notional,
        uint256 feeAmount,
        bool isMaker,
        VIPLevel vipLevel
    );

    /// @notice 手续费参数更新事件
    event FeeParamsUpdated(uint256 makerFeeBps, uint256 takerFeeBps, address feeReceiver);

    /// @notice VIP阈值更新事件
    event VIPThresholdsUpdated(uint256[4] thresholds);

    /// @notice 推荐人注册事件
    event ReferralRegistered(address indexed user, address indexed referrer);

    /// @notice 返佣支付事件
    event RebatePaid(
        address indexed trader,
        address indexed referrer,
        uint256 feeAmount,
        uint256 rebateAmount
    );
}
