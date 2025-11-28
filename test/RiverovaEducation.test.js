const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RiverovaEducation", function () {
  let education;
  let owner;
  let instructor;
  let learner1;
  let learner2;
  let admin;

  beforeEach(async function () {
    [owner, instructor, learner1, learner2, admin] = await ethers.getSigners();

    const RiverovaEducation = await ethers.getContractFactory("RiverovaEducation");
    education = await RiverovaEducation.deploy(owner.address);
    await education.waitForDeployment();

    // Grant instructor role
    const INSTRUCTOR_ROLE = await education.INSTRUCTOR_ROLE();
    await education.grantRole(INSTRUCTOR_ROLE, instructor.address);
  });

  describe("Deployment", function () {
    it("Should set the correct admin", async function () {
      const DEFAULT_ADMIN_ROLE = await education.DEFAULT_ADMIN_ROLE();
      expect(await education.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
    });
  });

  describe("Course Management", function () {
    it("Should create a course successfully", async function () {
      const tx = await education.connect(instructor).createCourse(
        "Blockchain Basics",
        "Learn the fundamentals of blockchain technology",
        ["en", "es", "fr"],
        0, // requiredLevel
        4, // maxLevel (Expert)
        "QmCourseContent"
      );

      await expect(tx)
        .to.emit(education, "CourseCreated")
        .withArgs(1, "Blockchain Basics", instructor.address);

      expect(await education.totalCourses()).to.equal(1);

      const course = await education.getCourse(1);
      expect(course.name).to.equal("Blockchain Basics");
      expect(course.requiredLevel).to.equal(0);
      expect(course.maxLevel).to.equal(4);
      expect(course.isActive).to.be.true;
    });

    it("Should update course content", async function () {
      await education.connect(instructor).createCourse(
        "Test Course",
        "Original description",
        ["en"],
        0,
        3,
        "QmOriginal"
      );

      await expect(education.connect(instructor).updateCourse(
        1,
        "Updated description",
        "QmUpdated"
      )).to.emit(education, "CourseUpdated").withArgs(1);

      const course = await education.getCourse(1);
      expect(course.description).to.equal("Updated description");
      expect(course.contentHash).to.equal("QmUpdated");
    });

    it("Should deactivate a course", async function () {
      await education.connect(instructor).createCourse(
        "Test Course",
        "Description",
        ["en"],
        0,
        3,
        "QmHash"
      );

      await expect(education.connect(instructor).deactivateCourse(1))
        .to.emit(education, "CourseDeactivated").withArgs(1);

      const course = await education.getCourse(1);
      expect(course.isActive).to.be.false;
    });
  });

  describe("Learner Registration", function () {
    it("Should register a learner", async function () {
      await expect(education.connect(learner1).registerLearner("en"))
        .to.emit(education, "LearnerRegistered")
        .withArgs(learner1.address, "en");

      const learner = await education.getLearner(learner1.address);
      expect(learner.account).to.equal(learner1.address);
      expect(learner.preferredLanguage).to.equal("en");
      expect(learner.currentLevel).to.equal(0);
      expect(learner.isActive).to.be.true;
    });

    it("Should not allow duplicate registration", async function () {
      await education.connect(learner1).registerLearner("en");

      await expect(education.connect(learner1).registerLearner("es"))
        .to.be.revertedWith("Already registered");
    });

    it("Should reject invalid language code", async function () {
      await expect(education.connect(learner1).registerLearner("english"))
        .to.be.revertedWith("Invalid language code");
    });
  });

  describe("Course Enrollment", function () {
    beforeEach(async function () {
      await education.connect(instructor).createCourse(
        "Web3 Development",
        "Learn to build Web3 apps",
        ["en"],
        0,
        5,
        "QmHash"
      );
      await education.connect(learner1).registerLearner("en");
    });

    it("Should enroll in a course", async function () {
      await expect(education.connect(learner1).enrollInCourse(1))
        .to.emit(education, "LearnerEnrolled")
        .withArgs(learner1.address, 1);

      const enrollment = await education.getEnrollment(learner1.address, 1);
      expect(enrollment.courseId).to.equal(1);
      expect(enrollment.progress).to.equal(0);
      expect(enrollment.completed).to.be.false;
    });

    it("Should not allow duplicate enrollment", async function () {
      await education.connect(learner1).enrollInCourse(1);

      await expect(education.connect(learner1).enrollInCourse(1))
        .to.be.revertedWith("Already enrolled");
    });

    it("Should not enroll unregistered learners", async function () {
      await expect(education.connect(learner2).enrollInCourse(1))
        .to.be.revertedWith("Not a registered learner");
    });
  });

  describe("Progress and Completion", function () {
    beforeEach(async function () {
      await education.connect(instructor).createCourse(
        "Smart Contract Security",
        "Learn secure coding practices",
        ["en"],
        0,
        7, // maxLevel: Visionary
        "QmHash"
      );
      await education.connect(learner1).registerLearner("en");
      await education.connect(learner1).enrollInCourse(1);
    });

    it("Should update progress", async function () {
      await expect(education.connect(instructor).updateProgress(
        learner1.address,
        1,
        50
      )).to.emit(education, "ProgressUpdated")
        .withArgs(learner1.address, 1, 50);

      const enrollment = await education.getEnrollment(learner1.address, 1);
      expect(enrollment.progress).to.equal(50);
    });

    it("Should complete course and earn achievement", async function () {
      const tx = await education.connect(instructor).completeCourse(
        learner1.address,
        1,
        95, // Score of 95% = Visionary level
        "QmAchievementHash"
      );

      await expect(tx)
        .to.emit(education, "CourseCompleted")
        .withArgs(learner1.address, 1);

      await expect(tx)
        .to.emit(education, "AchievementEarned");

      const achievement = await education.getAchievement(1);
      expect(achievement.learner).to.equal(learner1.address);
      expect(achievement.score).to.equal(95);
      expect(achievement.level).to.equal(7); // Visionary

      const learner = await education.getLearner(learner1.address);
      expect(learner.currentLevel).to.equal(7);
      expect(learner.totalAchievements).to.equal(1);
    });

    it("Should calculate correct levels based on score", async function () {
      // Create multiple courses for testing
      await education.connect(instructor).createCourse("Course 2", "Desc", ["en"], 0, 7, "QmHash2");
      await education.connect(instructor).createCourse("Course 3", "Desc", ["en"], 0, 7, "QmHash3");
      
      await education.connect(learner2).registerLearner("es");
      await education.connect(learner2).enrollInCourse(2);
      
      // 75% score should give Specialist (level 3) - score range 70-79%
      await education.connect(instructor).completeCourse(
        learner2.address,
        2,
        75,
        "QmHash"
      );

      // This is the first achievement in this test (achievementId=1)
      const achievement = await education.getAchievement(1);
      expect(achievement.level).to.equal(3); // Specialist

      const learner = await education.getLearner(learner2.address);
      expect(learner.currentLevel).to.equal(3);
    });
  });

  describe("View Functions", function () {
    beforeEach(async function () {
      await education.connect(instructor).createCourse(
        "Test Course",
        "Description",
        ["en", "es"],
        0,
        5,
        "QmHash"
      );
      await education.connect(learner1).registerLearner("en");
      await education.connect(learner1).enrollInCourse(1);
      await education.connect(instructor).completeCourse(
        learner1.address,
        1,
        85,
        "QmAchievement"
      );
    });

    it("Should get learner achievements", async function () {
      const achievements = await education.getLearnerAchievements(learner1.address);
      expect(achievements.length).to.equal(1);
      expect(achievements[0]).to.equal(1);
    });

    it("Should get total achievements count", async function () {
      expect(await education.totalAchievements()).to.equal(1);
    });
  });

  describe("Level Names", function () {
    it("Should return correct level names", async function () {
      expect(await education.getLevelName(0)).to.equal("Novice");
      expect(await education.getLevelName(1)).to.equal("Apprentice");
      expect(await education.getLevelName(2)).to.equal("Practitioner");
      expect(await education.getLevelName(3)).to.equal("Specialist");
      expect(await education.getLevelName(4)).to.equal("Expert");
      expect(await education.getLevelName(5)).to.equal("Master");
      expect(await education.getLevelName(6)).to.equal("Authority");
      expect(await education.getLevelName(7)).to.equal("Visionary");
    });
  });

  describe("Contract References", function () {
    it("Should set certificate contract", async function () {
      const ADMIN_ROLE = await education.ADMIN_ROLE();
      await education.grantRole(ADMIN_ROLE, admin.address);

      const fakeAddress = "0x1234567890123456789012345678901234567890";
      await expect(education.connect(admin).setCertificateContract(fakeAddress))
        .to.emit(education, "CertificateContractSet")
        .withArgs(fakeAddress);

      expect(await education.certificateContract()).to.equal(fakeAddress);
    });

    it("Should set DAO contract", async function () {
      const ADMIN_ROLE = await education.ADMIN_ROLE();
      await education.grantRole(ADMIN_ROLE, admin.address);

      const fakeAddress = "0x1234567890123456789012345678901234567890";
      await expect(education.connect(admin).setDAOContract(fakeAddress))
        .to.emit(education, "DAOContractSet")
        .withArgs(fakeAddress);

      expect(await education.daoContract()).to.equal(fakeAddress);
    });
  });
});
