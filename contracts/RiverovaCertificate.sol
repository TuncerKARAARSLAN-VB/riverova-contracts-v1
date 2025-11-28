// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RiverovaCertificate
 * @author Riverova Team
 * @notice Immutable 8-level NFT certificates for educational achievements
 * @dev ERC721-based certificate system with 8 certification levels and multi-language support
 */
contract RiverovaCertificate is ERC721, ERC721URIStorage, ERC721Enumerable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    /// @notice Maximum certification level (1-8)
    uint8 public constant MAX_LEVEL = 8;

    /// @notice Counter for token IDs
    uint256 private _tokenIdCounter;

    /// @notice Enum representing the 8 certification levels
    enum CertificationLevel {
        Novice,       // Level 1: Beginner
        Apprentice,   // Level 2: Basic understanding
        Practitioner, // Level 3: Practical skills
        Specialist,   // Level 4: Specialized knowledge
        Expert,       // Level 5: Expert level
        Master,       // Level 6: Master level
        Authority,    // Level 7: Authority in the field
        Visionary     // Level 8: Highest level - Visionary
    }

    /// @notice Certificate data structure
    struct Certificate {
        uint256 tokenId;
        address recipient;
        string courseName;
        string languageCode;       // ISO 639-1 language code (e.g., "en", "es", "fr")
        CertificationLevel level;
        uint256 issuedAt;
        string achievementHash;    // Hash of achievement data for verification
        bool validated;            // DAO validation status
    }

    /// @notice Mapping from token ID to certificate data
    mapping(uint256 => Certificate) public certificates;

    /// @notice Mapping from recipient to their certificate IDs
    mapping(address => uint256[]) public recipientCertificates;

    /// @notice Supported languages (20+ languages)
    mapping(string => bool) public supportedLanguages;

    /// @notice Events
    event CertificateMinted(
        uint256 indexed tokenId,
        address indexed recipient,
        string courseName,
        CertificationLevel level,
        string languageCode
    );
    event CertificateValidated(uint256 indexed tokenId, address indexed validator);
    event LanguageAdded(string languageCode);
    event LanguageRemoved(string languageCode);

    /**
     * @notice Constructor initializes the contract with default supported languages
     * @param defaultAdmin Address of the default admin
     */
    constructor(address defaultAdmin) ERC721("Riverova Certificate", "RVRC") {
        require(defaultAdmin != address(0), "Invalid admin address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(DAO_ROLE, defaultAdmin);

        // Initialize 20+ supported languages
        _initializeSupportedLanguages();
    }

    /**
     * @notice Initialize supported languages (20+ languages)
     */
    function _initializeSupportedLanguages() private {
        // Major world languages
        supportedLanguages["en"] = true; // English
        supportedLanguages["es"] = true; // Spanish
        supportedLanguages["fr"] = true; // French
        supportedLanguages["de"] = true; // German
        supportedLanguages["it"] = true; // Italian
        supportedLanguages["pt"] = true; // Portuguese
        supportedLanguages["ru"] = true; // Russian
        supportedLanguages["zh"] = true; // Chinese
        supportedLanguages["ja"] = true; // Japanese
        supportedLanguages["ko"] = true; // Korean
        supportedLanguages["ar"] = true; // Arabic
        supportedLanguages["hi"] = true; // Hindi
        supportedLanguages["bn"] = true; // Bengali
        supportedLanguages["tr"] = true; // Turkish
        supportedLanguages["vi"] = true; // Vietnamese
        supportedLanguages["th"] = true; // Thai
        supportedLanguages["id"] = true; // Indonesian
        supportedLanguages["nl"] = true; // Dutch
        supportedLanguages["pl"] = true; // Polish
        supportedLanguages["sv"] = true; // Swedish
        supportedLanguages["uk"] = true; // Ukrainian
        supportedLanguages["el"] = true; // Greek
    }

    /**
     * @notice Mint a new certificate NFT
     * @param recipient Address to receive the certificate
     * @param courseName Name of the course completed
     * @param languageCode ISO 639-1 language code
     * @param level Certification level (0-7 mapping to CertificationLevel enum)
     * @param achievementHash Hash of achievement data
     * @param metadataURI URI for the certificate metadata
     * @return tokenId The ID of the minted certificate
     */
    function mintCertificate(
        address recipient,
        string calldata courseName,
        string calldata languageCode,
        CertificationLevel level,
        string calldata achievementHash,
        string calldata metadataURI
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (uint256) {
        require(recipient != address(0), "Invalid recipient address");
        require(bytes(courseName).length > 0, "Course name required");
        require(supportedLanguages[languageCode], "Language not supported");
        require(bytes(achievementHash).length > 0, "Achievement hash required");

        uint256 tokenId = ++_tokenIdCounter;

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, metadataURI);

        certificates[tokenId] = Certificate({
            tokenId: tokenId,
            recipient: recipient,
            courseName: courseName,
            languageCode: languageCode,
            level: level,
            issuedAt: block.timestamp,
            achievementHash: achievementHash,
            validated: false
        });

        recipientCertificates[recipient].push(tokenId);

        emit CertificateMinted(tokenId, recipient, courseName, level, languageCode);

        return tokenId;
    }

    /**
     * @notice Validate a certificate (DAO governance)
     * @param tokenId The certificate token ID to validate
     */
    function validateCertificate(uint256 tokenId) external onlyRole(DAO_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Certificate does not exist");
        require(!certificates[tokenId].validated, "Already validated");

        certificates[tokenId].validated = true;
        emit CertificateValidated(tokenId, msg.sender);
    }

    /**
     * @notice Add a new supported language
     * @param languageCode ISO 639-1 language code
     */
    function addLanguage(string calldata languageCode) external onlyRole(DAO_ROLE) {
        require(bytes(languageCode).length == 2, "Invalid language code");
        require(!supportedLanguages[languageCode], "Language already supported");

        supportedLanguages[languageCode] = true;
        emit LanguageAdded(languageCode);
    }

    /**
     * @notice Remove a supported language
     * @param languageCode ISO 639-1 language code
     */
    function removeLanguage(string calldata languageCode) external onlyRole(DAO_ROLE) {
        require(supportedLanguages[languageCode], "Language not supported");

        supportedLanguages[languageCode] = false;
        emit LanguageRemoved(languageCode);
    }

    /**
     * @notice Get all certificates for a recipient
     * @param recipient Address of the certificate holder
     * @return Array of certificate token IDs
     */
    function getCertificatesByRecipient(address recipient) external view returns (uint256[] memory) {
        return recipientCertificates[recipient];
    }

    /**
     * @notice Get certificate details
     * @param tokenId The certificate token ID
     * @return Certificate data
     */
    function getCertificate(uint256 tokenId) external view returns (Certificate memory) {
        require(_ownerOf(tokenId) != address(0), "Certificate does not exist");
        return certificates[tokenId];
    }

    /**
     * @notice Check if a language is supported
     * @param languageCode ISO 639-1 language code
     * @return true if supported
     */
    function isLanguageSupported(string calldata languageCode) external view returns (bool) {
        return supportedLanguages[languageCode];
    }

    /**
     * @notice Get the total number of certificates minted
     * @return Total count
     */
    function totalCertificates() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @notice Get the level name as a string
     * @param level The certification level
     * @return Level name
     */
    function getLevelName(CertificationLevel level) external pure returns (string memory) {
        if (level == CertificationLevel.Novice) return "Novice";
        if (level == CertificationLevel.Apprentice) return "Apprentice";
        if (level == CertificationLevel.Practitioner) return "Practitioner";
        if (level == CertificationLevel.Specialist) return "Specialist";
        if (level == CertificationLevel.Expert) return "Expert";
        if (level == CertificationLevel.Master) return "Master";
        if (level == CertificationLevel.Authority) return "Authority";
        if (level == CertificationLevel.Visionary) return "Visionary";
        revert("Invalid level");
    }

    // ===== Required Overrides =====

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
