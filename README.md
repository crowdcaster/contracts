# Crowdcaster Contracts

## Introduction
Here we hold the set of crowcaster contracts, including:
- CrowdcasterStrategy.sol, which is an early implementation of a kickstarter-style strategy for gitcoin allo v2;
- simpleCampaign.sol, a functional standalone contract allowing for kickstarter-style donations of native and ERC-20 tokens. This includes permissionless donation and resolution of the crowdcaster campaign. 

## Sequence Diagram

The proposed structure of the CrowdcasterStrategy is as follows:

```mermaid
sequenceDiagram
    participant Alice
    participant Bob
    participant PoolManager
    participant Allo
    participant CrowdcasterStrategy

    PoolManager->>Allo: createPool with CrowdcasterStrategy
    Allo-->>PoolManager: poolId
    Bob ->> PoolManager: allocate()
    PoolManager->>Allo: allocate()
    Allo-->>CrowdcasterStrategy: allocate()
    CrowdcasterStrategy ->> CrowdcasterStrategy: checkThreshold()
    Bob ->> PoolManager: allocate()
    PoolManager->>Allo: allocate()
    Allo-->>CrowdcasterStrategy: allocate()
    CrowdcasterStrategy ->> CrowdcasterStrategy: checkThreshold()
```

Nevertheless, there are some restrictions on the gitcoin allo architecture; namely, increasePoolAmount does not return who increased the pool. For the sake of not using  so the architecture may need some further thought.

We have created an interim POC contract, which have three main functions:

```sol
function createCampaign(
    uint256 goalAmount,
    uint256 duration,
    uint256 minimumDonation,
    address beneficiary,
    address token,
    bytes calldata name,
    bytes calldata description
  ) public {}
```
This function allows for creating new campaigns, whether in an ERC20 token like $DEGEN :hat: or a native token.

```sol
  function contribute(uint256 id, uint256 amount) public payable {}
```
This function allows donating to a campaign. It also checks whether a campaign has reached the minimum threshold, at which point it executes the distribution of funds.

```sol
    if (campaigns[id].totalContributions >= campaigns[id].goalAmount) {
      campaigns[id].status = false;
      emit CampaignSuccess(id, campaigns[id].totalContributions);
      [...]
    }
```

If the execution is not successful, returning funds is possible via the following function:

```sol
  function returnFunds(uint256 id) public {}
```
## Testing
There is testing already created for the SimpleCampaign, available using foundry.

## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy the `.env.example` file to `.env` and fill in the variables.
3. Install the dependencies by running: `yarn install`. In case there is an error with the commands, run `foundryup` and try them again.

## Build

The default way to build the code is suboptimal but fast, you can run it via:

```bash
yarn build
```

In order to build a more optimized code ([via IR](https://docs.soliditylang.org/en/v0.8.15/ir-breaking-changes.html#solidity-ir-based-codegen-changes)), run:

```bash
yarn build:optimized
```

## Running tests

Unit tests should be isolated from any externalities, while Integration usually run in a fork of the blockchain. In this boilerplate you will find example of both.

In order to run both unit and integration tests, run:

```bash
yarn test
```

In order to just run unit tests, run:

```bash
yarn test:unit
```

In order to run unit tests and run way more fuzzing than usual (5x), run:

```bash
yarn test:unit:deep
```

In order to just run integration tests, run:

```bash
yarn test:integration
```

In order to check your current code coverage, run:

```bash
yarn coverage
```

<br>

## Deploy & verify

### Setup

Configure the `.env` variables.

### Sepolia

```bash
yarn deploy:sepolia
```

### Mainnet

```bash
yarn deploy:mainnet
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).

## Export And Publish

Export TypeScript interfaces from Solidity contracts and interfaces providing compatibility with TypeChain. Publish the exported packages to NPM.

To enable this feature, make sure you've set the `NPM_TOKEN` on your org's secrets. Then set the job's conditional to `true`:

```yaml
jobs:
  export:
    name: Generate Interfaces And Contracts
    # Remove the following line if you wish to export your Solidity contracts and interfaces and publish them to NPM
    if: true
    ...
```

Also, remember to update the `package_name` param to your package name:

```yaml
- name: Export Solidity - ${{ matrix.export_type }}
  uses: defi-wonderland/solidity-exporter-action@1dbf5371c260add4a354e7a8d3467e5d3b9580b8
  with:
    # Update package_name with your package name
    package_name: "my-cool-project"
    ...


- name: Publish to NPM - ${{ matrix.export_type }}
  # Update `my-cool-project` with your package name
  run: cd export/my-cool-project-${{ matrix.export_type }} && npm publish --access public
  ...
```

You can take a look at our [solidity-exporter-action](https://github.com/defi-wonderland/solidity-exporter-action) repository for more information and usage examples.

## Licensing
The primary license for the boilerplate is MIT, see [`LICENSE`](https://github.com/defi-wonderland/solidity-foundry-boilerplate/blob/main/LICENSE)