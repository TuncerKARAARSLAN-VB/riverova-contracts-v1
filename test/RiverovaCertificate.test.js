const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RiverovaCertificate", function () {
  let certificate;
  let owner;
  let minter;
  let recipient;
  let daoMember;

  const CertificationLevel = {
    Novice: 0,
    Apprentice: 1,
    Practitioner: 2,
    Specialist: 3,
    Expert: 4,
    Master: 5,
    Authority: 6,
    Visionary: 7
  };

  beforeEach(async function () {
    [owner, minter, recipient, daoMember] = await ethers.getSigners();

    const RiverovaCertificate = await ethers.getContractFactory("RiverovaCertificate");
    certificate = await RiverovaCertificate.deploy(owner.address);
    await certificate.waitForDeployment();

    // Grant minter role
    const MINTER_ROLE = await certificate.MINTER_ROLE();
    await certificate.grantRole(MINTER_ROLE, minter.address);
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await certificate.name()).to.equal("Riverova Certificate");
      expect(await certificate.symbol()).to.equal("RVRC");
    });

    it("Should grant admin role to deployer", async function () {
      const DEFAULT_ADMIN_ROLE = await certificate.DEFAULT_ADMIN_ROLE();
      expect(await certificate.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
    });

    it("Should initialize supported languages", async function () {
      expect(await certificate.isLanguageSupported("en")).to.be.true;
      expect(await certificate.isLanguageSupported("es")).to.be.true;
      expect(await certificate.isLanguageSupported("fr")).to.be.true;
      expect(await certificate.isLanguageSupported("zh")).to.be.true;
      expect(await certificate.isLanguageSupported("ar")).to.be.true;
    });
  });

  describe("Certificate Minting", function () {
    it("Should mint a certificate successfully", async function () {
      const tx = await certificate.connect(minter).mintCertificate(
        recipient.address,
        "Blockchain Fundamentals",
        "en",
        CertificationLevel.Expert,
        "QmHash123",
        "ipfs://metadata"
      );

      await expect(tx)
        .to.emit(certificate, "CertificateMinted")
        .withArgs(1, recipient.address, "Blockchain Fundamentals", CertificationLevel.Expert, "en");

      expect(await certificate.totalCertificates()).to.equal(1);
      expect(await certificate.ownerOf(1)).to.equal(recipient.address);
    });

    it("Should reject minting with unsupported language", async function () {
      await expect(
        certificate.connect(minter).mintCertificate(
          recipient.address,
          "Test Course",
          "xx", // Unsupported
          CertificationLevel.Novice,
          "QmHash",
          "ipfs://metadata"
        )
      ).to.be.revertedWith("Language not supported");
    });

    it("Should reject minting to zero address", async function () {
      await expect(
        certificate.connect(minter).mintCertificate(
          ethers.ZeroAddress,
          "Test Course",
          "en",
          CertificationLevel.Novice,
          "QmHash",
          "ipfs://metadata"
        )
      ).to.be.revertedWith("Invalid recipient address");
    });

    it("Should reject minting without minter role", async function () {
      await expect(
        certificate.connect(recipient).mintCertificate(
          recipient.address,
          "Test Course",
          "en",
          CertificationLevel.Novice,
          "QmHash",
          "ipfs://metadata"
        )
      ).to.be.reverted;
    });
  });

  describe("Certificate Data", function () {
    beforeEach(async function () {
      await certificate.connect(minter).mintCertificate(
        recipient.address,
        "Web3 Development",
        "es",
        CertificationLevel.Master,
        "QmAchievementHash",
        "ipfs://cert-metadata"
      );
    });

    it("Should return correct certificate data", async function () {
      const cert = await certificate.getCertificate(1);
      expect(cert.recipient).to.equal(recipient.address);
      expect(cert.courseName).to.equal("Web3 Development");
      expect(cert.languageCode).to.equal("es");
      expect(cert.level).to.equal(CertificationLevel.Master);
      expect(cert.achievementHash).to.equal("QmAchievementHash");
      expect(cert.validated).to.be.false;
    });

    it("Should return certificates by recipient", async function () {
      const certs = await certificate.getCertificatesByRecipient(recipient.address);
      expect(certs.length).to.equal(1);
      expect(certs[0]).to.equal(1);
    });
  });

  describe("DAO Validation", function () {
    beforeEach(async function () {
      await certificate.connect(minter).mintCertificate(
        recipient.address,
        "AI Fundamentals",
        "en",
        CertificationLevel.Specialist,
        "QmHash",
        "ipfs://metadata"
      );
    });

    it("Should validate certificate by DAO member", async function () {
      const DAO_ROLE = await certificate.DAO_ROLE();
      await certificate.grantRole(DAO_ROLE, daoMember.address);

      await expect(certificate.connect(daoMember).validateCertificate(1))
        .to.emit(certificate, "CertificateValidated")
        .withArgs(1, daoMember.address);

      const cert = await certificate.getCertificate(1);
      expect(cert.validated).to.be.true;
    });

    it("Should reject double validation", async function () {
      const DAO_ROLE = await certificate.DAO_ROLE();
      await certificate.grantRole(DAO_ROLE, daoMember.address);

      await certificate.connect(daoMember).validateCertificate(1);
      
      await expect(
        certificate.connect(daoMember).validateCertificate(1)
      ).to.be.revertedWith("Already validated");
    });
  });

  describe("Language Management", function () {
    it("Should add new language", async function () {
      const DAO_ROLE = await certificate.DAO_ROLE();
      await certificate.grantRole(DAO_ROLE, daoMember.address);

      await expect(certificate.connect(daoMember).addLanguage("sw"))
        .to.emit(certificate, "LanguageAdded")
        .withArgs("sw");

      expect(await certificate.isLanguageSupported("sw")).to.be.true;
    });

    it("Should remove language", async function () {
      const DAO_ROLE = await certificate.DAO_ROLE();
      await certificate.grantRole(DAO_ROLE, daoMember.address);

      await expect(certificate.connect(daoMember).removeLanguage("en"))
        .to.emit(certificate, "LanguageRemoved")
        .withArgs("en");

      expect(await certificate.isLanguageSupported("en")).to.be.false;
    });
  });

  describe("Level Names", function () {
    it("Should return correct level names", async function () {
      expect(await certificate.getLevelName(CertificationLevel.Novice)).to.equal("Novice");
      expect(await certificate.getLevelName(CertificationLevel.Apprentice)).to.equal("Apprentice");
      expect(await certificate.getLevelName(CertificationLevel.Practitioner)).to.equal("Practitioner");
      expect(await certificate.getLevelName(CertificationLevel.Specialist)).to.equal("Specialist");
      expect(await certificate.getLevelName(CertificationLevel.Expert)).to.equal("Expert");
      expect(await certificate.getLevelName(CertificationLevel.Master)).to.equal("Master");
      expect(await certificate.getLevelName(CertificationLevel.Authority)).to.equal("Authority");
      expect(await certificate.getLevelName(CertificationLevel.Visionary)).to.equal("Visionary");
    });
  });
});
