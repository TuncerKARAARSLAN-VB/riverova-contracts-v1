# Riverova Contracts V1

**AI-Powered Decentralized Education Infrastructure**

Riverova delivers free, multi-lingual learning (20+ languages), validated by DAO governance for quality control. Secure achievements with immutable 8-level NFT certificates. A Public Goods project focused on mass global adoption.

## 🌟 Features

- **8-Level NFT Certificates**: Immutable blockchain-based certificates from Novice to Visionary
- **DAO Governance**: Quality control through decentralized voting
- **Multi-Language Support**: 20+ languages including English, Spanish, French, Chinese, Arabic, and more
- **Public Goods**: Free education accessible to everyone globally
- **Web3 Native**: Built on Ethereum with ERC-721 NFT standard

## 📜 Smart Contracts

### RiverovaCertificate.sol
ERC-721 NFT contract for issuing immutable educational certificates.

**Certification Levels:**
| Level | Name | Description |
|-------|------|-------------|
| 0 | Novice | Beginner level |
| 1 | Apprentice | Basic understanding |
| 2 | Practitioner | Practical skills |
| 3 | Specialist | Specialized knowledge |
| 4 | Expert | Expert level |
| 5 | Master | Master level |
| 6 | Authority | Authority in the field |
| 7 | Visionary | Highest level |

### RiverovaDAO.sol
Governance contract for quality control and content validation.

**Proposal Types:**
- Course Approval
- Content Update
- Quality Review
- Language Addition
- Governance Change
- Validator Addition
- Curriculum Update

### RiverovaEducation.sol
Core registry for managing courses, learners, and achievements.

**Key Features:**
- Course management with multi-language support
- Learner registration and tracking
- Progress monitoring
- Achievement system with score-based level calculation

## 🛠 Installation

```bash
# Clone the repository
git clone https://github.com/TuncerKARAARSLAN-VB/riverova-contracts-v1.git
cd riverova-contracts-v1

# Install dependencies
npm install
```

## 📝 Usage

### Compile Contracts
```bash
npm run compile
```

### Run Tests
```bash
npm test
```

### Deploy (Hardhat)
```bash
npx hardhat run scripts/deploy.js --network <network-name>
```

## 🌐 Supported Languages

The platform supports 20+ languages:

| Code | Language | Code | Language |
|------|----------|------|----------|
| en | English | zh | Chinese |
| es | Spanish | ja | Japanese |
| fr | French | ko | Korean |
| de | German | ar | Arabic |
| it | Italian | hi | Hindi |
| pt | Portuguese | bn | Bengali |
| ru | Russian | tr | Turkish |
| vi | Vietnamese | th | Thai |
| id | Indonesian | nl | Dutch |
| pl | Polish | sv | Swedish |
| uk | Ukrainian | el | Greek |

Additional languages can be added through DAO governance proposals.

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Riverova Ecosystem                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │  RiverovaDAO    │◄───│  Governance     │                 │
│  │  (Governance)   │    │  Proposals      │                 │
│  └────────┬────────┘    └─────────────────┘                 │
│           │                                                  │
│           │ validates                                        │
│           ▼                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │ RiverovaCert    │◄───│  NFT Metadata   │                 │
│  │ (ERC-721 NFTs)  │    │  (IPFS)         │                 │
│  └────────┬────────┘    └─────────────────┘                 │
│           │                                                  │
│           │ issues certificates                              │
│           ▼                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │ RiverovaEdu     │◄───│  Course Content │                 │
│  │ (Core Registry) │    │  (IPFS)         │                 │
│  └─────────────────┘    └─────────────────┘                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 🔐 Security

- Role-based access control (AccessControl from OpenZeppelin)
- Reentrancy protection (ReentrancyGuard)
- Input validation
- Immutable certificates (once minted, cannot be modified)

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Contact

- **Founder/CEO**: Tuncer KARAARSLAN
- **Project**: Riverova - Public Goods Education
- **Tags**: #Web3 #AI #EduTech #PublicGoods #DAO #NFT
