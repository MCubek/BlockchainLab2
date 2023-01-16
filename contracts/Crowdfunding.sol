// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Timer.sol";

/// This contract represents most simple crowdfunding campaign.
/// This contract does not protects investors from not receiving goods
/// they were promised from crowdfunding owner. This kind of contract
/// might be suitable for campaigns that does not promise anything to the
/// investors except that they will start working on some project.
/// (e.g. almost all blockchain spinoffs.)
contract Crowdfunding {

    address payable private owner;

    Timer private timer;

    uint256 public goal;

    uint256 public endTimestamp;

    mapping(address => uint256) public investments;

    constructor(
        address _owner,
        Timer _timer,
        uint256 _goal,
        uint256 _endTimestamp
    ) {
        owner = payable(_owner == address(0) ? msg.sender : _owner);
        timer = _timer;
        // Not checking if this is correctly injected.
        goal = _goal;
        endTimestamp = _endTimestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Failed as not owner.");
        _;
    }

    modifier beforeDeadline() {
        require(timer.getTime() < endTimestamp, "Function can't be called after deadline.");
        _;
    }

    modifier afterDeadline(){
        require(timer.getTime() >= endTimestamp, "Function can't be called before deadline.");
        _;
    }

    modifier goalReached(){
        require(address(this).balance >= goal, "Function can't be called when goal is not reached.");
        _;
    }

    modifier goalNotReached(){
        require(address(this).balance < goal, "Function can't be called when goal is reached.");
        _;
    }

    function invest() beforeDeadline public payable {
        investments[msg.sender] += msg.value;
    }

    function claimFunds() onlyOwner afterDeadline goalReached public {
        owner.transfer(address(this).balance);
    }

    function refund() afterDeadline goalNotReached public {
        uint256 amount = investments[msg.sender];

        investments[msg.sender] -= amount;
        bool success = payable(msg.sender).send(amount);

        require(success, "Refund not successful.");
    }

}