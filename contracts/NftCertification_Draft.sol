
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin imports for standard compliance and security
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RiverovaNftCertification_Draft
 * @notice Draft V1 of the Riverova NFT Certification Contract (ERC-721 based).
 *
 * PURPOSE: This contract is responsible for minting immutable NFT certificates
 * representing user achievement across the 8-level progression journey.
 * Critically, it maps each token to a Level (1-8), which is used by the
 * DaoGovernance contract to determine voting eligibility (Level 5+).
 * * Grant Note: This draft demonstrates the core functionality of verification and
 * level mapping for the DAO integration.
 */
contract RiverovaNftCertification_Draft is ERC721, Ownable {

    //-------------------------------------------------------------------------
    // 1. State Variables
    //-------------------------------------------------------------------------
    
    // Maps Token ID to its Certification Level (1 to 8).
    mapping(uint256 => uint256) private tokenLevel;
    
    // Tracks the next available Token ID.
    uint256 private nextTokenId = 1;

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
        require(level >= 1 && level <= 8, "RIVEROVA: Invalid level (must be 1-8).");
        
        uint256 tokenId = nextTokenId;
        
        // 1. Mint the token
        _safeMint(to, tokenId);
        
        // 2. Set the metadata URI (pointing to IPFS)
        _setTokenURI(tokenId, tokenURI);
        
        // 3. Map the level (CRITICAL for DAO integration)
        tokenLevel[tokenId] = level;
        
        nextTokenId++;
        return tokenId;
    }

    //-------------------------------------------------------------------------
    // 4. DAO Integration Function
    //-------------------------------------------------------------------------
    
    /**
     * @notice Returns the level of a specific token ID.
     * @dev Used by external contracts (like DaoGovernance) for verification.
     * @param _tokenId The ID of the certificate NFT.
     * @return The level (1-8) associated with the token. Returns 0 if token ID does not exist.
     */
    function getTokenLevel(uint256 _tokenId) public view returns (uint256) {
        return tokenLevel[_tokenId];
    }
}