// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Order, OrderState, BalanceKind, SettleActor} from "./Types.sol";
import {IFeeHook} from "../interfaces/IFeeHook.sol";
import {INESPEvents} from "../interfaces/INESPEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NESPCore
 * @notice NESP 协议核心合约 - 无仲裁托管结算协议
 * @dev 基于 SPEC/zh/whitepaper.md (SSOT)
 *
 * 核心原则：
 * - 最小内置（Minimal Enshrinement）：无仲裁、无裁量
 * - 可信中立（Credible Neutrality）：对称规则、确定性时间窗
 * - 可验证与可重放（Verifiable & Replayable）：完整事件日志
 *
 * 状态机（13 个转换，WP §3.0）：
 * E1:  Initialized → Executing   (acceptOrder)
 * E2:  Initialized → Cancelled   (cancelOrder)
 * E3:  Executing → Reviewing     (markReady)
 * E4:  Executing → Settled       (approveReceipt)
 * E5:  Executing → Disputing     (raiseDispute)
 * E6:  Executing → Cancelled     (cancelOrder, client)
 * E7:  Executing → Cancelled     (cancelOrder, contractor)
 * E8:  Reviewing → Settled       (approveReceipt)
 * E9:  Reviewing → Settled       (timeoutSettle)
 * E10: Reviewing → Disputing     (raiseDispute)
 * E11: Reviewing → Cancelled     (cancelOrder, contractor)
 * E12: Disputing → Settled       (settleWithSigs)
 * E13: Disputing → Forfeited     (timeoutForfeit)
 */
contract NESPCore is INESPEvents {
    // ============================================
    // 库使用
    // ============================================

    using SafeERC20 for IERC20;

    // ============================================
    // 常量
    // ============================================

    /// @notice 默认履约窗口（1 天）
    uint48 public constant DEFAULT_DUE_SEC = 86400;

    /// @notice 默认评审窗口（1 天）
    uint48 public constant DEFAULT_REV_SEC = 86400;

    /// @notice 默认争议窗口（7 天）
    uint48 public constant DEFAULT_DIS_SEC = 604800;

    /// @notice ETH 资产标识（使用 address(0)）
    address public constant ETH_ADDRESS = address(0);

    // ============================================
    // 错误定义（Custom Errors，节省 Gas）
    // ============================================

    /// @notice 状态不合法（守卫失败）
    error ErrInvalidState();

    /// @notice 未授权（主体校验失败）
    error ErrUnauthorized();

    /// @notice 资金冻结（争议期禁止充值）
    error ErrFrozen();

    /// @notice 签名过期
    error ErrExpired();

    /// @notice 签名不匹配
    error ErrBadSig();

    /// @notice Nonce 重放攻击
    error ErrReplay();

    /// @notice 超出托管额（A > E）
    error ErrOverEscrow();

    /// @notice 不支持的资产
    error ErrAssetUnsupported();

    /// @notice 金额为零
    error ErrZeroAmount();

    /// @notice ForfeitPool 余额不足
    error ErrInsufficientForfeit();

    /// @notice 手续费超出限制
    error ErrFeeExceedsLimit();

    // ============================================
    // 存储
    // ============================================

    /// @notice 治理地址（可提取 ForfeitPool）
    address public governance;

    /// @notice 订单映射（orderId => Order）
    mapping(uint256 => Order) internal _orders;

    /// @notice 下一个订单 ID（自增计数器）
    uint256 public nextOrderId;

    /// @notice 聚合余额（token => user => amount）
    /// @dev Pull 模式：先记账，后提现
    mapping(address => mapping(address => uint256)) internal _balances;

    /// @notice ForfeitPool 余额（token => amount）
    /// @dev INV.8：罚没资产留存于合约，由治理提取
    mapping(address => uint256) public forfeitBalance;

    /// @notice 签名 nonce（orderId => signer => nonce）
    /// @dev 防重放攻击（WP §5.1）
    mapping(uint256 => mapping(address => uint256)) public nonces;

    /// @notice EIP-712 域分隔符
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @notice EIP-712 Settlement 类型哈希
    bytes32 public constant SETTLEMENT_TYPEHASH = keccak256(
        "Settlement(uint256 orderId,address tokenAddr,uint256 amountToSeller,address proposer,address acceptor,uint256 nonce,uint256 deadline)"
    );

    // ============================================
    // 重入防护
    // ============================================

    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "Reentrant call");
        _locked = 2;
        _;
        _locked = 1;
    }

    // ============================================
    // 构造函数
    // ============================================

    /**
     * @notice 初始化合约
     * @param _governance 治理地址
     */
    constructor(address _governance) {
        require(_governance != address(0), "Zero governance");
        governance = _governance;
        nextOrderId = 1; // 订单 ID 从 1 开始

        // 计算 EIP-712 域分隔符
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("NESP"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    // ============================================
    // 订单创建（E0: → Initialized）
    // ============================================

    /**
     * @notice 创建订单（WP §6.1）
     * @param tokenAddr 资产地址（address(0) 表示 ETH）
     * @param contractor 卖方地址
     * @param dueSec 履约窗口（秒，0 表示使用默认值）
     * @param revSec 评审窗口（秒，0 表示使用默认值）
     * @param disSec 争议窗口（秒，0 表示使用默认值）
     * @param feeHook 手续费 Hook 地址（address(0) 表示无手续费）
     * @param feeCtx 手续费上下文（仅哈希上链）
     * @return orderId 订单 ID
     */
    function createOrder(
        address tokenAddr,
        address contractor,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec,
        address feeHook,
        bytes calldata feeCtx
    ) external returns (uint256 orderId) {
        // 参数校验
        require(contractor != address(0), "Zero contractor");
        require(contractor != msg.sender, "Self-dealing");

        // 使用默认值（0 表示采用默认）
        if (dueSec == 0) dueSec = DEFAULT_DUE_SEC;
        if (revSec == 0) revSec = DEFAULT_REV_SEC;
        if (disSec == 0) disSec = DEFAULT_DIS_SEC;

        // 分配订单 ID
        orderId = nextOrderId++;

        // 初始化订单
        Order storage order = _orders[orderId];
        order.client = msg.sender;
        order.contractor = contractor;
        order.tokenAddr = tokenAddr;
        order.state = OrderState.Initialized;
        order.escrow = 0; // 初始托管为 0
        order.dueSec = dueSec;
        order.revSec = revSec;
        order.disSec = disSec;
        order.feeHook = feeHook;
        order.feeCtxHash = keccak256(feeCtx); // 仅存储哈希

        // 触发事件
        emit OrderCreated(orderId, msg.sender, contractor, tokenAddr, dueSec, revSec, disSec, feeHook, order.feeCtxHash);
    }

    /**
     * @notice 创建并充值订单
     * @dev 组合 createOrder + depositEscrow，节省一次交易
     */
    function createAndDeposit(
        address tokenAddr,
        address contractor,
        uint48 dueSec,
        uint48 revSec,
        uint48 disSec,
        address feeHook,
        bytes calldata feeCtx,
        uint256 amount
    ) external payable returns (uint256 orderId) {
        // 创建订单
        orderId = createOrder(tokenAddr, contractor, dueSec, revSec, disSec, feeHook, feeCtx);

        // 充值（内部调用，不会重入）
        _depositEscrow(orderId, amount, msg.sender, address(0));
    }

    // ============================================
    // 托管充值（SIA3: 状态不变动作）
    // ============================================

    /**
     * @notice 补充托管额（WP §3.2 SIA3）
     * @param orderId 订单 ID
     * @param amount 充值金额
     * @dev Permissionless：允许任意地址充值（第三方赠与）
     */
    function depositEscrow(uint256 orderId, uint256 amount) external payable {
        _depositEscrow(orderId, amount, msg.sender, address(0));
    }

    /**
     * @notice 内部充值逻辑
     */
    function _depositEscrow(uint256 orderId, uint256 amount, address from, address via) internal {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (amount == 0) revert ErrZeroAmount();
        if (order.state == OrderState.Disputing || order.state == OrderState.Settled || order.state == OrderState.Forfeited || order.state == OrderState.Cancelled) {
            revert ErrFrozen();
        }

        // 转账（ETH 或 ERC-20）
        if (order.tokenAddr == ETH_ADDRESS) {
            // ETH
            require(msg.value == amount, "ETH mismatch");
        } else {
            // ERC-20
            require(msg.value == 0, "No ETH for ERC20");

            // 余额差核验（INV.7：防止手续费代币攻击）
            uint256 balanceBefore = IERC20(order.tokenAddr).balanceOf(address(this));
            IERC20(order.tokenAddr).safeTransferFrom(from, address(this), amount);
            uint256 balanceAfter = IERC20(order.tokenAddr).balanceOf(address(this));

            // 验证实际到账金额（防止通缩代币/手续费代币）
            require(balanceAfter - balanceBefore == amount, "Transfer amount mismatch");
        }

        // Effects：单调增加托管额
        order.escrow += amount;

        // 触发事件
        emit EscrowDeposited(orderId, from, amount, order.escrow, via);
    }

    // ============================================
    // 只读查询
    // ============================================

    /**
     * @notice 查询订单详情
     * @param orderId 订单 ID
     * @return order 订单结构体
     */
    function getOrder(uint256 orderId) external view returns (Order memory order) {
        return _orders[orderId];
    }

    /**
     * @notice 查询可提余额
     * @param tokenAddr 资产地址
     * @param account 账户地址
     * @return 可提余额
     */
    function withdrawableOf(address tokenAddr, address account) external view returns (uint256) {
        return _balances[tokenAddr][account];
    }

    // ============================================
    // 状态转换：E1-E7（第一批）
    // ============================================

    /**
     * @notice E1: 接单（Initialized → Executing）
     * @param orderId 订单 ID
     * @dev WP §3.1 Transition E1
     *      守卫：Condition(Initialized) ∧ Subject(contractor)
     *      效果：state ← Executing, startTime ← now
     */
    function acceptOrder(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (order.state != OrderState.Initialized) revert ErrInvalidState();

        // 守卫：Subject
        if (msg.sender != order.contractor) revert ErrUnauthorized();

        // Effects
        order.state = OrderState.Executing;
        order.startTime = uint48(block.timestamp);

        // 触发事件
        emit Accepted(orderId, order.escrow);
    }

    /**
     * @notice E2: 取消订单（Initialized → Cancelled）
     * @param orderId 订单 ID
     * @dev WP §3.1 Transition E2
     *      守卫：Condition(Initialized) ∧ Subject(client)
     *      效果：state ← Cancelled, 退款给 client
     */
    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：根据当前状态判断
        if (order.state == OrderState.Initialized) {
            // E2: Initialized → Cancelled (client only)
            if (msg.sender != order.client) revert ErrUnauthorized();

        } else if (order.state == OrderState.Executing) {
            // E6/E7: Executing → Cancelled (双方都可以)
            if (msg.sender != order.client && msg.sender != order.contractor) revert ErrUnauthorized();

        } else if (order.state == OrderState.Reviewing) {
            // E11: Reviewing → Cancelled (contractor only)
            if (msg.sender != order.contractor) revert ErrUnauthorized();

        } else {
            revert ErrInvalidState();
        }

        // Effects
        order.state = OrderState.Cancelled;

        // 退款给 client（如果有托管）
        if (order.escrow > 0) {
            _creditBalance(orderId, order.client, order.tokenAddr, order.escrow, BalanceKind.Refund);
        }

        // 触发事件
        emit Cancelled(orderId, msg.sender);
    }

    /**
     * @notice E3: 标记完成（Executing → Reviewing）
     * @param orderId 订单 ID
     * @dev WP §3.1 Transition E3
     *      守卫：Condition(Executing) ∧ Subject(contractor)
     *      效果：state ← Reviewing, readyAt ← now
     */
    function markReady(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (order.state != OrderState.Executing) revert ErrInvalidState();

        // 守卫：Subject
        if (msg.sender != order.contractor) revert ErrUnauthorized();

        // Effects
        order.state = OrderState.Reviewing;
        order.readyAt = uint48(block.timestamp);

        // 触发事件
        emit ReadyMarked(orderId, order.readyAt);
    }

    /**
     * @notice E4/E8: 验收完成（Executing/Reviewing → Settled）
     * @param orderId 订单 ID
     * @dev WP §3.1 Transition E4, E8
     *      守卫：Condition(Executing | Reviewing) ∧ Subject(client)
     *      效果：state ← Settled, 结清给 contractor（A = E）
     */
    function approveReceipt(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (order.state != OrderState.Executing && order.state != OrderState.Reviewing) revert ErrInvalidState();

        // 守卫：Subject
        if (msg.sender != order.client) revert ErrUnauthorized();

        // 结清：A = E（全额给卖方）
        _settle(orderId, order.escrow, SettleActor.Client);
    }

    /**
     * @notice E5/E10: 发起争议（Executing/Reviewing → Disputing）
     * @param orderId 订单 ID
     * @dev WP §3.1 Transition E5, E10
     *      守卫：Condition(Executing | Reviewing) ∧ Subject(client | contractor)
     *      效果：state ← Disputing, disputeStart ← now
     */
    function raiseDispute(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (order.state != OrderState.Executing && order.state != OrderState.Reviewing) revert ErrInvalidState();

        // 守卫：Subject（双方都可以发起）
        if (msg.sender != order.client && msg.sender != order.contractor) revert ErrUnauthorized();

        // Effects
        order.state = OrderState.Disputing;
        order.disputeStart = uint48(block.timestamp);

        // 触发事件
        emit DisputeRaised(orderId, msg.sender);
    }

    // ============================================
    // 状态转换：E9, E12, E13（第二批）
    // ============================================

    /**
     * @notice E9: 超时自动结清（Reviewing → Settled）
     * @param orderId 订单 ID
     * @dev WP §3.1 Transition E9
     *      守卫：Condition(Reviewing) ∧ Time(readyAt + revSec ≤ now)
     *      效果：state ← Settled, 结清给 contractor（A = E）
     *      Permissionless：任何人都可以触发（节省 client gas）
     */
    function timeoutSettle(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (order.state != OrderState.Reviewing) revert ErrInvalidState();

        // 守卫：Time（评审窗口超时）
        if (block.timestamp < order.readyAt + order.revSec) revert ErrInvalidState();

        // 结清：A = E（全额给卖方）
        _settle(orderId, order.escrow, SettleActor.Timeout);
    }

    /**
     * @notice E12: 签名协商结清（Disputing → Settled）
     * @param orderId 订单 ID
     * @param amountToSeller 协商金额（A）
     * @param proposer 提议方地址
     * @param acceptor 接受方地址
     * @param nonce 提议方的 nonce
     * @param deadline 签名有效期
     * @param proposerSig 提议方签名
     * @param acceptorSig 接受方签名
     * @param feeCtx 手续费上下文（必须与 order.feeCtxHash 匹配）
     * @dev WP §3.1 Transition E12
     *      守卫：Condition(Disputing) ∧ Sigs(proposer, acceptor) ∧ (A ≤ E)
     *      效果：state ← Settled, 结清给 contractor（A）
     *      Permissionless：任何人都可以提交（链下协商，链上执行）
     */
    function settleWithSigs(
        uint256 orderId,
        uint256 amountToSeller,
        address proposer,
        address acceptor,
        uint256 nonce,
        uint256 deadline,
        bytes calldata proposerSig,
        bytes calldata acceptorSig,
        bytes calldata feeCtx
    ) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (order.state != OrderState.Disputing) revert ErrInvalidState();

        // 守卫：Time（签名未过期）
        if (block.timestamp > deadline) revert ErrExpired();

        // 守卫：Amount（A ≤ E）
        if (amountToSeller > order.escrow) revert ErrOverEscrow();

        // 守卫：Subject（proposer 和 acceptor 必须是 client 和 contractor）
        if (!((proposer == order.client && acceptor == order.contractor) ||
              (proposer == order.contractor && acceptor == order.client))) {
            revert ErrUnauthorized();
        }

        // 守卫：Nonce（防重放）
        if (nonces[orderId][proposer] != nonce) revert ErrReplay();
        nonces[orderId][proposer]++; // 消费 nonce

        // 守卫：FeeCtx（必须与创建时的哈希匹配）
        if (keccak256(feeCtx) != order.feeCtxHash) revert ErrBadSig();

        // 守卫：Signatures（EIP-712 验证）
        bytes32 structHash = keccak256(
            abi.encode(
                SETTLEMENT_TYPEHASH,
                orderId,
                order.tokenAddr,
                amountToSeller,
                proposer,
                acceptor,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        // 验证 proposer 签名
        if (!_verifySignature(digest, proposerSig, proposer)) revert ErrBadSig();

        // 验证 acceptor 签名
        if (!_verifySignature(digest, acceptorSig, acceptor)) revert ErrBadSig();

        // 结清：A = amountToSeller
        _settle(orderId, amountToSeller, SettleActor.Client); // 使用 Client 标识人工协商

        // 触发额外事件（记录协商细节）
        emit AmountSettled(orderId, proposer, acceptor, amountToSeller, nonce);
    }

    /**
     * @notice E13: 超时没收（Disputing → Forfeited）
     * @param orderId 订单 ID
     * @dev WP §3.1 Transition E13
     *      守卫：Condition(Disputing) ∧ Time(disputeStart + disSec ≤ now)
     *      效果：state ← Forfeited, 托管额进入 ForfeitPool
     *      Permissionless：任何人都可以触发
     */
    function timeoutForfeit(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];

        // 守卫：Condition
        if (order.state != OrderState.Disputing) revert ErrInvalidState();

        // 守卫：Time（争议窗口超时）
        if (block.timestamp < order.disputeStart + order.disSec) revert ErrInvalidState();

        // Effects
        order.state = OrderState.Forfeited;

        // 托管额进入 ForfeitPool
        uint256 amount = order.escrow;
        if (amount > 0) {
            forfeitBalance[order.tokenAddr] += amount;
        }

        // 触发事件
        emit Forfeited(orderId, order.tokenAddr, amount);
    }

    // ============================================
    // 辅助功能：窗口延长（SIA1, SIA2）
    // ============================================

    /**
     * @notice SIA1: 延长履约窗口（WP §3.2 SIA1）
     * @param orderId 订单 ID
     * @param newDueSec 新的履约窗口（秒）
     * @dev 守卫：Subject(client) ∧ Condition(Executing) ∧ (newDueSec > dueSec)
     */
    function extendDue(uint256 orderId, uint48 newDueSec) external {
        Order storage order = _orders[orderId];

        // 守卫：Subject
        if (msg.sender != order.client) revert ErrUnauthorized();

        // 守卫：Condition
        if (order.state != OrderState.Executing) revert ErrInvalidState();

        // 守卫：单调性
        if (newDueSec <= order.dueSec) revert ErrInvalidState();

        // Effects
        uint48 oldDueSec = order.dueSec;
        order.dueSec = newDueSec;

        // 触发事件
        emit DueExtended(orderId, oldDueSec, newDueSec, msg.sender);
    }

    /**
     * @notice SIA2: 延长评审窗口（WP §3.2 SIA2）
     * @param orderId 订单 ID
     * @param newRevSec 新的评审窗口（秒）
     * @dev 守卫：Subject(contractor) ∧ Condition(Reviewing) ∧ (newRevSec > revSec)
     */
    function extendReview(uint256 orderId, uint48 newRevSec) external {
        Order storage order = _orders[orderId];

        // 守卫：Subject
        if (msg.sender != order.contractor) revert ErrUnauthorized();

        // 守卫：Condition
        if (order.state != OrderState.Reviewing) revert ErrInvalidState();

        // 守卫：单调性
        if (newRevSec <= order.revSec) revert ErrInvalidState();

        // Effects
        uint48 oldRevSec = order.revSec;
        order.revSec = newRevSec;

        // 触发事件
        emit ReviewExtended(orderId, oldRevSec, newRevSec, msg.sender);
    }

    // ============================================
    // 内部逻辑：结算与记账
    // ============================================

    /**
     * @notice 统一结清逻辑（WP §4.2）
     * @param orderId 订单 ID
     * @param amountToSeller 结清金额（A）
     * @param actor 触发方
     * @dev 三笔记账：
     *      1. contractor 收款（A - fee）
     *      2. provider 手续费（fee，如果有）
     *      3. client 退款（E - A，如果 A < E）
     */
    function _settle(uint256 orderId, uint256 amountToSeller, SettleActor actor) internal {
        Order storage order = _orders[orderId];

        // Effects
        order.state = OrderState.Settled;

        // 计算手续费
        uint256 fee = 0;
        address feeRecipient = address(0);

        if (order.feeHook != address(0) && amountToSeller > 0) {
            // 调用 FeeHook（STATICCALL，Gas 限制 50k）
            try IFeeHook(order.feeHook).onSettleFee{gas: 50000}(
                orderId,
                order.client,
                order.contractor,
                amountToSeller,
                "" // feeCtx 由调用方提供（在 settleWithSigs 中验证哈希）
            ) returns (address _recipient, uint256 _fee) {
                // 验证 fee ≤ amountToSeller
                if (_fee > amountToSeller) revert ErrFeeExceedsLimit();
                fee = _fee;
                feeRecipient = _recipient;
            } catch {
                // Hook 失败时不收取手续费（容错设计）
                fee = 0;
            }
        }

        // 三笔记账
        uint256 payoutToContractor = amountToSeller - fee;

        // 1. contractor 收款（Payout）
        if (payoutToContractor > 0) {
            _creditBalance(orderId, order.contractor, order.tokenAddr, payoutToContractor, BalanceKind.Payout);
        }

        // 2. provider 手续费（Fee）
        if (fee > 0 && feeRecipient != address(0)) {
            _creditBalance(orderId, feeRecipient, order.tokenAddr, fee, BalanceKind.Fee);
        }

        // 3. client 退款（Refund，如果 A < E）
        if (amountToSeller < order.escrow) {
            uint256 refund = order.escrow - amountToSeller;
            _creditBalance(orderId, order.client, order.tokenAddr, refund, BalanceKind.Refund);
        }

        // 触发事件
        emit Settled(orderId, amountToSeller, order.escrow, actor);
    }

    /**
     * @notice 记账到 Pull 余额（WP §4.2）
     * @param orderId 订单 ID（用于事件）
     * @param to 接收地址
     * @param tokenAddr 资产地址
     * @param amount 记账金额
     * @param kind 余额类型
     */
    function _creditBalance(
        uint256 orderId,
        address to,
        address tokenAddr,
        uint256 amount,
        BalanceKind kind
    ) internal {
        if (amount == 0) return;

        _balances[tokenAddr][to] += amount;

        // 触发事件
        emit BalanceCredited(orderId, to, tokenAddr, amount, kind);
    }

    /**
     * @notice EIP-712 签名验证（简化版）
     * @param digest EIP-712 摘要
     * @param signature 签名（65 字节）
     * @param expectedSigner 期望签名者
     * @return 是否匹配
     */
    function _verifySignature(bytes32 digest, bytes calldata signature, address expectedSigner) internal pure returns (bool) {
        if (signature.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        // ecrecover 返回 address(0) 表示无效签名
        address recoveredSigner = ecrecover(digest, v, r, s);
        return recoveredSigner == expectedSigner;
    }

    // ============================================
    // 用户提现（Pull 模式）
    // ============================================

    /**
     * @notice 提现余额（WP §4.2）
     * @param tokenAddr 资产地址
     * @dev Permissionless：用户自主提现
     */
    function withdraw(address tokenAddr) external nonReentrant {
        uint256 amount = _balances[tokenAddr][msg.sender];

        // 守卫
        if (amount == 0) revert ErrZeroAmount();

        // Effects
        _balances[tokenAddr][msg.sender] = 0;

        // Interactions（CEI 模式）
        if (tokenAddr == ETH_ADDRESS) {
            // ETH
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC-20
            IERC20(tokenAddr).safeTransfer(msg.sender, amount);
        }

        // 触发事件
        emit BalanceWithdrawn(msg.sender, tokenAddr, amount);
    }

    // ============================================
    // 治理功能
    // ============================================

    /**
     * @notice 提取 ForfeitPool（WP §11.2）
     * @param tokenAddr 资产地址
     * @param to 接收地址
     * @param amount 提现金额
     * @dev 仅治理地址可调用
     */
    function withdrawForfeit(address tokenAddr, address to, uint256 amount) external nonReentrant {
        // 守卫：Subject
        if (msg.sender != governance) revert ErrUnauthorized();

        // 守卫：Amount
        if (amount > forfeitBalance[tokenAddr]) revert ErrInsufficientForfeit();

        // Effects
        forfeitBalance[tokenAddr] -= amount;

        // Interactions
        if (tokenAddr == ETH_ADDRESS) {
            // ETH
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC-20
            IERC20(tokenAddr).safeTransfer(to, amount);
        }

        // 触发事件
        emit ProtocolFeeWithdrawn(tokenAddr, to, amount, msg.sender);
    }

    /**
     * @notice 变更治理地址
     * @param newGovernance 新治理地址
     * @dev 仅当前治理地址可调用
     */
    function setGovernance(address newGovernance) external {
        if (msg.sender != governance) revert ErrUnauthorized();
        require(newGovernance != address(0), "Zero governance");
        governance = newGovernance;
    }

    // ============================================
    // Receive ETH（支持直接转账）
    // ============================================

    receive() external payable {
        // 接受 ETH（用于 ForfeitPool 或其他场景）
    }
}
