// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

// OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrowdFund is Ownable, ReentrancyGuard {

    constructor() Ownable(msg.sender) {}

    enum status { Active, Failed, Success, Withdrawn }

    struct campaign {
        address owner;
        status state;
        uint campaignid;
        uint goalWei;
        uint deadlineTimestamp;
        uint amountcontributed;
        string metadataCID;               
        mapping(address => uint) contributions;
    }

    uint[] public campaign_id_list;
    mapping(uint => campaign) public campaign_map;
    uint256 public campaignCount;

    event CampaignCreated(uint campaign_id, address owner, uint goalWei, uint deadlineTimestamp, string metadataCID);

    // ── CREATE CAMPAIGN ──────────────────────────────────────────────
    function createCampaign(
        uint256 _goalWei,
        uint256 _deadlineTimestamp,
        string calldata _metadataCID     
    ) external returns (uint) {
        require(_goalWei > 0, "Funds requested invalid");
        require(_deadlineTimestamp > block.timestamp, "Deadline invalid");

        uint256 campaign_id = campaignCount++;

        campaign_id_list.push(campaign_id);

        campaign storage newCampaign = campaign_map[campaign_id];
        newCampaign.campaignid        = campaign_id;
        newCampaign.owner             = msg.sender;
        newCampaign.goalWei           = _goalWei;
        newCampaign.deadlineTimestamp = _deadlineTimestamp;
        newCampaign.amountcontributed = 0;
        newCampaign.state             = status.Active;
        newCampaign.metadataCID       = _metadataCID;

        emit CampaignCreated(campaign_id, msg.sender, _goalWei, _deadlineTimestamp, _metadataCID);
        return campaign_id;
    }

    // ── CONTRIBUTE ───────────────────────────────────────────────────
    event Contributed(address from, uint cmpgn, uint amount);

    function contribute(uint256 _campaignId) external payable {
        campaign storage selected = campaign_map[_campaignId];

        require(selected.owner != address(0),            "Campaign does not exist");
        require(selected.state == status.Active,          "Campaign not active");
        require(msg.sender != selected.owner,             "Owner cannot contribute");
        require(block.timestamp < selected.deadlineTimestamp, "Campaign expired");
        require(msg.value > 0,                            "Invalid amount");

        selected.contributions[msg.sender] += msg.value;
        selected.amountcontributed         += msg.value;

        emit Contributed(msg.sender, _campaignId, msg.value);
    }

    // ── WITHDRAW ─────────────────────────────────────────────────────
    event FundsWithdrawn(address payable to, uint campaign_id);

    function withdraw(uint256 _campaignId) external nonReentrant {
        campaign storage selected = campaign_map[_campaignId];

        require(msg.sender == selected.owner,                    "Only owner can withdraw");
        require(block.timestamp >= selected.deadlineTimestamp,   "Campaign ongoing");
        require(selected.state != status.Withdrawn,              "Campaign already withdrawn");

        if (selected.amountcontributed >= selected.goalWei &&
            block.timestamp >= selected.deadlineTimestamp) {
            selected.state = status.Success;
        }

        require(selected.state == status.Success, "Campaign not successful");

        uint amount = selected.amountcontributed;
        selected.amountcontributed = 0;
        selected.state = status.Withdrawn;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(payable(msg.sender), _campaignId);
    }

    // ── REFUND ───────────────────────────────────────────────────────
    event Refunded(address payable to, uint campaign_id, uint amount);

    function refund(uint _campaignId) external nonReentrant {
        campaign storage selected = campaign_map[_campaignId];

        require(msg.sender != selected.owner,                    "Owner cannot get a Refund");
        require(block.timestamp > selected.deadlineTimestamp,    "Campaign still active");

        if (selected.amountcontributed < selected.goalWei) {
            selected.state = status.Failed;
        }

        require(selected.state == status.Failed,                 "Campaign was Successful");

        uint contributed = selected.contributions[msg.sender];
        require(contributed > 0,                                 "Only contributors can get a refund");

        selected.contributions[msg.sender] = 0;
        selected.amountcontributed        -= contributed;

        (bool success, ) = payable(msg.sender).call{value: contributed}("");
        require(success, "Refund failed");

        emit Refunded(payable(msg.sender), _campaignId, contributed);
    }

    // ── READ ─────────────────────────────────────────────────────────
    function getCampaign(uint _campaignId) external view
        returns (
            uint goal,
            uint raised,
            uint deadline,
            address creator,
            status state,
            string memory metadataCID    
        )
    {
        campaign storage c = campaign_map[_campaignId];
        require(c.owner != address(0), "Campaign does not exist");
        return (
            c.goalWei,
            c.amountcontributed,
            c.deadlineTimestamp,
            c.owner,
            c.state,
            c.metadataCID               
        );
    }

    function getContribution(uint _campaignId, address contributor) external view
        returns (uint)
    {
        campaign storage c = campaign_map[_campaignId];
        require(c.owner != address(0), "Campaign does not exist");
        return c.contributions[contributor];
    }

    function getAllCampaignIds() external view returns (uint[] memory) {
        return campaign_id_list;
    }

    receive() external payable {}

    fallback() external payable {
        revert("Invalid call. Use contribute()");
    }
}
