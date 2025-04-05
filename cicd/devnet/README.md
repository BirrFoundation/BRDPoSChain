# BRDPoS Chain DevNet Tools

This directory contains scripts and tools for running and managing a BRDPoS Chain development network.

## BRDPoS Consensus Mechanism

The BRDPoS Chain uses a unique consensus mechanism with the following key characteristics:

### Consensus Transition Points

The blockchain has specific transition points in its life cycle:

- **0-449**: Consensus v1 normal operation
- **450**: Gap point - blockchain pauses to prepare for transition
- **450-899**: Consensus v1 continues after restart
- **900**: Epoch switch/checkpoint and final v1 block
- **901+**: Consensus v2 begins operation

### Key Parameters

- **Period**: 2 (seconds between blocks)
- **Epoch**: 900 (blocks per epoch cycle)
- **Gap**: 450 (blocks before epoch where preparation happens)
- **SwitchBlock**: 900 (block where v1 to v2 transition occurs)

### Mining Past the Gap Point

When you mine the BRDPoS chain, it will automatically stop at the gap point (around block 450). This is normal behavior and part of the consensus design.

To continue mining past the gap point:
```
./start-brdpos-3669.sh
```

The node will restart and continue mining until it reaches block 900, where it will transition from consensus v1 to v2.

### Monitoring the Transition

To monitor the blockchain's progress toward the v1 → v2 transition:
```
./mine-past-transition.sh
```

This script will track the blockchain's progress and notify you when it hits important milestones.

## Available Scripts

### Node Management
- `start-brdpos-3669.sh` - Start the BRDPoS Chain node with Chain ID 3669
- `show-network-info.sh` - Display network connection information for MetaMask
- `mine-past-transition.sh` - Monitor the blockchain's progress through consensus transition points

### Account Management

#### Foundation Account
- `foundation-key.sh` - Get the foundation account private key for MetaMask import
  - This account has a large balance and can be used to fund other accounts
  - Private key: `2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201`
  - Address: `0x71562b71999873DB5b286dF957af199Ec94617F7`

#### Node Accounts / Validators
- `account-manager.sh` - Create new accounts and manage existing ones
- `create-funded-account.sh` - Create a new account and fund it automatically
- `import-to-metamask.sh` - Prepare account information for MetaMask JSON import
- `get-private-key.sh` - Extract private keys using Python (requires modules)
- `extract-key-openssl.sh` - Extract private keys using NodeJS

## Accessing Validator Private Keys

To get a validator's private key, you have several options:

1. **Using `foundation-key.sh` (Easiest)**:
   ```
   ./foundation-key.sh
   ```
   This provides the foundation account, which has validator privileges

2. **Using `import-to-metamask.sh` (Recommended)**:
   ```
   ./import-to-metamask.sh
   ```
   This lists available keystore files, saves your password, and provides instructions to import via JSON

3. **Using `get-private-key.sh` (Python-based)**:
   ```
   ./get-private-key.sh
   ```
   Attempts to extract the raw private key from keystore files using Python

4. **Using `extract-key-openssl.sh` (Node.js-based)**:
   ```
   ./extract-key-openssl.sh
   ```
   Uses Node.js to attempt extraction of private keys

## Troubleshooting MetaMask Issues

If you're having trouble connecting to MetaMask, try these steps:

1. **Check script compatibility with your version of MetaMask**:
   ```
   ./metamask-chrome-fix.sh
   ```
   This provides troubleshooting steps for Chrome extension issues

2. **Use simple account creation**:
   ```
   node eth-wallet.js
   ```
   This creates a completely new account with a clean private key

3. **Get the foundation account**:
   ```
   ./foundation-key.sh
   ```
   This provides a known working account key for importing

## MetaMask Integration

1. Add the BRDPoS Chain network to MetaMask:
   - Network Name: BRDPoS Chain
   - RPC URL: http://192.168.1.180:8651
   - Chain ID: 3669
   - Currency Symbol: BRC

2. Import an account using one of these methods:
   - **Private Key method**: Use `foundation-key.sh` or any of the private key extraction tools
   - **JSON File method**: Use `import-to-metamask.sh` to prepare keystore file for import

## Blockchain Information

The BRDPoS Chain provides:

- **Consensus v1 (blocks 0-900)**:
  - Simple delegated-proof-of-stake (DPoS) consensus
  - Gap period at block 450 for preparation
  - Epoch length of 900 blocks with checkpoint at block 900

- **Consensus v2 (blocks 901+)**:
  - Enhanced BFT-based consensus mechanism
  - Support for validator signatures and quorum certificates
  - Improved finality guarantees and network security

## Security Warning

⚠️ **IMPORTANT**: All private keys and passwords generated in this development environment should be considered insecure and used for testing purposes only. Never use these accounts on mainnet or with real assets.

# CI/CD pipeline for BRC
This directory contains CI/CD scripts used for each of the BRC environments.

## How to deploy more nodes
Adjust the number of variable `num_of_nodes` under file `.env`. (**Maximum supported is 58**)

## Devnet
Each PR merged into `dev-upgrade` will trigger below actions:
- Tests
- Terraform to apply infrascture changes(if any)
- Docker build of BRC with devnet configurations with tag of `:latest`
- Docker push to docker hub. https://hub.docker.com/repository/docker/xinfinorg/devnet
- Deployment of the latest BRC image(from above) to devnet run by AWS ECS

### First time set up an new environment
1. Pre-generate a list of node private keys in below format
```
{
  "brc0": {
    "pk": {{PRIVATE KEY}},
    "address": {{BRC wallet address}},
    "imageTag": {{Optional field to run different version of BRC}},
    "logLevel": {{Optional field to adjust the log level for the container}}
  },
  "brc1": {...},
  "brc{{NUMBER}}: {...}
}
```
2. Access to aws console, create a bucket with name `tf-devnet-bucket`:
  - You can choose any name, just make sure update the name in the s3 bucket name variable in `variables.tf`
  - And update the name of the terraform.backend.s3.bucket from `s3.tf`
3. Upload the file from step 1 into the above bucket with name `node-config.json`
4. In order to allow pipeline able to push and deploy via ECR and ECS, we require below environment variables to be injected into the CI pipeline:
  1. DOCKER_USERNAME
  2. DOCKER_PASSWORD
  3. AWS_ACCESS_KEY_ID
  4. AWS_SECRET_ACCESS_KEY
  
You are all set!

## How to run different version of BRC on selected nodes
1. Create a new image tag:
  - Check out the repo
  - Run docker build `docker build -t brc-devnet -f cicd/devnet/Dockerfile .`
  - Run docker tag `docker tag brc-devnet:latest xinfinorg/devnet:test-{{put your version number here}}`
  - Run docker push `docker push xinfinorg/devnet:test-{{Version number from step above}}`
2. Adjust node-config.json
  - Download the node-config.json from s3
  - Add/update the `imageTag` field with value of `test-{{version number you defined in step 1}}` for the selected number of nodes you want to test with
  - Optional: Adjust the log level by add/updating the field of `logLevel`
  - Save and upload to s3
3. Make a dummy PR and get merged. Wait it to be updated.