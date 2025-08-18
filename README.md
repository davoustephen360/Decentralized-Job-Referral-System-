# 🔗 Decentralized Job Referral System

A transparent, blockchain-based job referral platform that rewards users for successful job placements through smart contracts on the Stacks blockchain.

## 🌟 Features

- **🎯 Smart Referral Tracking**: Generate unique referral links tied to user wallets
- **💰 Automated Rewards**: Automatic token distribution upon successful hires
- **📊 Transparent Records**: All referrals, hires, and payouts recorded on-chain
- **⚖️ Dispute Resolution**: Community-driven voting system for contested referrals
- **📈 User Analytics**: Track referral performance and earnings

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm (for testing)

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd Decentralized-Job-Referral-System-
```

2. Install dependencies
```bash
npm install
```

3. Check contract compilation
```bash
clarinet check
```

## 🔧 Contract Functions

### 📝 Job Management

#### `create-job`
Creates a new job posting with reward pool
```clarity
(create-job "Software Engineer" "Looking for a skilled developer" u1000000)
```

#### `deactivate-job` 
Deactivates a job posting (employer only)
```clarity
(deactivate-job u1)
```

### 👥 Referral System

#### `create-referral`
Creates a referral for a candidate to a specific job
```clarity
(create-referral 'SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60 u1)
```

#### `verify-hire`
Verifies that a candidate was hired (employer only)
```clarity
(verify-hire u1 'SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60 u1)
```

#### `process-reward`
Processes reward payment to referrer after verified hire
```clarity
(process-reward u1 'SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60)
```

### ⚖️ Dispute Resolution

#### `create-dispute`
Initiates a dispute for a referral (referrer or candidate only)
```clarity
(create-dispute u1 "Referral not properly credited")
```

#### `vote-on-dispute`
Vote on an active dispute (community members)
```clarity
(vote-on-dispute u1 true)
```

#### `resolve-dispute`
Resolves a dispute after voting period ends
```clarity
(resolve-dispute u1)
```

### 📊 Query Functions

#### `get-job`
Retrieves job information
```clarity
(get-job u1)
```

#### `get-referral`
Retrieves referral details
```clarity
(get-referral u1)
```

#### `get-user-stats`
Gets user statistics (referrals, hires, earnings)
```clarity
(get-user-stats 'SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60)
```

## 🔄 Workflow

1. **👔 Employer** creates a job with reward pool using `create-job`
2. **🤝 Referrer** creates referral using `create-referral` 
3. **📞 Candidate** applies for job through referral link
4. **✅ Employer** verifies successful hire using `verify-hire`
5. **💰 System** automatically processes reward using `process-reward`
6. **🗳️ Community** can vote on disputes if needed

## 💡 Example Usage

```clarity
;; Create a software engineering job with 1 STX reward
(contract-call? .Decentralized-Job-Referral-System- create-job 
  "Senior Developer" 
  "Looking for experienced full-stack developer" 
  u1000000)

;; Refer a candidate to the job
(contract-call? .Decentralized-Job-Referral-System- create-referral 
  'SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60 
  u1)

;; Employer verifies the hire
(contract-call? .Decentralized-Job-Referral-System- verify-hire 
  u1 
  'SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60 
  u1)

;; Process the reward payment
(contract-call? .Decentralized-Job-Referral-System- process-reward 
  u1 
  'SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60)
```

## 🧪 Testing

Run the test suite:
```bash
npm test
```

## 🔒 Security Features

- **Owner Controls**: Emergency withdrawal function for contract owner
- **Access Controls**: Role-based permissions for different functions
- **Validation**: Input validation and error handling
- **Dispute System**: Community governance for contested referrals

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Invalid referral |
| u102 | Invalid job |
| u103 | Already hired |
| u104 | Unauthorized access |
| u105 | Insufficient funds |
| u106 | Invalid vote |
| u107 | Dispute not found |
| u108 | Voting period ended |
| u109 | Already voted |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🌐 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet/)

---

Built with ❤️ on Stacks blockchain
