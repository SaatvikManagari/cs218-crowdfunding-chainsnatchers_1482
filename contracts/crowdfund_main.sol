// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

// OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CrowdFund — A decentralised crowdfunding contract 
/// @notice Allows anyone to create fundraising campaigns, accept ETH contributions,
///         and either withdraw funds on success or claim a refund on failure.
/// @dev Inherits OpenZeppelin `Ownable` for contract-level admin access and
///      `ReentrancyGuard` to protect ETH transfer functions.
contract CrowdFund is Ownable, ReentrancyGuard {

    /// @notice Initialises the contract and sets the deployer as the owner.
    constructor() Ownable(msg.sender) {}

    /// @notice Lifecycle states a campaign can be in.
    /// @dev State transitions:
    ///      Active → Failed   (deadline passed, goal not met)
    ///      Active → Success  (deadline passed, goal met)
    ///      Success → Withdrawn (owner has pulled funds)
    enum status { Active, Failed, Success, Withdrawn }

    /// @notice Stores all data for a single campaign.
    /// @dev Uses a nested mapping for per-contributor balances; this prevents
    ///      the struct from being returned directly from public getters.
    struct campaign {
        /// @dev Address of the campaign creator.
        address owner;
        /// @dev Current lifecycle state.
        status state;
        /// @dev Unique numeric identifier (matches the key in `campaign_map`).
        uint campaignid;
        /// @dev Funding goal expressed in wei.
        uint goalWei;
        /// @dev Unix timestamp after which contributions are no longer accepted.
        uint deadlineTimestamp;
        /// @dev Running total of all contributions received, in wei.
        uint amountcontributed;
        /// @dev IPFS CID pointing to off-chain campaign metadata (title, description, image, etc.).
        string metadataCID;
        /// @dev Maps each contributor's address to the total wei they have sent.
        mapping(address => uint) contributions;
    }

    /// @notice Ordered list of all campaign IDs ever created.
    uint[] public campaign_id_list;

    /// @notice Maps a campaign ID to its `campaign` storage struct.
    mapping(uint => campaign) public campaign_map;

    /// @notice Total number of campaigns created (also used to derive the next ID).
    uint256 public campaignCount;

    // ── EVENTS ───────────────────────────────────────────────────────

    /// @notice Emitted when a new campaign is successfully created.
    /// @param campaign_id      The unique ID assigned to the new campaign.
    /// @param owner            Address of the campaign creator.
    /// @param goalWei          Funding goal in wei.
    /// @param deadlineTimestamp Unix timestamp of the campaign deadline.
    /// @param metadataCID      IPFS CID for off-chain campaign metadata.
    event CampaignCreated(uint campaign_id, address owner, uint goalWei, uint deadlineTimestamp, string metadataCID);

    /// @notice Emitted when a contributor sends ETH to a campaign.
    /// @param from       Address of the contributor.
    /// @param cmpgn      ID of the campaign that received the contribution.
    /// @param amount     Amount contributed in wei.
    event Contributed(address from, uint cmpgn, uint amount);

    /// @notice Emitted when a campaign owner successfully withdraws raised funds.
    /// @param to          Address the funds were sent to (the campaign owner).
    /// @param campaign_id ID of the campaign from which funds were withdrawn.
    event FundsWithdrawn(address payable to, uint campaign_id);

    /// @notice Emitted when a contributor successfully claims a refund.
    /// @param to          Address the refund was sent to.
    /// @param campaign_id ID of the campaign from which the refund was issued.
    /// @param amount      Amount refunded in wei.
    event Refunded(address payable to, uint campaign_id, uint amount);

    // ── CREATE CAMPAIGN ──────────────────────────────────────────────

    /// @notice Creates a new crowdfunding campaign.
    /// @dev Increments `campaignCount` (pre-increment used as the new ID),
    ///      pushes the ID to `campaign_id_list`, and initialises the storage struct.
    ///      Emits {CampaignCreated}.
    /// @param _goalWei          Minimum amount of wei that must be raised for the campaign to succeed.
    /// @param _deadlineTimestamp Unix timestamp after which no more contributions are accepted.
    ///                           Must be strictly greater than the current block timestamp.
    /// @param _metadataCID      IPFS content identifier for off-chain metadata.
    /// @return                  The ID assigned to the newly created campaign.
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

    /// @notice Sends ETH to an active campaign as a contribution.
    /// @dev The full `msg.value` is credited to the caller's contribution balance.
    ///      The campaign owner is not allowed to contribute to their own campaign.
    ///      Emits {Contributed}.
    /// @param _campaignId ID of the campaign to fund.
    function contribute(uint256 _campaignId) external payable {
        campaign storage selected = campaign_map[_campaignId];

        require(selected.owner != address(0),                 "Campaign does not exist");
        require(selected.state == status.Active,               "Campaign not active");
        require(msg.sender != selected.owner,                  "Owner cannot contribute");
        require(block.timestamp < selected.deadlineTimestamp,  "Campaign expired");
        require(msg.value > 0,                                 "Invalid amount");

        selected.contributions[msg.sender] += msg.value;
        selected.amountcontributed         += msg.value;

        emit Contributed(msg.sender, _campaignId, msg.value);
    }

    // ── WITHDRAW ─────────────────────────────────────────────────────

    /// @notice Allows the campaign owner to withdraw all raised funds after a successful campaign.
    /// @dev Checks that the deadline has passed and the goal was met before transferring.
    ///      Sets `amountcontributed` to zero and transitions state to `Withdrawn` before
    ///      the external call to guard against reentrancy (in addition to the `nonReentrant` modifier).
    ///      Emits {FundsWithdrawn}.
    /// @param _campaignId ID of the campaign whose funds should be withdrawn.
    function withdraw(uint256 _campaignId) external nonReentrant {
        campaign storage selected = campaign_map[_campaignId];

        require(msg.sender == selected.owner,                   "Only owner can withdraw");
        require(block.timestamp >= selected.deadlineTimestamp,  "Campaign ongoing");
        require(selected.state != status.Withdrawn,             "Campaign already withdrawn");

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

    /// @notice Allows a contributor to reclaim their ETH after a failed campaign.
    /// @dev A campaign is considered failed when the deadline has passed and the goal
    ///      was not reached. Clears the caller's contribution balance before the external
    ///      call to guard against reentrancy (in addition to the `nonReentrant` modifier).
    ///      Emits {Refunded}.
    /// @param _campaignId ID of the campaign from which the refund is requested.
    function refund(uint _campaignId) external nonReentrant {
        campaign storage selected = campaign_map[_campaignId];

        require(msg.sender != selected.owner,                   "Owner cannot get a Refund");
        require(block.timestamp > selected.deadlineTimestamp,   "Campaign still active");

        if (selected.amountcontributed < selected.goalWei) {
            selected.state = status.Failed;
        }

        require(selected.state == status.Failed,                "Campaign was Successful");

        uint contributed = selected.contributions[msg.sender];
        require(contributed > 0,                                "Only contributors can get a refund");

        selected.contributions[msg.sender] = 0;
        selected.amountcontributed        -= contributed;

        (bool success, ) = payable(msg.sender).call{value: contributed}("");
        require(success, "Refund failed");

        emit Refunded(payable(msg.sender), _campaignId, contributed);
    }

    // ── READ ─────────────────────────────────────────────────────────

    /// @notice Returns the core details of a campaign.
    /// @dev Reverts if no campaign exists at `_campaignId` (i.e. owner is the zero address).
    /// @param _campaignId ID of the campaign to query.
    /// @return goal        Funding goal in wei.
    /// @return raised      Total wei contributed so far.
    /// @return deadline    Unix timestamp of the campaign deadline.
    /// @return creator     Address of the campaign owner.
    /// @return state       Current lifecycle state of the campaign.
    /// @return metadataCID IPFS CID for off-chain metadata.
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

    /// @notice Returns the total wei contributed to a campaign by a specific address.
    /// @param _campaignId  ID of the campaign to query.
    /// @param contributor  Address of the contributor to look up.
    /// @return             Total wei contributed by `contributor` to the given campaign.
    function getContribution(uint _campaignId, address contributor) external view
        returns (uint)
    {
        campaign storage c = campaign_map[_campaignId];
        require(c.owner != address(0), "Campaign does not exist");
        return c.contributions[contributor];
    }

    /// @notice Returns the IDs of all campaigns that have ever been created.
    /// @return An array of campaign IDs in creation order.
    function getAllCampaignIds() external view returns (uint[] memory) {
        return campaign_id_list;
    }

    // ── FALLBACKS ────────────────────────────────────────────────────

    /// @notice Accepts plain ETH transfers sent directly to the contract.
    receive() external payable {}

    /// @notice Reverts any call that does not match a valid function signature.
    /// @dev Prevents accidental ETH loss from miscoded calls.
    fallback() external payable {
        revert("Invalid call. Use contribute()");
    }
}
