
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RiverovaDaoGovernance", function () {
    let NftCertification;
    let DaoGovernance;
    let nftCertification;
    let daoGovernance;
    let owner; // Simulates the Founder/Deployer/Initial Leader
    let addr1; // Simulates a regular user (Non-Leader)
    let addr2; // Simulates another address

    // Tüm testlerden önce kontratları dağıtma ve adresleri ayarlama
    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // 1. NFT Kontratını Dağıtma
        NftCertification = await ethers.getContractFactory("RiverovaNftCertification_Draft");
        nftCertification = await NftCertification.deploy();
        await nftCertification.deployed();

        // 2. DAO Kontratını Dağıtma (NFT Kontrat adresini parametre olarak geçerek)
        DaoGovernance = await ethers.getContractFactory("RiverovaDaoGovernance_Draft");
        daoGovernance = await DaoGovernance.deploy(nftCertification.address);
        await daoGovernance.deployed();
    });

    describe("Deployment & Initialization", function () {
        it("Should correctly set the NFT Certification address", async function () {
            // DAO kontratının, NFT kontrat adresini doğru kaydettiğini kontrol eder.
            expect(await daoGovernance.nftCertificationContractAddress()).to.equal(nftCertification.address);
        });
    });

    describe("Access Control (Community Leader Check)", function () {
        // NOTE: DaoGovernance_Draft.sol şu anda sadece deployer'ı (owner) Community Leader olarak kabul eder.
        // Bu testler, bu draft mantığını doğrular.

        it("Should allow the deployer (Owner) to create a proposal (simulating Level 5+ Leader)", async function () {
            // Kontratı dağıtan adresin (Founder), teklif oluşturma yetkisi olmalıdır.
            const description = "Approve new AI model for content generation.";
            await expect(daoGovernance.connect(owner).createProposal(description))
                .to.not.be.reverted;
            
            // Teklifin oluşturulduğunu kontrol et
            const proposal = await daoGovernance.proposals(1);
            expect(proposal.proposer).to.equal(owner.address);
            expect(proposal.description).to.equal(description);
        });

        it("Should NOT allow a regular address (addr1) to create a proposal", async function () {
            // Kontratı dağıtmayan adresin (Regular User) teklif oluşturmasına izin verilmemelidir.
            const description = "Request for a new DevOps course module.";
            await expect(daoGovernance.connect(addr1).createProposal(description))
                .to.be.revertedWith("RIVEROVA: Only Level 5+ Leaders can create proposals.");
        });
    });

    describe("Voting Mechanism", function () {
        
        beforeEach(async function () {
            // Test için önce bir teklif oluşturulur
            const description = "Implement token staking for Level 8 NFTs.";
            await daoGovernance.connect(owner).createProposal(description);
        });

        it("Should allow the Community Leader (Owner) to cast a vote", async function () {
            // Founder (Owner) teklif lehine oy kullanır.
            await daoGovernance.connect(owner).castVote(1, true);

            // Oyların doğru kaydedildiğini kontrol et
            const proposal = await daoGovernance.proposals(1);
            expect(proposal.forVotes).to.equal(1);
            expect(proposal.againstVotes).to.equal(0);
            
            // Kullanıcının oy kullandığı işaretlenmeli
            expect(await daoGovernance.hasVoted(1, owner.address)).to.be.true;
        });
        
        it("Should NOT allow the Community Leader to vote twice", async function () {
            // İlk oyu kullanır
            await daoGovernance.connect(owner).castVote(1, true);
            
            // İkinci kez oy kullanmayı dener ve hata alır
            await expect(daoGovernance.connect(owner).castVote(1, false))
                .to.be.revertedWith("RIVEROVA: Already voted on this proposal.");
        });

        it("Should NOT allow a non-leader (addr1) to cast a vote", async function () {
            // Normal bir kullanıcının oy kullanmasına izin verilmemelidir.
            await expect(daoGovernance.connect(addr1).castVote(1, true))
                .to.be.revertedWith("RIVEROVA: Only Level 5+ Leaders can vote.");
        });
    });
});