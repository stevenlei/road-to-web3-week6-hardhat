// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Stake {
    // Balance of an address, should also handle in receive()
    mapping(address => uint256) public balances;

    // Balance of stake of an address
    mapping(address => uint256) public stakes;

    // Time to start the stake
    mapping(address => uint256) public stakedTime;

    // Total amount that is locked (exceeded the withdrawal period)
    uint256 public lockedAmount;

    // Available interest
    uint256 public availableInterest;

    // Interest rate in gwei
    uint256 public interestRate;

    address public owner;

    uint256 public minStakeSeconds;
    uint256 public maxStakeSeconds;

    uint256 public withdrawalPeriodSeconds;

    address public lockerAddress;

    event Received(address sender, uint256 amount);
    event Staked(address sender, uint256 amount);
    event Unstaked(address sender, uint256 amount);
    event Withdraw(address to, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    // Set the interest rate in gwei
    function setInterestRate(uint256 _interestRate) external onlyOwner {
        interestRate = _interestRate;
    }

    // Set the minStakeSeconds
    function setMinStakeSeconds(uint256 _minStakeSeconds) external onlyOwner {
        minStakeSeconds = _minStakeSeconds;
    }

    // Set the maxStakeSeconds
    function setMaxStakeSeconds(uint256 _maxStakeSeconds) external onlyOwner {
        maxStakeSeconds = _maxStakeSeconds;
    }

    // Set the withdrawalPeriodSeconds
    function setWithdrawalPeriodSeconds(uint256 _withdrawalPeriodSeconds)
        external
        onlyOwner
    {
        withdrawalPeriodSeconds = _withdrawalPeriodSeconds;
    }

    // Set the lockerAddress
    function setLockerAddress(address _lockerAddress) external onlyOwner {
        lockerAddress = _lockerAddress;
    }

    // When one address staked, the staked amount cannot be changed unless unstake
    function stake(uint256 amount)
        public
        payable
        hasBalance(true)
        hasStaked(false)
    {
        balances[msg.sender] -= amount;
        stakes[msg.sender] = amount;

        emit Staked(msg.sender, amount);
    }

    function unstake() public hasStaked(true) withinUnstakePeriod {
        // Get the staked amount
        uint256 amount = stakes[msg.sender];

        // Reset the staked amount to 0
        stakes[msg.sender] = 0;

        // Add the staked amount to the balance
        balances[msg.sender] += amount;

        uint256 stakedSeconds = stakedTime[msg.sender] - block.timestamp;

        // Interest earned
        balances[msg.sender] += calculateInterest(amount, stakedSeconds);

        // Reset the staked time to 0
        stakedTime[msg.sender] = 0;

        // Emit the unstaked event
        emit Unstaked(msg.sender, amount);
    }

    function withdraw() public hasBalance(true) {
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0;

        // Send all the sender's available balance to the sender
        payable(msg.sender).transfer(balance);

        emit Withdraw(msg.sender, balance);
    }

    function depositInterest() external payable onlyOwner {
        availableInterest += balances[msg.sender];
    }

    function _isExceededWithdrawalPeriod() private view returns (bool) {
        return
            block.timestamp >
            stakedTime[msg.sender] + withdrawalPeriodSeconds + maxStakeSeconds;
    }

    function getStake() public view returns (uint256) {}

    function getBalance() public view returns (uint256) {}

    function getUnstake() public view returns (uint256) {}

    function getWithdraw() public view returns (uint256) {}

    // Users have to deposit to the contract before they can stake.
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier hasStaked(bool _shouldBeStaked) {
        if (_shouldBeStaked) {
            require(stakes[msg.sender] > 0, "You have no stake");
        } else {
            require(stakes[msg.sender] == 0, "You have already staked");
        }

        _;
    }

    modifier hasBalance(bool _shouldBeDeposited) {
        if (_shouldBeDeposited) {
            require(balances[msg.sender] > 0, "You have no balance");
        } else {
            require(balances[msg.sender] == 0, "You have already deposited");
        }

        _;
    }

    modifier isDuringStakePeriod() {
        require(
            block.timestamp < stakedTime[msg.sender] + minStakeSeconds,
            "You can't stake yet"
        );
        _;
    }

    modifier withinUnstakePeriod() {
        uint256 unstakeTimestampFrom = stakedTime[msg.sender] + minStakeSeconds;
        uint256 unstakeTimestampUntil = stakedTime[msg.sender] +
            maxStakeSeconds;

        require(
            block.timestamp >= unstakeTimestampFrom,
            "You can't unstake yet"
        );
        require(
            block.timestamp <= unstakeTimestampUntil,
            "Unstake period exceeded"
        );

        _;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function calculateInterest(uint256 _amount, uint256 _seconds)
        public
        view
        returns (uint256)
    {
        uint256 maxInterest = (_amount * interestRate) / 1 gwei;

        uint256 fulfilled = maxStakeSeconds - _seconds;

        return
            (maxInterest * (_seconds - sqrt(_seconds - fulfilled**2))) /
            _seconds;
    }
}
