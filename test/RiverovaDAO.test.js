const { expect } = require("chai");
const { ethers } = require("hardhat");
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

describe("RiverovaDAO", function () {
  let dao;
  let owner;
  let proposer;
  let voter1;
  let voter2;
  let voter3;
  let validator;

  const ProposalType = {
    CourseApproval: 0,
    ContentUpdate: 1,
    QualityReview: 2,
    LanguageAddition: 3,
    GovernanceChange: 4,
    ValidatorAddition: 5,
    CurriculumUpdate: 6
  };

  const ProposalState = {
    Pending: 0,
    Active: 1,
    Defeated: 2,
    Succeeded: 3,
    Executed: 4,
    Cancelled: 5
  };

  beforeEach(async function () {
    [owner, proposer, voter1, voter2, voter3, validator] = await ethers.getSigners();

    const RiverovaDAO = await ethers.getContractFactory("RiverovaDAO");
    dao = await RiverovaDAO.deploy(owner.address);
    await dao.waitForDeployment();

    // Grant roles
    const PROPOSER_ROLE = await dao.PROPOSER_ROLE();
    const VALIDATOR_ROLE = await dao.VALIDATOR_ROLE();
    await dao.grantRole(PROPOSER_ROLE, proposer.address);
    await dao.grantRole(VALIDATOR_ROLE, validator.address);

    // Register voters
    await dao.registerVoter(voter1.address);
    await dao.registerVoter(voter2.address);
    await dao.registerVoter(voter3.address);
  });

  describe("Deployment", function () {
    it("Should set the correct admin", async function () {
      const DEFAULT_ADMIN_ROLE = await dao.DEFAULT_ADMIN_ROLE();
      expect(await dao.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
    });

    it("Should register initial voter (admin)", async function () {
      expect(await dao.isVoter(owner.address)).to.be.true;
      expect(await dao.totalVoters()).to.equal(4); // owner + 3 voters
    });
  });

  describe("Voter Management", function () {
    it("Should register a new voter", async function () {
      const newVoter = (await ethers.getSigners())[6];
      
      await expect(dao.registerVoter(newVoter.address))
        .to.emit(dao, "VoterRegistered")
        .withArgs(newVoter.address);

      expect(await dao.isVoter(newVoter.address)).to.be.true;
      expect(await dao.totalVoters()).to.equal(5);
    });

    it("Should remove a voter", async function () {
      await expect(dao.removeVoter(voter3.address))
        .to.emit(dao, "VoterRemoved")
        .withArgs(voter3.address);

      expect(await dao.isVoter(voter3.address)).to.be.false;
      expect(await dao.totalVoters()).to.equal(3);
    });

    it("Should not allow duplicate registration", async function () {
      await expect(dao.registerVoter(voter1.address))
        .to.be.revertedWith("Already registered");
    });
  });

  describe("Proposal Creation", function () {
    it("Should create a proposal successfully", async function () {
      const tx = await dao.connect(proposer).createProposal(
        ProposalType.CourseApproval,
        "New AI Course",
        "Proposal to add new AI fundamentals course",
        "QmContentHash"
      );

      await expect(tx)
        .to.emit(dao, "ProposalCreated");

      expect(await dao.totalProposals()).to.equal(1);

      const proposal = await dao.getProposal(1);
      expect(proposal.title).to.equal("New AI Course");
      expect(proposal.proposalType).to.equal(ProposalType.CourseApproval);
      expect(proposal.state).to.equal(ProposalState.Active);
    });

    it("Should reject proposal without title", async function () {
      await expect(
        dao.connect(proposer).createProposal(
          ProposalType.CourseApproval,
          "",
          "Description",
          "QmHash"
        )
      ).to.be.revertedWith("Title required");
    });

    it("Should reject proposal without proposer role", async function () {
      await expect(
        dao.connect(voter1).createProposal(
          ProposalType.CourseApproval,
          "Test",
          "Description",
          "QmHash"
        )
      ).to.be.reverted;
    });
  });

  describe("Voting", function () {
    beforeEach(async function () {
      await dao.connect(proposer).createProposal(
        ProposalType.CourseApproval,
        "Test Proposal",
        "Test description",
        "QmHash"
      );
    });

    it("Should cast vote successfully", async function () {
      await expect(dao.connect(voter1).castVote(1, 1)) // Vote FOR
        .to.emit(dao, "VoteCast")
        .withArgs(1, voter1.address, 1, 1);

      const proposal = await dao.getProposal(1);
      expect(proposal.forVotes).to.equal(1);
    });

    it("Should track different vote types", async function () {
      await dao.connect(voter1).castVote(1, 1); // FOR
      await dao.connect(voter2).castVote(1, 0); // AGAINST
      await dao.connect(voter3).castVote(1, 2); // ABSTAIN

      const proposal = await dao.getProposal(1);
      expect(proposal.forVotes).to.equal(1);
      expect(proposal.againstVotes).to.equal(1);
      expect(proposal.abstainVotes).to.equal(1);
    });

    it("Should not allow double voting", async function () {
      await dao.connect(voter1).castVote(1, 1);
      
      await expect(dao.connect(voter1).castVote(1, 0))
        .to.be.revertedWith("Already voted");
    });

    it("Should check voting activity", async function () {
      expect(await dao.isVotingActive(1)).to.be.true;
    });
  });

  describe("Proposal Finalization", function () {
    beforeEach(async function () {
      await dao.connect(proposer).createProposal(
        ProposalType.CourseApproval,
        "Test Proposal",
        "Test description",
        "QmHash"
      );
    });

    it("Should succeed proposal with quorum and majority", async function () {
      // Vote FOR (need > 30% quorum of 4 voters = 2 votes minimum)
      await dao.connect(owner).castVote(1, 1);
      await dao.connect(voter1).castVote(1, 1);

      // Mine blocks to end voting period
      await mine(21601);

      await dao.finalizeProposal(1);

      const proposal = await dao.getProposal(1);
      expect(proposal.state).to.equal(ProposalState.Succeeded);
    });

    it("Should defeat proposal without majority", async function () {
      await dao.connect(owner).castVote(1, 0); // AGAINST
      await dao.connect(voter1).castVote(1, 0); // AGAINST

      await mine(21601);

      await dao.finalizeProposal(1);

      const proposal = await dao.getProposal(1);
      expect(proposal.state).to.equal(ProposalState.Defeated);
    });
  });

  describe("Proposal Execution", function () {
    beforeEach(async function () {
      await dao.connect(proposer).createProposal(
        ProposalType.CourseApproval,
        "Test Proposal",
        "Test description",
        "QmHash"
      );

      await dao.connect(owner).castVote(1, 1);
      await dao.connect(voter1).castVote(1, 1);
      
      await mine(21601);
      await dao.finalizeProposal(1);
    });

    it("Should execute succeeded proposal", async function () {
      await expect(dao.connect(validator).executeProposal(1))
        .to.emit(dao, "ProposalExecuted")
        .withArgs(1);

      const proposal = await dao.getProposal(1);
      expect(proposal.state).to.equal(ProposalState.Executed);
      expect(proposal.executed).to.be.true;
    });

    it("Should not execute twice", async function () {
      await dao.connect(validator).executeProposal(1);
      
      await expect(dao.connect(validator).executeProposal(1))
        .to.be.revertedWith("Proposal not succeeded");
    });
  });

  describe("Proposal Cancellation", function () {
    beforeEach(async function () {
      await dao.connect(proposer).createProposal(
        ProposalType.CourseApproval,
        "Test Proposal",
        "Test description",
        "QmHash"
      );
    });

    it("Should allow proposer to cancel", async function () {
      await expect(dao.connect(proposer).cancelProposal(1))
        .to.emit(dao, "ProposalCancelled")
        .withArgs(1);

      const proposal = await dao.getProposal(1);
      expect(proposal.state).to.equal(ProposalState.Cancelled);
    });

    it("Should allow admin to cancel", async function () {
      await expect(dao.connect(owner).cancelProposal(1))
        .to.emit(dao, "ProposalCancelled")
        .withArgs(1);
    });
  });

  describe("Proposal Type Names", function () {
    it("Should return correct type names", async function () {
      expect(await dao.getProposalTypeName(ProposalType.CourseApproval)).to.equal("Course Approval");
      expect(await dao.getProposalTypeName(ProposalType.ContentUpdate)).to.equal("Content Update");
      expect(await dao.getProposalTypeName(ProposalType.QualityReview)).to.equal("Quality Review");
      expect(await dao.getProposalTypeName(ProposalType.LanguageAddition)).to.equal("Language Addition");
      expect(await dao.getProposalTypeName(ProposalType.GovernanceChange)).to.equal("Governance Change");
      expect(await dao.getProposalTypeName(ProposalType.ValidatorAddition)).to.equal("Validator Addition");
      expect(await dao.getProposalTypeName(ProposalType.CurriculumUpdate)).to.equal("Curriculum Update");
    });
  });
});
