// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./Treasury.sol";
import "hardhat/console.sol";

contract Stake {
    // Treasury contract to save the balance of the staker
    Treasury public treasury;

    // Balance of an address, should also handle in receive()
    mapping(address => uint256) public balances;

    // Balance of stake of an address
    mapping(address => uint256) public stakes;

    // Time to start the stake
    mapping(address => uint256) public stakedTime;

    // Available interest
    uint256 public availableInterest;

    // Available interest buffer
    uint256 public availableInterestBuffer;

    // Interest rate in gwei
    uint256 public interestRate;

    // Contract owner
    address public owner;

    // Staking Parameters
    uint256 public minStakeSeconds;
    uint256 public maxStakeSeconds;
    uint256 public withdrawalPeriodEndsSeconds;

    event Received(address sender, uint256 amount);
    event Staked(address sender, uint256 amount);
    event Unstaked(address sender, uint256 amount);
    event Withdraw(address to, uint256 amount);

    constructor(
        uint256 _interestRate,
        uint256 _minStakeSeconds,
        uint256 _maxStakeSeconds,
        uint256 _withdrawalPeriodEndsSeconds
    ) {
        owner = msg.sender;
        interestRate = _interestRate;
        minStakeSeconds = _minStakeSeconds;
        maxStakeSeconds = _maxStakeSeconds;
        withdrawalPeriodEndsSeconds = _withdrawalPeriodEndsSeconds;
    }

    // Set the treasury contract address
    function setTreasury(address _treasury) external onlyOwner {
        require(
            msg.sender == owner,
            "Only owner can set the treasury contract address"
        );

        treasury = Treasury(_treasury);
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

    // Set the withdrawalPeriodEndsSeconds
    function setwithdrawalPeriodEndsSeconds(
        uint256 _withdrawalPeriodEndsSeconds
    ) external onlyOwner {
        withdrawalPeriodEndsSeconds = _withdrawalPeriodEndsSeconds;
    }

    // When one address staked, the staked amount cannot be changed before unstake
    function stake(uint256 amount)
        public
        payable
        hasBalance(true)
        hasStaked(false)
    {
        require(amount > 0, "Stake amount must be greater than 0");
        require(
            amount <= balances[msg.sender],
            "Stake amount must be less than or equal to the balance"
        );

        // Check if this contract has enough interest (maximized) to pay the staker
        require(
            (amount * interestRate) / 1 gwei <= availableInterestBuffer,
            "Stake amount must be less than or equal to the available interest"
        );

        // Deduct the available interest buffer
        availableInterestBuffer -= (amount * interestRate) / 1 gwei;

        // Deduct the balance
        balances[msg.sender] -= amount;

        // Set the staked amount
        stakes[msg.sender] = amount;

        // Set the stake time
        stakedTime[msg.sender] = block.timestamp;

        // Send the amount to treasury
        treasury.stake{value: amount}(msg.sender);

        // Broadcast the staked event
        emit Staked(msg.sender, amount);
    }

    // Unstake the staked amount within the withdrawal period
    function unstake() public hasStaked(true) withinUnstakePeriod {
        // Get the staked amount
        uint256 amount = stakes[msg.sender];

        // Reset the staked amount to 0
        stakes[msg.sender] = 0;

        // Get the amount from treasury
        treasury.unstake(msg.sender);

        // Add the staked amount to the balance
        balances[msg.sender] += amount;

        // Get the staked seconds for interest calculation
        uint256 stakedSeconds = block.timestamp - stakedTime[msg.sender];

        // Calculate the interest
        uint256 interest = calculateInterest(amount, stakedSeconds);

        // Interest earned
        balances[msg.sender] += interest;

        // Deduct availableInterest
        availableInterest -= interest;

        // Add back the remaining interest to the buffer
        availableInterestBuffer += (amount * interestRate) / 1 gwei - interest;

        // Reset the staked time to 0
        stakedTime[msg.sender] = 0;

        // Broadcast the unstaked event
        emit Unstaked(msg.sender, amount);
    }

    // Withdraw all balance of an address
    function withdraw() public hasBalance(true) {
        // Get the balance of an address
        uint256 balance = balances[msg.sender];

        // Reset it to zero
        balances[msg.sender] = 0;

        // Send all the available balance to the sender
        payable(msg.sender).transfer(balance);

        // Broadcast the withdraw event
        emit Withdraw(msg.sender, balance);
    }

    // Deposit interest to the contract so that stakers can receive
    function depositInterest() external payable onlyOwner {
        // Add to the available interest
        availableInterest += msg.value;

        // Buffer to determine if this contract has enough interest to allow new stakes
        availableInterestBuffer += msg.value;
    }

    // Check the staked amount of an address
    function getStake(address _address) public view returns (uint256) {
        return stakes[_address];
    }

    // Check the balance of an address
    function getBalance(address _address) public view returns (uint256) {
        return balances[_address];
    }

    // Number of stakers
    function getNumStakers() public view returns (uint256) {
        return treasury.stakers();
    }

    // withdraw function for admin, for getting the assets to invest etc.
    function adminWithdraw(address _to, uint256 _amount) public onlyOwner {
        payable(_to).transfer(_amount);
    }

    // withdraw function from treasury for admin, for getting the assets to invest etc.
    function adminWithdrawTreasury(address _to, uint256 _amount)
        public
        onlyOwner
    {
        // Withdraw from treasury
        treasury.adminWithdraw(payable(_to), _amount);
    }

    // Users have to deposit to the contract before they can stake
    receive() external payable {
        // Add the balance to the sender
        balances[msg.sender] += msg.value;

        // Broadcast the received event
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

    // Square root function
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // Calculate interest with a 'easeIn' curve
    function calculateInterest(uint256 _amount, uint256 _seconds)
        public
        view
        returns (uint256)
    {
        // Calculate the maxInterest (unit: gwei)
        uint256 maxInterest = (_amount * interestRate) / 1 gwei;

        // Calculate the fulfilled percent (uint: gwei for precision)
        uint256 fulfilledPercentInGwei = 1 gwei -
            (((maxStakeSeconds - _seconds) * 1 gwei) / maxStakeSeconds);

        // Formula of easeInCubic
        uint256 multiplier = fulfilledPercentInGwei**3;

        // Calculate the interest
        return (maxInterest * multiplier) / 1 gwei**3;
    }
}
