# Farmers Market Coordination Platform

A digital coordination platform built on Stacks blockchain for farmers markets with vendor management, market scheduling, and customer loyalty programs.

## Overview

This platform empowers farmers markets by providing a decentralized system for:
- **Vendor Management**: Register and verify local farmers and artisan vendors
- **Market Scheduling**: Coordinate market dates, locations, and vendor booth assignments  
- **Customer Loyalty**: Track customer purchases and reward frequent market supporters

## Architecture

The system consists of three core smart contracts:

### 1. Vendor Registration Contract (`vendor-registration.clar`)
- Register new vendors with verification process
- Store vendor profiles, certifications, and product categories
- Manage vendor status and approval workflows
- Track vendor performance and compliance history

### 2. Market Scheduling Contract (`market-scheduling.clar`)
- Schedule market events with dates, times, and locations
- Assign booth spaces to registered vendors
- Manage capacity limits and vendor preferences
- Handle scheduling conflicts and cancellations

### 3. Customer Loyalty Contract (`customer-loyalty.clar`)
- Track customer purchases across vendors
- Implement point-based reward system
- Manage loyalty tiers and benefits
- Enable redemption of rewards and special offers

## Key Features

- **Decentralized Verification**: Vendor credentials stored immutably on blockchain
- **Fair Booth Assignment**: Transparent scheduling algorithm for equitable space allocation
- **Cross-Vendor Loyalty**: Customers earn rewards from any participating vendor
- **Community Governance**: Market participants can propose and vote on changes
- **Transparent Operations**: All transactions and decisions recorded on-chain

## Smart Contract Functions

### Vendor Registration
- `register-vendor`: Submit vendor application with required information
- `verify-vendor`: Admin function to approve/reject vendor applications
- `update-vendor-status`: Modify vendor standing based on performance
- `get-vendor-info`: Retrieve vendor profile and verification status

### Market Scheduling
- `create-market-event`: Schedule new market date and location
- `assign-booth`: Allocate specific booth space to vendor
- `update-booth-assignment`: Modify booth assignments as needed
- `cancel-market-event`: Handle event cancellations and notifications

### Customer Loyalty
- `register-customer`: Create customer account for loyalty tracking
- `record-purchase`: Log customer transaction and award points
- `redeem-rewards`: Allow customers to spend accumulated points
- `check-loyalty-status`: View customer points balance and tier level

## Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet/) - Stacks smart contract development tool
- [Node.js](https://nodejs.org/) - For running tests and utilities
- [Stacks Wallet](https://wallet.hiro.so/) - For interacting with deployed contracts

### Installation
```bash
# Clone the repository
git clone https://github.com/franksamuel2027/farmers-market-coordination.git

# Navigate to project directory
cd farmers-market-coordination

# Install dependencies
npm install

# Check contract syntax
clarinet check
```

### Testing
```bash
# Run all tests
npm test

# Run specific contract tests
clarinet test tests/vendor-registration_test.ts
clarinet test tests/market-scheduling_test.ts
clarinet test tests/customer-loyalty_test.ts
```

### Deployment
```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet (requires additional configuration)
clarinet deploy --mainnet
```

## Usage Examples

### Registering a Vendor
```clarity
(contract-call? .vendor-registration register-vendor 
  "Green Valley Farm"
  "Organic vegetables and herbs"
  "organic-certified"
  u100) ;; application fee
```

### Scheduling a Market
```clarity
(contract-call? .market-scheduling create-market-event
  u1640995200 ;; timestamp
  "Central Park Farmers Market"
  u50) ;; max vendors
```

### Recording Customer Purchase
```clarity
(contract-call? .customer-loyalty record-purchase
  'SP1CUSTOMER123...
  'SP1VENDOR456...
  u2500) ;; purchase amount in cents
```

## Data Structures

### Vendor Profile
```clarity
{
  name: (string-ascii 64),
  description: (string-ascii 256),
  certification: (string-ascii 32),
  products: (list 10 (string-ascii 32)),
  verified: bool,
  registration-date: uint,
  performance-score: uint
}
```

### Market Event
```clarity
{
  date: uint,
  location: (string-ascii 64),
  max-vendors: uint,
  registered-count: uint,
  status: (string-ascii 16),
  organizer: principal
}
```

### Customer Account
```clarity
{
  total-purchases: uint,
  loyalty-points: uint,
  tier-level: uint,
  join-date: uint,
  last-activity: uint
}
```

## Security Considerations

- **Access Control**: Admin functions restricted to authorized principals
- **Data Validation**: Input sanitization and bounds checking on all parameters
- **Economic Incentives**: Fee structure prevents spam and encourages quality participation
- **Upgrade Path**: Contracts designed with future extensibility in mind

## Contributing

We welcome contributions from the community! Please read our contributing guidelines and submit pull requests for any improvements.

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request with detailed description

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions, suggestions, or support, please contact:
- GitHub Issues: [Create an issue](https://github.com/franksamuel2027/farmers-market-coordination/issues)
- Email: franksamuel2027@gmail.com

## Acknowledgments

- Stacks Foundation for blockchain infrastructure
- Local farmers market communities for inspiration and feedback
- Open source contributors who make projects like this possible

---

*Building community-driven solutions for local food systems* 🌱