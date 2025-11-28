// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RiverovaDAO
 * @author Riverova Team
 * @notice DAO governance contract for quality control and content validation
 * @dev Manages proposals, voting, and validation for educational content
 */
contract RiverovaDAO is AccessControl, ReentrancyGuard {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    /// @notice Voting period in blocks (approximately 3 days at 12s/block)
    uint256 public constant VOTING_PERIOD = 21600;

    /// @notice Minimum quorum percentage (30%)
    uint256 public constant QUORUM_PERCENTAGE = 30;

    /// @notice Proposal states
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Cancelled
    }

    /// @notice Proposal types
    enum ProposalType {
        CourseApproval,      // Approve new course content
        ContentUpdate,       // Update existing content
        QualityReview,       // Quality review for certificates
        LanguageAddition,    // Add new language support
        GovernanceChange,    // Governance parameter changes
        ValidatorAddition,   // Add new validators
        CurriculumUpdate     // Update curriculum standards
    }

    /// @notice Proposal data structure
    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        string contentHash;         // IPFS hash of detailed content
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalState state;
        bool executed;
    }

    /// @notice Vote receipt for tracking voter participation
    struct VoteReceipt {
        bool hasVoted;
        uint8 support;      // 0 = Against, 1 = For, 2 = Abstain
        uint256 votes;
    }

    /// @notice Counter for proposal IDs
    uint256 private _proposalIdCounter;

    /// @notice Total voting members
    uint256 public totalVoters;

    /// @notice Mapping from proposal ID to proposal data
    mapping(uint256 => Proposal) public proposals;

    /// @notice Mapping from proposal ID to voter address to vote receipt
    mapping(uint256 => mapping(address => VoteReceipt)) public voteReceipts;

    /// @notice Mapping to track voter registration
    mapping(address => bool) public isVoter;

    /// @notice Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title,
        uint256 startBlock,
        uint256 endBlock
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 votes
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VoterRegistered(address indexed voter);
    event VoterRemoved(address indexed voter);

    /**
     * @notice Constructor initializes the DAO
     * @param defaultAdmin Address of the default admin
     */
    constructor(address defaultAdmin) {
        require(defaultAdmin != address(0), "Invalid admin address");

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PROPOSER_ROLE, defaultAdmin);
        _grantRole(VOTER_ROLE, defaultAdmin);
        _grantRole(VALIDATOR_ROLE, defaultAdmin);

        // Register admin as initial voter
        isVoter[defaultAdmin] = true;
        totalVoters = 1;
        emit VoterRegistered(defaultAdmin);
    }

    /**
     * @notice Register a new voter
     * @param voter Address to register as voter
     */
    function registerVoter(address voter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(voter != address(0), "Invalid voter address");
        require(!isVoter[voter], "Already registered");

        isVoter[voter] = true;
        totalVoters++;
        _grantRole(VOTER_ROLE, voter);

        emit VoterRegistered(voter);
    }

    /**
     * @notice Remove a voter
     * @param voter Address to remove
     */
    function removeVoter(address voter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isVoter[voter], "Not a voter");
        require(totalVoters > 1, "Cannot remove last voter");

        isVoter[voter] = false;
        totalVoters--;
        _revokeRole(VOTER_ROLE, voter);

        emit VoterRemoved(voter);
    }

    /**
     * @notice Create a new proposal
     * @param proposalType Type of proposal
     * @param title Title of the proposal
     * @param description Description of the proposal
     * @param contentHash IPFS hash of detailed content
     * @return proposalId The ID of the created proposal
     */
    function createProposal(
        ProposalType proposalType,
        string calldata title,
        string calldata description,
        string calldata contentHash
    ) external onlyRole(PROPOSER_ROLE) returns (uint256) {
        require(bytes(title).length > 0, "Title required");
        require(bytes(description).length > 0, "Description required");

        uint256 proposalId = ++_proposalIdCounter;
        uint256 startBlock = block.number;
        uint256 endBlock = startBlock + VOTING_PERIOD;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            title: title,
            description: description,
            contentHash: contentHash,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            state: ProposalState.Active,
            executed: false
        });

        emit ProposalCreated(proposalId, msg.sender, proposalType, title, startBlock, endBlock);

        return proposalId;
    }

    /**
     * @notice Cast a vote on a proposal
     * @param proposalId The ID of the proposal
     * @param support Vote type: 0 = Against, 1 = For, 2 = Abstain
     */
    function castVote(uint256 proposalId, uint8 support) external onlyRole(VOTER_ROLE) {
        require(support <= 2, "Invalid vote type");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.number <= proposal.endBlock, "Voting period ended");
        
        VoteReceipt storage receipt = voteReceipts[proposalId][msg.sender];
        require(!receipt.hasVoted, "Already voted");

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = 1; // Each voter has 1 vote (can be modified for token-weighted voting)

        if (support == 0) {
            proposal.againstVotes += 1;
        } else if (support == 1) {
            proposal.forVotes += 1;
        } else {
            proposal.abstainVotes += 1;
        }

        emit VoteCast(proposalId, msg.sender, support, 1);
    }

    /**
     * @notice Finalize a proposal after voting period ends
     * @param proposalId The ID of the proposal
     */
    function finalizeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.number > proposal.endBlock, "Voting period not ended");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (totalVoters * QUORUM_PERCENTAGE) / 100;

        if (totalVotes >= quorumRequired && proposal.forVotes > proposal.againstVotes) {
            proposal.state = ProposalState.Succeeded;
        } else {
            proposal.state = ProposalState.Defeated;
        }
    }

    /**
     * @notice Execute a successful proposal
     * @param proposalId The ID of the proposal
     */
    function executeProposal(uint256 proposalId) external onlyRole(VALIDATOR_ROLE) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(proposal.state == ProposalState.Succeeded, "Proposal not succeeded");
        require(!proposal.executed, "Already executed");

        proposal.executed = true;
        proposal.state = ProposalState.Executed;

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancel a proposal (only proposer or admin)
     * @param proposalId The ID of the proposal
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(
            msg.sender == proposal.proposer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(
            proposal.state == ProposalState.Active || proposal.state == ProposalState.Pending,
            "Cannot cancel"
        );

        proposal.state = ProposalState.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    /**
     * @notice Get proposal details
     * @param proposalId The ID of the proposal
     * @return Proposal data
     */
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        require(proposals[proposalId].id != 0, "Proposal does not exist");
        return proposals[proposalId];
    }

    /**
     * @notice Get vote receipt for a voter on a proposal
     * @param proposalId The ID of the proposal
     * @param voter Address of the voter
     * @return VoteReceipt data
     */
    function getVoteReceipt(uint256 proposalId, address voter) external view returns (VoteReceipt memory) {
        return voteReceipts[proposalId][voter];
    }

    /**
     * @notice Get the current state of a proposal
     * @param proposalId The ID of the proposal
     * @return Current state
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        require(proposals[proposalId].id != 0, "Proposal does not exist");
        return proposals[proposalId].state;
    }

    /**
     * @notice Get total number of proposals
     * @return Total count
     */
    function totalProposals() external view returns (uint256) {
        return _proposalIdCounter;
    }

    /**
     * @notice Check if voting period is active for a proposal
     * @param proposalId The ID of the proposal
     * @return true if voting is active
     */
    function isVotingActive(uint256 proposalId) external view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.state == ProposalState.Active && block.number <= proposal.endBlock;
    }

    /**
     * @notice Get the proposal type name as a string
     * @param proposalType The proposal type
     * @return Type name
     */
    function getProposalTypeName(ProposalType proposalType) external pure returns (string memory) {
        if (proposalType == ProposalType.CourseApproval) return "Course Approval";
        if (proposalType == ProposalType.ContentUpdate) return "Content Update";
        if (proposalType == ProposalType.QualityReview) return "Quality Review";
        if (proposalType == ProposalType.LanguageAddition) return "Language Addition";
        if (proposalType == ProposalType.GovernanceChange) return "Governance Change";
        if (proposalType == ProposalType.ValidatorAddition) return "Validator Addition";
        if (proposalType == ProposalType.CurriculumUpdate) return "Curriculum Update";
        revert("Invalid proposal type");
    }
}
