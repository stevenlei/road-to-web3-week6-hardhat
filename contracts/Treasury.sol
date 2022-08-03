// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Treasury {
    // Allowed address to call this contract
    address public allowedCaller;

    // Balance of an address
    mapping(address => uint256) public balances;

    // Events
    event Staked(address _staker, uint256 _amount);
    event Unstaked(address _staker, uint256 _amount);

    // Stake
    function stake(address _staker) external payable onlyCaller {
        require(msg.value > 0, "Stake amount must be greater than 0");

        // Add the balance
        balances[_staker] += msg.value;

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
        payable(allowedCaller).transfer(balance);

        // Broadcast the unstaked event
        emit Unstaked(_staker, balances[_staker]);
    }

    modifier onlyCaller() {
        require(
            msg.sender == allowedCaller,
            "Only allowed caller can call this function"
        );
        _;
    }
}
