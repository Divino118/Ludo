# Game Development Studio Smart Contract

A decentralized game development platform built on the Stacks blockchain that enables community-driven game funding and feature approval through democratic voting.

## Overview

This smart contract creates a transparent, community-backed game development process where:
- Studio leads can launch development campaigns with set budgets and timelines
- Community members can back games financially
- Features are implemented only after community approval through weighted voting
- Backers can claim refunds if funding targets aren't met within the deadline

## Features

### Core Functionality
- **Decentralized Funding**: Community-driven backing system with transparent fund management
- **Democratic Feature Approval**: Weighted voting system based on backing amounts
- **Refund Protection**: Automatic refund mechanism if development targets aren't met
- **Phase Management**: Clear development phases (not_started → development → playtesting)
- **Feature Roadmap**: Structured feature planning with cost estimates

### Key Components
- **Studio Lead**: Project initiator who manages development phases
- **Backers**: Community members who financially support the project
- **Feature Voting**: Investment-weighted decision making on game features
- **Budget Management**: Transparent fund allocation and withdrawal system

## Contract States

The game development process follows these phases:

1. **not_started**: Initial state, waiting for studio lead to launch development
2. **development**: Active development phase, accepting backers and implementing features
3. **playtesting**: Community testing and feature voting phase

## Public Functions

### Development Management

#### `launch-game-development`
```clarity
(launch-game-development (budget uint) (timeline uint))
```
Initiates a new game development project.
- **budget**: Total funding target in microSTX
- **timeline**: Development deadline in blocks (max 1 year/52,560 blocks)
- **Caller becomes**: Studio lead
- **Restrictions**: Can only be called once per contract deployment

#### `begin-playtesting-phase`
```clarity
(begin-playtesting-phase)
```
Transitions from development to playtesting phase.
- **Caller**: Must be studio lead
- **Current phase**: Must be "development"
- **Effect**: Resets voting counters

#### `end-playtesting-phase`
```clarity
(end-playtesting-phase)
```
Concludes playtesting and processes community vote results.
- **Caller**: Must be studio lead
- **Current phase**: Must be "playtesting"
- **Logic**: Approves feature if approvals > rejections, otherwise rejects

### Funding Functions

#### `back-game`
```clarity
(back-game (amount uint))
```
Allows community members to financially back the game.
- **amount**: STX amount to contribute (in microSTX)
- **Requirements**: 
  - Development must be active
  - Total raised cannot exceed budget
  - Amount must be positive
- **Effect**: Transfers STX to contract, updates backer records

#### `withdraw-dev-funds`
```clarity
(withdraw-dev-funds (amount uint))
```
Enables studio lead to withdraw development funds.
- **Caller**: Must be studio lead
- **amount**: STX amount to withdraw
- **Restrictions**: Cannot exceed total funds raised

#### `claim-backer-refund`
```clarity
(claim-backer-refund)
```
Allows backers to reclaim funds if development fails.
- **Conditions**: 
  - Development deadline has passed
  - Funding target was not met
- **Effect**: Returns full investment to backer

### Feature Management

#### `add-game-feature`
```clarity
(add-game-feature (description (string-utf8 256)) (cost uint))
```
Adds a new feature to the development roadmap.
- **Caller**: Must be studio lead
- **description**: Feature description (max 256 UTF-8 characters)
- **cost**: Estimated development cost

#### `vote-on-feature`
```clarity
(vote-on-feature (approve bool))
```
Allows backers to vote on proposed features.
- **Caller**: Must be a backer (have invested funds)
- **Current phase**: Must be "playtesting"
- **Weight**: Vote weight equals investment amount
- **approve**: true for approval, false for rejection

## Read-Only Functions

### `get-game-status`
Returns comprehensive project status including lead, budget, funds raised, deadline, current phase, and feature count.

### `get-backer-investment`
```clarity
(get-backer-investment (backer principal))
```
Returns the total investment amount for a specific backer.

### `get-feature-info`
```clarity
(get-feature-info (feature-id uint))
```
Returns feature details including description and estimated cost.

## Error Codes

| Code | Error | Description |
|------|--------|-------------|
| 100 | ERR_NOT_STUDIO_LEAD | Caller is not the studio lead |
| 102 | ERR_BACKER_NOT_FOUND | Caller has not backed the project |
| 103 | ERR_DEV_CYCLE_ENDED | Development deadline has passed |
| 104 | ERR_BUDGET_TARGET_MISSED | Backing would exceed budget target |
| 105 | ERR_INSUFFICIENT_DEV_BUDGET | Insufficient funds for withdrawal |
| 106 | ERR_INVALID_BACKING_AMOUNT | Invalid backing amount (must be > 0) |
| 107 | ERR_INVALID_DEV_TIMELINE | Invalid timeline (must be 1-52560 blocks) |
| 108 | ERR_FEATURE_REJECTED | Community rejected the proposed feature |
| 109 | ERR_INVALID_FEATURE_DESC | Feature description exceeds 256 characters |

## Usage Examples

### Launching a Game Development Project
```clarity
;; Launch a game with 1000 STX budget and 6-month timeline
(contract-call? .game-dev-contract launch-game-development u1000000000 u26280)
```

### Backing a Game
```clarity
;; Back the game with 10 STX
(contract-call? .game-dev-contract back-game u10000000)
```

### Adding a Feature
```clarity
;; Add a multiplayer feature
(contract-call? .game-dev-contract add-game-feature u"Multiplayer support with matchmaking" u200000000)
```

### Voting on Features
```clarity
;; Approve the current feature
(contract-call? .game-dev-contract vote-on-feature true)
```

## Security Considerations

- **Fund Safety**: All funds are held in the contract until withdrawal or refund
- **Access Control**: Critical functions restricted to studio lead
- **Deadline Enforcement**: Automatic refund eligibility after deadline
- **Investment Tracking**: Transparent record of all backing amounts
- **Weighted Voting**: Prevents gaming of the voting system

## Development Timeline

1. **Setup Phase**: Studio lead launches project with budget and timeline
2. **Funding Phase**: Community backs the project during development period
3. **Development Cycles**: Iterative feature development and community approval
4. **Completion or Refund**: Successful delivery or automatic refund mechanism
