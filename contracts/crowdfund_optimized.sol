// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

// OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrowdFundOptimized is Ownable, ReentrancyGuard {

    constructor() Ownable(msg.sender) {}

    enum status { Active, Failed, Success, Withdrawn }

    struct campaign {
        address owner;
        status state;
        // REMOVED: uint campaignid  → the mapping key already IS the id;
        //          storing it again wastes one 32-byte SSTORE (~20 k gas) per campaign.
        uint goalWei;
        uint deadlineTimestamp;
        uint amountcontributed;
        // REMOVED: string metadataCID  → dynamic strings cost many SSTOREs (length slot +
        //          data chunks).  The CID is emitted in CampaignCreated so off-chain
        //          indexers / frontends can read it cheaply from logs; no need to persist
        //          it in storage.
        mapping(address => uint) contributions;
    }

    // REMOVED: uint[] campaign_id_list  → pushing to a dynamic array costs ~20 k gas
    //          (new slot write + length update) on every createCampaign.  Because IDs
    //          are sequential 0..campaignCount-1, getAllCampaignIds() reconstructs the
    //          list in memory at query time with zero storage cost.
    mapping(uint => campaign) public campaign_map;
    uint256 public campaignCount;

    // metadataCID kept in the event so it is still discoverable off-chain.
    event CampaignCreated(uint campaign_id, address owner, uint goalWei, uint deadlineTimestamp, string metadataCID);

    // ── CREATE CAMPAIGN ──────────────────────────────────────────────
    function createCampaign(
        uint256 _goalWei,
        uint256 _deadlineTimestamp,
        string calldata _metadataCID      // calldata (not storage) – stays cheap
    ) external returns (uint) {
        require(_goalWei > 0, "Funds requested invalid");
        require(_deadlineTimestamp > block.timestamp, "Deadline invalid");

        uint256 campaign_id = campaignCount++;

        // No push to campaign_id_list, no campaignid field, no metadataCID storage.
        campaign storage newCampaign = campaign_map[campaign_id];
        newCampaign.owner             = msg.sender;
        newCampaign.goalWei           = _goalWei;
        newCampaign.deadlineTimestamp = _deadlineTimestamp;
        // amountcontributed defaults to 0 – explicit assignment removed (saves gas)
        // state defaults to status.Active (== 0) – explicit assignment removed
        
        emit CampaignCreated(campaign_id, msg.sender, _goalWei, _deadlineTimestamp, _metadataCID);
        return campaign_id;
    }

    // ── CONTRIBUTE ───────────────────────────────────────────────────
    event Contributed(address from, uint cmpgn, uint amount);

    function contribute(uint256 _campaignId) external payable {
        campaign storage selected = campaign_map[_campaignId];

        require(selected.owner != address(0),                     "Campaign does not exist");
        require(selected.state == status.Active,                  "Campaign not active");
        require(msg.sender != selected.owner,                     "Owner cannot contribute");
        require(block.timestamp < selected.deadlineTimestamp,     "Campaign expired");
        require(msg.value > 0,                                    "Invalid amount");

        selected.contributions[msg.sender] += msg.value;
        selected.amountcontributed         += msg.value;

        emit Contributed(msg.sender, _campaignId, msg.value);
    }

    // ── WITHDRAW ─────────────────────────────────────────────────────
    event FundsWithdrawn(address payable to, uint campaign_id);

    function withdraw(uint256 _campaignId) external nonReentrant {
        campaign storage selected = campaign_map[_campaignId];

        require(msg.sender == selected.owner,                   "Only owner can withdraw");
        require(block.timestamp >= selected.deadlineTimestamp,  "Campaign ongoing");
        require(selected.state != status.Withdrawn,             "Campaign already withdrawn");

        if (selected.amountcontributed >= selected.goalWei) {
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
            status state
            // metadataCID removed from storage; read it from the CampaignCreated event log
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

    function getContribution(uint _campaignId, address contributor) external view
        returns (uint)
    {
        campaign storage c = campaign_map[_campaignId];
        require(c.owner != address(0), "Campaign does not exist");
        return c.contributions[contributor];
    }

    /// @notice Returns all campaign IDs cheaply – computed in memory, no storage array.
    function getAllCampaignIds() external view returns (uint[] memory) {
        uint count = campaignCount;
        uint[] memory ids = new uint[](count);
        for (uint i = 0; i < count; ) {
            ids[i] = i;
            unchecked { ++i; }
        }
        return ids;
    }

    receive() external payable {}

    fallback() external payable {
        revert("Invalid call. Use contribute()");
    }
}
