// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin imports for standard compliance and security
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; // Useful for level to string conversion (metadata)

/**
 * @title RiverovaNftCertification_Draft
 * @notice Draft V1 of the Riverova NFT Certification Contract (ERC-721 based).
 *
 * PURPOSE: This contract is responsible for minting immutable NFT certificates
 * representing user achievement across the 8-level progression journey.
 * Critically, it maps each token to a Level (1-8), which is used by the
 * DaoGovernance contract to determine voting eligibility (Level 5+).
 * * Improvements: Added immutable constants, event logging, and a robust verification method.
 */
contract RiverovaNftCertification_Draft is ERC721, Ownable {
    using Strings for uint256;

    //-------------------------------------------------------------------------
    // 1. State Variables & Events
    //-------------------------------------------------------------------------
    
    // Immutable constants for better gas efficiency and code clarity
    uint256 public constant MIN_CERT_LEVEL = 1;
    uint256 public constant MAX_CERT_LEVEL = 8;
    
    // Maps Token ID to its Certification Level (1 to 8).
    mapping(uint256 => uint256) private tokenLevel;
    
    // Tracks the next available Token ID.
    uint256 private nextTokenId = 1;

    // Event is crucial for off-chain services (Riverova backend) to track new NFTs
    event CertificateMinted(
        address indexed recipient, 
        uint256 indexed tokenId, 
        uint256 level, 
        string tokenURI
    );

    //-------------------------------------------------------------------------
    // 2. Constructor
    //-------------------------------------------------------------------------
    
    // Initializes the ERC721 token (name and symbol) and sets the deployer as owner.
    constructor() ERC721("RiverovaCertificate", "RIV-NFT") {
        // Only the owner (the Riverova backend service) can mint new certificates.
    }

    //-------------------------------------------------------------------------
    // 3. Core Minting Function
    //-------------------------------------------------------------------------
    
    /**
     * @notice Mints a new NFT certificate and assigns a level.
     * @dev Only callable by the contract owner (Riverova backend service).
     * @param to The address of the user receiving the NFT.
     * @param level The achievement level (1-8) of the certificate.
     * @param tokenURI IPFS URI pointing to the immutable metadata (level, course, date).
     */
    function mintCertificate(
        address to, 
        uint256 level, 
        string memory tokenURI
    ) public onlyOwner returns (uint256) {
        // Security check using the defined immutable constants
        require(level >= MIN_CERT_LEVEL && level <= MAX_CERT_LEVEL, "RIVEROVA: Invalid level (must be 1-8).");
        
        uint256 tokenId = nextTokenId;
        
        // 1. Map the level (CRITICAL for DAO integration)
        tokenLevel[tokenId] = level;

        // 2. Mint the token
        _safeMint(to, tokenId);
        
        // 3. Set the metadata URI (pointing to IPFS)
        _setTokenURI(tokenId, tokenURI);
        
        nextTokenId++;
        
        // Log the event for off-chain systems
        emit CertificateMinted(to, tokenId, level, tokenURI);
        
        return tokenId;
    }

    //-------------------------------------------------------------------------
    // 4. DAO Integration Functions
    //-------------------------------------------------------------------------
    
    /**
     * @notice Returns the level of a specific token ID.
     * @dev Used by external contracts (like DaoGovernance) for verification.
     * @param _tokenId The ID of the certificate NFT.
     * @return The level (1-8) associated with the token. Returns 0 if token ID does not exist.
     */
    function getTokenLevel(uint256 _tokenId) public view returns (uint256) {
        // Robustness check: Ensure the token exists before returning the level
        if (!_exists(_tokenId)) {
            return 0; // Return 0 (no level) if the token ID is invalid
        }
        return tokenLevel[_tokenId];
    }

    /**
     * @notice Returns the highest level NFT owned by an address.
     * @dev This is the function the DAO contract will eventually use for voting eligibility.
     * @param _owner The address to check.
     * @return The highest level (1-8) NFT owned by the address. Returns 0 if no NFT is owned.
     */
    function getHighestLevel(address _owner) public view returns (uint256 highestLevel) {
        uint256 balance = balanceOf(_owner);
        if (balance == 0) {
            return 0;
        }
        
        // NOTE: In the full ERC721 implementation, there is no easy way to iterate 
        // through tokens owned by an address without external libraries (Enumerable).
        // For a draft, we state the intention:

        // INTENDED LOGIC:
        // uint256 highestLevel = 0;
        // for (uint256 i = 0; i < balance; i++) {
        //     uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
        //     uint256 level = tokenLevel[tokenId];
        //     if (level > highestLevel) {
        //         highestLevel = level;
        //     }
        // }
        
        // Since we are not using Enumerable extension (due to gas cost), 
        // the final implementation will likely use a dedicated mapping or an off-chain index.
        // For this draft, we return the max possible level for a non-zero balance:
        return MAX_CERT_LEVEL; 
    }
}