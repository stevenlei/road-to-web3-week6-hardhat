// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Treasury {
    // Allowed address to call this contract
    address public allowedCaller;
    uint256 public stakers;

    // Balance of an address
    mapping(address => uint256) public balances;

    // Events
    event Staked(address _staker, uint256 _amount);
    event Unstaked(address _staker, uint256 _amount);

    // Constructor
    constructor(address _allowedCaller) {
        allowedCaller = _allowedCaller;
    }

    // Set allowedCaller
    function setAllowedCaller(address _allowedCaller) external onlyCaller {
        allowedCaller = _allowedCaller;
    }

    // Stake
    function stake(address _staker) external payable onlyCaller {
        require(msg.value > 0, "Stake amount must be greater than 0");

        // Add the balance
        balances[_staker] += msg.value;

        // Add staker count
        stakers += 1;

        // Broadcast the staked event
        emit Staked(_staker, msg.value);
    }

    // Unstake
    function unstake(address _staker) external onlyCaller {
        require(
            balances[_staker] > 0,
            "Balance amount of the address must be greater than 0"
        );

        // Get the balance
        uint256 balance = balances[_staker];

        // Set the balance to 0
        balances[_staker] = 0;

        // Send back the balance to the caller contract
        (bool sent, bytes memory data) = allowedCaller.call{value: balance}("");
        require(sent, "Failed to send the balance to the caller contract");

        // Subtract staker count
        stakers -= 1;

        // Broadcast the unstaked event
        emit Unstaked(_staker, balances[_staker]);
    }

    // Withdraw function for admin, for getting the assets to invest etc.
    function adminWithdraw(address payable _to, uint256 _amount)
        external
        onlyCaller
    {
        // Send back the total balance to an address
        payable(_to).transfer(_amount);
    }

    modifier onlyCaller() {
        require(
            msg.sender == allowedCaller,
            "Only allowed caller can call this function"
        );
        _;
    }
}
