#!/bin/bash

# Stop any running BRC processes
pkill -f BRC || true

# Clean up existing node data
echo "Cleaning up existing node data..."
rm -rf ./tmp

# Create directories
mkdir -p ./tmp/brcchain
mkdir -p ./tmp/keystore
touch ./tmp/.pwd
echo "" > ./tmp/password.txt

# Use a hardcoded wallet address for simplicity
echo "Using a hardcoded wallet address for simplicity..."
wallet="71562b71999873db5b286df957af199ec94617f7"
echo "Wallet address: ${wallet}"

# Create the account in the node
echo "Creating account in the node..."
echo "" > ./tmp/password.txt
../../build/bin/BRC account import --datadir ./tmp/brcchain --password ./tmp/password.txt <(echo "b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")

# Create a simplified genesis file with the wallet as the validator
echo "Using wallet address: ${wallet} for genesis configuration"

cat > ./tmp/genesis.json << EOF
{
  "config": {
    "chainId": 551,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "BRDPoS": {
      "period": 2,
      "epoch": 900,
      "reward": 10,
      "rewardCheckpoint": 900,
      "gap": 450,
      "foudationWalletAddr": "0x${wallet}"
    }
  },
  "nonce": "0x0",
  "timestamp": "0x0",
  "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "gasLimit": "0x47b760",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "validators": [
    "0x${wallet}"
  ],
  "alloc": {
    "0x${wallet}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

# Initialize the blockchain with the genesis file
echo "Initializing blockchain with genesis file..."
../../build/bin/BRC --datadir ./tmp/brcchain init ./tmp/genesis.json

# Set log level
log_level=4  # Increased verbosity for debugging

# Start the node
echo "Starting node with wallet: ${wallet}"
../../build/bin/BRC --datadir ./tmp/brcchain \
  --http --http-corsdomain "*" --http-addr 0.0.0.0 --http-port 8545 \
  --http-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --ws --ws-addr 0.0.0.0 --ws-port 8546 --ws-origins "*" \
  --ws-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --networkid 551 \
  --port 30303 \
  --identity "BRC-Devnet" \
  --mine \
  --unlock "0x${wallet}" \
  --password ./tmp/password.txt \
  --etherbase "0x${wallet}" \
  --gasprice 0 \
  --targetgaslimit 42000000 \
  --verbosity ${log_level} 2>&1 | tee ./tmp/brc.log
