# Riverova V1 Architecture Overview: DAO Core Integration

The Riverova V1 architecture focuses on securely linking the centralized AI-driven content production system (Off-Chain) with the decentralized quality control system (On-Chain, DAO).

## Core Components:

1.  **AI Services (Off-Chain):** Generates educational content (V2 roadmap).
2.  **Riverova UI/UX Platform (Off-Chain):** The Community & Voting Platform (V1 roadmap).
3.  **NFT Certification Contract (On-Chain):**
    * **Role:** Issues 8-Level NFT certificates to users.
    * **Key Function:** `getHighestLevel(address)` is used by the DAO to verify voting rights.
4.  **DAO Governance Contract (On-Chain):**
    * **Role:** Manages proposal creation and voting for content validation and system updates.
    * **Integration:** Calls the NFT Contract to enforce **Level 5+** leadership access control for all voting actions.