// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

// OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CrowdFunding is Ownable, ReentrancyGuard {

    constructor() Ownable(msg.sender) {}

    enum status { Active, Failed, Success, Withdrawn }

    struct campaign {
        bytes32 campaignid;
        address owner;
        uint goalWei;
        uint deadlineTimestamp;
        uint amountcontributed;
        status state;
        mapping(address => uint) contributions;
    }

    bytes32[] public campaign_id_list;
    mapping(bytes32 => campaign) public campaign_map;

    //Create Campaign
    function createCampaign(uint256 _goalWei, uint256 _deadlineTimestamp)
        public
        returns (bytes32)
    {
        require(_goalWei > 0, "Funds requested invalid");
        require(_deadlineTimestamp > block.timestamp + 120, "Deadline invalid");

        bytes32 campaign_id = keccak256(
            abi.encodePacked(_goalWei, _deadlineTimestamp, block.number)
        );

        campaign_id_list.push(campaign_id);

        campaign storage newCampaign = campaign_map[campaign_id];
        newCampaign.campaignid = campaign_id;
        newCampaign.owner = msg.sender;
        newCampaign.goalWei = _goalWei;
        newCampaign.deadlineTimestamp = _deadlineTimestamp;
        newCampaign.amountcontributed = 0;
        newCampaign.state = status.Active;

        return campaign_id;
    }

    //Contributed Event
    event Contributed(address from, bytes32 cmpgn, uint amount);

    //Contribute
    function contribute(bytes32 _campaignId) public payable {
        campaign storage selected = campaign_map[_campaignId];

        require(selected.owner != address(0), "Campaign does not exist");             //Campaign owner should exist 
        require(selected.state == status.Active, "Campaign not active");              //Contribute only to Active Campaign
        require(msg.sender != selected.owner, "Owner cannot contribute");             //Owner cannot contribute
        require(block.timestamp < selected.deadlineTimestamp, "Campaign expired");    //Contribute only before Deadline
        require(msg.value > 0, "Invalid amount");                                     //Cannot contribute zero value

        selected.contributions[msg.sender] += msg.value;
        selected.amountcontributed += msg.value;

        if (selected.amountcontributed >= selected.goalWei) {
            selected.state = status.Success;
        }

        emit Contributed(msg.sender, _campaignId, msg.value);
    }

    // Withdraw Event
    event FundsWithdrawn(address payable to, bytes32 campaign_id);

    // Withdraw 
    function withdraw(bytes32 _campaignId) public nonReentrant {
        campaign storage selected = campaign_map[_campaignId];

        // CHECKS
        require(msg.sender == selected.owner, "Only owner can withdraw");                 //Only owner can withdraw 
        require(block.timestamp > selected.deadlineTimestamp, "Campaign ongoing");        //withdraw only for deadline 
        require(selected.state != status.Withdrawn , "Campaign already withdrawn")        // Double-withdraw reverts
        if(selected.amountcontributed >= selected.goalWei) {
            selected.state = status.success; 
        }
        require(selected.state == status.Success, "Campaign not successful");             //Make sure campaign is successful 

        // EFFECTS
        uint amount = selected.amountcontributed;
        selected.amountcontributed = 0; 
        selected.state = status.Withdrawn;

        // INTERACTION
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(payable(msg.sender), _campaignId);
    }

    function refund(bytes32 _campaignId) public nonReentrant {
        campaign storage selected = campaign_map[_campaignId];
        
        // CHECKS
        require(msg.sender != selected.owner , "Owner cannot get a Refund")
        require(block.timestamp > selected.deadlineTimestamp, "Campaign still active");  //Refund only after Deadline
        if (selected.amountcontributed < selected.goalWei) {                             //Refund only after Deadline and goal not reached
            selected.state = status.Failed;
        }
        require(selected.state == status.Failed, "Campaign not failed");

        uint contributed = selected.contributions[msg.sender];
        require(contributed > 0, "No contribution");                                     //Zero contribution refund reverts

        // EFFECTS
        selected.contributions[msg.sender] = 0;
        selected.amountcontributed -= contributed;

        // INTERACTION
        (bool success, ) = payable(msg.sender).call{value: contributed}("");
        require(success, "Refund failed");

        emit Refunded(msg.sender, _campaignId, contributed);
    }

    function getCampaign(bytes32 _campaignId) public view
        returns (
            uint goal,
            uint raised,
            uint deadline,
            address creator,
            status state
        )
    {
        campaign storage c = campaign_map[_campaignId];

        require(c.owner != address(0), "Campaign does not exist");

        return (
            c.goalWei,
            c.amountcontributed,
            c.deadlineTimestamp,
            c.owner,
            c.state
        );
    }

    function getContribution(bytes32 _campaignId, address contributor) public view
        returns (uint)
    {
        campaign storage c = campaign_map[_campaignId];

        require(c.owner != address(0), "Campaign does not exist");

        return c.contributions[contributor];
    }

    receive() external payable {}

    fallback() external payable {
        revert("Invalid call. Use contribute()");
    }
}