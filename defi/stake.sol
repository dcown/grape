// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool is Ownable {
    //质押token地址
    IERC20 stakeToken;
    //质押奖励token地址
    IERC20 rewardToken;
    //每分钟产出奖励数量
    uint256 rewardPerMin;
    //某地址的质押份额
    mapping(address => uint256) private shares;
    //某地址已经提现的奖励
    mapping(address => uint256) private withdrawdReward;
    //某地址上一次关联的每份额累计已产出奖励
    mapping(address => uint256) private lastAddUpRewardPerShare;
    //某地址最近一次关联的累计已产出总奖励
    mapping(address => uint256) private lastAddUpReward;
    //每份额累计总奖励
    uint256 addUpRewardPerShare;
    //总挖矿奖励数量
    uint256 totalReward;
    //累计份额
    uint256 totalShares;

    //最近一次（如果没有最近一次则是首次）挖矿区块时间，秒
    uint256 lastBlockT;
    //最近一次（如果没有最近一次则是首次）每份额累计奖励
    uint256 lastAddUpRewardPerShareAll;

    //构造函数
    constructor(
        address _stakeTokenAddr,
        address _rewardTokenAddr,
        uint256 _rewardPerMin
    ) {
        stakeToken = IERC20(_stakeTokenAddr);
        rewardToken = IERC20(_rewardTokenAddr);
        rewardPerMin = _rewardPerMin;
    }

    //质押,【外部调用/所有人/不需要支付/读写状态】
    /// @notice 1. msg.sender转入本合约_amount数量的质押token
    /// @notice 4. 记录此时msg.sender已经产出的总奖励
    /// @notice 2. 增加msg.sender等量的质押份额
    /// @notice 3. 计算此时每份额累计总产出奖励
    function stake(uint256 _amount) external {
        stakeToken.transferFrom(msg.sender, address(this), _amount);
        uint256 currenTotalRewardPerShare = getRewardPerShare();
        lastAddUpReward[msg.sender] +=
            (currenTotalRewardPerShare - lastAddUpRewardPerShare[msg.sender]) *
            shares[msg.sender];
        shares[msg.sender] += _amount;
        updateTotalShare(_amount, 1);
        lastAddUpRewardPerShare[msg.sender] = currenTotalRewardPerShare;
    }

    //解除质押，提取token,【外部调用/所有人/不需要支付/读写状态】
    /// @notice 1. _amount必须<=已经质押的份额
    /// @notice 4. 记录此时msg.sender已经产出的总奖励
    function unStake(uint256 _amount) external {
        require(
            _amount <= shares[msg.sender],
            "UNSTAKE_AMOUNT_MUST_LESS_SHARES"
        );
        stakeToken.transferFrom(address(this), msg.sender, _amount);
        uint256 currenTotalRewardPerShare = getRewardPerShare();
        lastAddUpReward[msg.sender] +=
            (currenTotalRewardPerShare - lastAddUpRewardPerShare[msg.sender]) *
            shares[msg.sender];
        shares[msg.sender] -= _amount;
        updateTotalShare(_amount, 2);
        lastAddUpRewardPerShare[msg.sender] = currenTotalRewardPerShare;
    }

    //更新质押份额,【内部调用/合约创建者/不需要支付】
    /// @param _amount 更新的数量
    /// @param _type 1增加，其他 减少
    /// @notice 每次更新份额之前，先计算之前的份额累计奖励
    function updateTotalShare(uint256 _amount, uint256 _type)
        internal
        onlyOwner
    {
        lastAddUpRewardPerShareAll = getRewardPerShare();
        lastBlockT = block.timestamp;
        if (_type == 1) {
            totalShares += _amount;
        } else {
            totalShares -= _amount;
        }
    }

    //获取截至当前每份额累计产出,【内部调用/合约创建者/不需要支付/只读】
    /// @notice 1.（当前区块时间戳-具体当前最近一次计算的时间戳） * 每分钟产出奖励 / 60秒 / 总份额  + 距离当前最近一次计算的时候的每份额累计奖励 = 当前每份额累计奖励
    /// @notice 2. 更新最近一次计算每份额累计奖励的时间和数量
    function getRewardPerShare() internal view onlyOwner returns (uint256) {
        return
            ((block.timestamp - lastBlockT) * rewardPerMin) /
            60 /
            totalShares +
            lastAddUpRewardPerShareAll;
    }

    //计算累计奖励,【内部调用/合约创建者/不需要支付/只读】
    /// @notice 仅供内部调用，统一计算规则
    function getaddupReword(address _address)
        internal
        view
        onlyOwner
        returns (uint256)
    {
        return
            lastAddUpReward[_address] +
            ((getRewardPerShare() - lastAddUpRewardPerShare[_address]) *
                shares[_address]);
    }

    //计算可提现奖励,【内部调用/合约创建者/不需要支付/只读】
    /// @notice 仅供内部调用，统一计算规则
    function getWithdrawdReword(address _address)
        internal
        view
        onlyOwner
        returns (uint256)
    {
        return
            lastAddUpReward[_address] +
            ((getRewardPerShare() - lastAddUpRewardPerShare[_address]) *
                shares[_address]) -
            withdrawdReward[_address];
    }

    //提现收益,【外部调用/所有人/不需要支付/读写】
    /// @notice 1. 计算截至到当前的累计获得奖励
    /// @notice 2. _amount必须<=(累计获得奖励-已提现奖励)
    /// @notice 3. 提现，提现需要先增加数据，再进行提现操作
    function withdraw(uint256 _amount) external {
        require(
            _amount <= getWithdrawdReword(msg.sender),
            "WITHDRAW_AMOUNT_LESS_ADDUPREWARD"
        );
        withdrawdReward[msg.sender] += _amount;
        rewardToken.transferFrom(address(this), msg.sender, _amount);
    }

    //获取可提现奖励，【外部调用/所有人/不需要支付】
    function withdrawdReword() external view returns (uint256) {
        return getWithdrawdReword(msg.sender);
    }

    //获取已提现奖励，【外部调用/所有人/不需要支付】
    function hadWithdrawdReword() external view returns (uint256) {
        return withdrawdReward[msg.sender];
    }

    //获取累计奖励，【外部调用/所有人/不需要支付】
    function addupReword() external view returns (uint256) {
        return getaddupReword(msg.sender);
    }

    //获取质押份额,【外部调用/所有人/不需要支付/只读】
    function getShare() external view returns (uint256) {
        return shares[msg.sender];
    }
}
