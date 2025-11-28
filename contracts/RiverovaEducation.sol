// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RiverovaEducation
 * @author Riverova Team
 * @notice Core education registry for managing courses, learners, and achievements
 * @dev Central registry for the Riverova decentralized education infrastructure
 */
contract RiverovaEducation is AccessControl, ReentrancyGuard {
    bytes32 public constant INSTRUCTOR_ROLE = keccak256("INSTRUCTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Course structure
    struct Course {
        uint256 id;
        string name;
        string description;
        string[] languages;          // Supported languages for this course
        uint256 requiredLevel;       // Minimum level required to enroll (0-7)
        uint256 maxLevel;            // Maximum certification level awarded (0-7)
        address instructor;
        uint256 enrolledCount;
        uint256 completedCount;
        bool isActive;
        uint256 createdAt;
        string contentHash;          // IPFS hash of course content
    }

    /// @notice Learner profile structure
    struct Learner {
        address account;
        string preferredLanguage;
        uint256 currentLevel;        // Current overall certification level (0-7)
        uint256[] enrolledCourses;
        uint256[] completedCourses;
        uint256 totalAchievements;
        uint256 registeredAt;
        bool isActive;
    }

    /// @notice Achievement structure
    struct Achievement {
        uint256 id;
        address learner;
        uint256 courseId;
        uint256 level;
        uint256 score;               // Score out of 100
        string achievementHash;      // Hash for certificate verification
        uint256 achievedAt;
        bool certified;              // Whether NFT certificate has been issued
    }

    /// @notice Enrollment structure
    struct Enrollment {
        uint256 courseId;
        address learner;
        uint256 enrolledAt;
        uint256 progress;            // Progress percentage (0-100)
        bool completed;
    }

    /// @notice Counters
    uint256 private _courseIdCounter;
    uint256 private _achievementIdCounter;

    /// @notice Storage mappings
    mapping(uint256 => Course) public courses;
    mapping(address => Learner) public learners;
    mapping(uint256 => Achievement) public achievements;
    mapping(address => mapping(uint256 => Enrollment)) public enrollments;
    mapping(address => uint256[]) public learnerAchievements;

    /// @notice Certificate contract reference
    address public certificateContract;

    /// @notice DAO contract reference
    address public daoContract;

    /// @notice Events
    event CourseCreated(uint256 indexed courseId, string name, address indexed instructor);
    event CourseUpdated(uint256 indexed courseId);
    event CourseDeactivated(uint256 indexed courseId);
    event LearnerRegistered(address indexed learner, string preferredLanguage);
    event LearnerEnrolled(address indexed learner, uint256 indexed courseId);
    event ProgressUpdated(address indexed learner, uint256 indexed courseId, uint256 progress);
    event CourseCompleted(address indexed learner, uint256 indexed courseId);
    event AchievementEarned(uint256 indexed achievementId, address indexed learner, uint256 indexed courseId, uint256 level);
    event CertificateContractSet(address indexed contractAddress);
    event DAOContractSet(address indexed contractAddress);

    /**
     * @notice Constructor initializes the education registry
     * @param defaultAdmin Address of the default admin
     */
    constructor(address defaultAdmin) {
        require(defaultAdmin != address(0), "Invalid admin address");

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
        _grantRole(INSTRUCTOR_ROLE, defaultAdmin);
    }

    /**
     * @notice Set the certificate contract address
     * @param _certificateContract Address of the RiverovaCertificate contract
     */
    function setCertificateContract(address _certificateContract) external onlyRole(ADMIN_ROLE) {
        require(_certificateContract != address(0), "Invalid address");
        certificateContract = _certificateContract;
        emit CertificateContractSet(_certificateContract);
    }

    /**
     * @notice Set the DAO contract address
     * @param _daoContract Address of the RiverovaDAO contract
     */
    function setDAOContract(address _daoContract) external onlyRole(ADMIN_ROLE) {
        require(_daoContract != address(0), "Invalid address");
        daoContract = _daoContract;
        emit DAOContractSet(_daoContract);
    }

    /**
     * @notice Create a new course
     * @param name Course name
     * @param description Course description
     * @param languages Supported languages
     * @param requiredLevel Minimum level required
     * @param maxLevel Maximum certification level
     * @param contentHash IPFS hash of course content
     * @return courseId The ID of the created course
     */
    function createCourse(
        string calldata name,
        string calldata description,
        string[] calldata languages,
        uint256 requiredLevel,
        uint256 maxLevel,
        string calldata contentHash
    ) external onlyRole(INSTRUCTOR_ROLE) returns (uint256) {
        require(bytes(name).length > 0, "Name required");
        require(languages.length > 0, "At least one language required");
        require(requiredLevel <= 7, "Invalid required level");
        require(maxLevel <= 7, "Invalid max level");
        require(maxLevel >= requiredLevel, "Max level must be >= required level");

        uint256 courseId = ++_courseIdCounter;

        courses[courseId] = Course({
            id: courseId,
            name: name,
            description: description,
            languages: languages,
            requiredLevel: requiredLevel,
            maxLevel: maxLevel,
            instructor: msg.sender,
            enrolledCount: 0,
            completedCount: 0,
            isActive: true,
            createdAt: block.timestamp,
            contentHash: contentHash
        });

        emit CourseCreated(courseId, name, msg.sender);

        return courseId;
    }

    /**
     * @notice Update course content
     * @param courseId Course ID
     * @param description New description
     * @param contentHash New content hash
     */
    function updateCourse(
        uint256 courseId,
        string calldata description,
        string calldata contentHash
    ) external {
        Course storage course = courses[courseId];
        require(course.id != 0, "Course does not exist");
        require(
            msg.sender == course.instructor || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );

        course.description = description;
        course.contentHash = contentHash;

        emit CourseUpdated(courseId);
    }

    /**
     * @notice Deactivate a course
     * @param courseId Course ID
     */
    function deactivateCourse(uint256 courseId) external {
        Course storage course = courses[courseId];
        require(course.id != 0, "Course does not exist");
        require(
            msg.sender == course.instructor || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );

        course.isActive = false;
        emit CourseDeactivated(courseId);
    }

    /**
     * @notice Register as a learner
     * @param preferredLanguage Preferred language code
     */
    function registerLearner(string calldata preferredLanguage) external {
        require(learners[msg.sender].account == address(0), "Already registered");
        require(bytes(preferredLanguage).length == 2, "Invalid language code");

        learners[msg.sender] = Learner({
            account: msg.sender,
            preferredLanguage: preferredLanguage,
            currentLevel: 0,
            enrolledCourses: new uint256[](0),
            completedCourses: new uint256[](0),
            totalAchievements: 0,
            registeredAt: block.timestamp,
            isActive: true
        });

        emit LearnerRegistered(msg.sender, preferredLanguage);
    }

    /**
     * @notice Enroll in a course
     * @param courseId Course ID to enroll in
     */
    function enrollInCourse(uint256 courseId) external {
        require(learners[msg.sender].isActive, "Not a registered learner");
        
        Course storage course = courses[courseId];
        require(course.id != 0, "Course does not exist");
        require(course.isActive, "Course not active");
        require(learners[msg.sender].currentLevel >= course.requiredLevel, "Level too low");
        
        Enrollment storage enrollment = enrollments[msg.sender][courseId];
        require(enrollment.enrolledAt == 0, "Already enrolled");

        enrollment.courseId = courseId;
        enrollment.learner = msg.sender;
        enrollment.enrolledAt = block.timestamp;
        enrollment.progress = 0;
        enrollment.completed = false;

        learners[msg.sender].enrolledCourses.push(courseId);
        course.enrolledCount++;

        emit LearnerEnrolled(msg.sender, courseId);
    }

    /**
     * @notice Update learner progress in a course (by instructor)
     * @param learner Learner address
     * @param courseId Course ID
     * @param progress Progress percentage (0-100)
     */
    function updateProgress(
        address learner,
        uint256 courseId,
        uint256 progress
    ) external onlyRole(INSTRUCTOR_ROLE) {
        require(progress <= 100, "Invalid progress value");
        
        Enrollment storage enrollment = enrollments[learner][courseId];
        require(enrollment.enrolledAt != 0, "Not enrolled");
        require(!enrollment.completed, "Already completed");

        enrollment.progress = progress;
        emit ProgressUpdated(learner, courseId, progress);
    }

    /**
     * @notice Complete a course and earn achievement
     * @param learner Learner address
     * @param courseId Course ID
     * @param score Score achieved (0-100)
     * @param achievementHash Hash for certificate verification
     */
    function completeCourse(
        address learner,
        uint256 courseId,
        uint256 score,
        string calldata achievementHash
    ) external onlyRole(INSTRUCTOR_ROLE) nonReentrant {
        require(score <= 100, "Invalid score");
        
        Enrollment storage enrollment = enrollments[learner][courseId];
        require(enrollment.enrolledAt != 0, "Not enrolled");
        require(!enrollment.completed, "Already completed");

        Course storage course = courses[courseId];
        
        enrollment.completed = true;
        enrollment.progress = 100;

        // Calculate achievement level based on score
        uint256 achievedLevel = _calculateLevel(score, course.maxLevel);

        uint256 achievementId = ++_achievementIdCounter;

        achievements[achievementId] = Achievement({
            id: achievementId,
            learner: learner,
            courseId: courseId,
            level: achievedLevel,
            score: score,
            achievementHash: achievementHash,
            achievedAt: block.timestamp,
            certified: false
        });

        learnerAchievements[learner].push(achievementId);
        learners[learner].completedCourses.push(courseId);
        learners[learner].totalAchievements++;
        
        // Update learner's overall level if new achievement is higher
        if (achievedLevel > learners[learner].currentLevel) {
            learners[learner].currentLevel = achievedLevel;
        }

        course.completedCount++;

        emit CourseCompleted(learner, courseId);
        emit AchievementEarned(achievementId, learner, courseId, achievedLevel);
    }

    /**
     * @notice Mark achievement as certified (after NFT is minted)
     * @param achievementId Achievement ID
     */
    function markAsCertified(uint256 achievementId) external onlyRole(ADMIN_ROLE) {
        require(achievements[achievementId].id != 0, "Achievement does not exist");
        achievements[achievementId].certified = true;
    }

    /**
     * @notice Calculate certification level based on score
     * @param score Score achieved
     * @param maxLevel Maximum level for the course
     * @return Calculated level (0-7)
     */
    function _calculateLevel(uint256 score, uint256 maxLevel) private pure returns (uint256) {
        if (score < 50) return 0;      // Below 50%: Novice
        if (score < 60) return maxLevel > 1 ? 1 : maxLevel;  // 50-59%: Apprentice
        if (score < 70) return maxLevel > 2 ? 2 : maxLevel;  // 60-69%: Practitioner
        if (score < 80) return maxLevel > 3 ? 3 : maxLevel;  // 70-79%: Specialist
        if (score < 85) return maxLevel > 4 ? 4 : maxLevel;  // 80-84%: Expert
        if (score < 90) return maxLevel > 5 ? 5 : maxLevel;  // 85-89%: Master
        if (score < 95) return maxLevel > 6 ? 6 : maxLevel;  // 90-94%: Authority
        return maxLevel;                                      // 95-100%: Visionary (max level)
    }

    // ===== View Functions =====

    /**
     * @notice Get course details
     * @param courseId Course ID
     * @return Course data
     */
    function getCourse(uint256 courseId) external view returns (Course memory) {
        require(courses[courseId].id != 0, "Course does not exist");
        return courses[courseId];
    }

    /**
     * @notice Get learner profile
     * @param learner Learner address
     * @return Learner data
     */
    function getLearner(address learner) external view returns (Learner memory) {
        require(learners[learner].account != address(0), "Learner not registered");
        return learners[learner];
    }

    /**
     * @notice Get achievement details
     * @param achievementId Achievement ID
     * @return Achievement data
     */
    function getAchievement(uint256 achievementId) external view returns (Achievement memory) {
        require(achievements[achievementId].id != 0, "Achievement does not exist");
        return achievements[achievementId];
    }

    /**
     * @notice Get enrollment status
     * @param learner Learner address
     * @param courseId Course ID
     * @return Enrollment data
     */
    function getEnrollment(address learner, uint256 courseId) external view returns (Enrollment memory) {
        return enrollments[learner][courseId];
    }

    /**
     * @notice Get all achievements for a learner
     * @param learner Learner address
     * @return Array of achievement IDs
     */
    function getLearnerAchievements(address learner) external view returns (uint256[] memory) {
        return learnerAchievements[learner];
    }

    /**
     * @notice Get total number of courses
     * @return Total count
     */
    function totalCourses() external view returns (uint256) {
        return _courseIdCounter;
    }

    /**
     * @notice Get total number of achievements
     * @return Total count
     */
    function totalAchievements() external view returns (uint256) {
        return _achievementIdCounter;
    }

    /**
     * @notice Get level name
     * @param level Level number (0-7)
     * @return Level name
     */
    function getLevelName(uint256 level) external pure returns (string memory) {
        if (level == 0) return "Novice";
        if (level == 1) return "Apprentice";
        if (level == 2) return "Practitioner";
        if (level == 3) return "Specialist";
        if (level == 4) return "Expert";
        if (level == 5) return "Master";
        if (level == 6) return "Authority";
        if (level == 7) return "Visionary";
        revert("Invalid level");
    }
}
