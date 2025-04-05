#!/bin/bash

# This script sets up a single ERPoS validator node with proper genesis configuration

# Stop any running BRC processes
pkill -f BRC || true
sleep 2

# Clean up existing node data
echo "Cleaning up existing node data..."
rm -rf ./tmp
mkdir -p ./tmp

# Create password file
echo "" > ./tmp/password.txt

# Define hardcoded private key for validator (without 0x prefix)
PRIVATE_KEY="b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291"

# Create directory for validator
mkdir -p ./tmp/validator

# Import private key for validator
echo "Importing validator private key..."
echo "$PRIVATE_KEY" > ./tmp/validator/key.txt

# Import the private key
WALLET_OUTPUT=$(../../build/bin/BRC account import --datadir ./tmp/validator --password ./tmp/password.txt ./tmp/validator/key.txt 2>&1)

# Extract the address from the output
WALLET=$(echo "$WALLET_OUTPUT" | grep -o '0x[0-9a-fA-F]\{40\}' || echo "$WALLET_OUTPUT" | grep -o '{[^}]*}' | sed 's/{//;s/}//')

# Remove brc prefix if present
WALLET=${WALLET#brc}
# Remove 0x prefix if present
WALLET=${WALLET#0x}

echo "Validator address: 0x$WALLET"

# Store the wallet address for later use
echo "$WALLET" > ./tmp/validator/address.txt

# Create genesis.json with validator and proper configuration
echo "Creating genesis.json with validator..."
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
      "foudationWalletAddr": "0x${WALLET}"
    }
  },
  "nonce": "0x0",
  "timestamp": "0x0",
  "extraData": "0x000000000000000000000000000000000000000000000000000000000000000071562b71999873db5b286df957af199ec94617f70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "gasLimit": "0x47b760",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "validators": [
    "0x${WALLET}"
  ],
  "alloc": {
    "0x${WALLET}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

# Display the genesis file for verification
echo "Genesis file created:"
cat ./tmp/genesis.json

# Initialize validator node with the genesis file
echo "Initializing validator node with genesis..."
../../build/bin/BRC --datadir ./tmp/validator init ./tmp/genesis.json

# Start the validator node
echo "Starting validator node..."
CURRENT_DIR=$(pwd)
IPC_PATH="$CURRENT_DIR/tmp/validator/BRC.ipc"
../../build/bin/BRC --datadir ./tmp/validator \
  --port 30302 \
  --http --http-addr 0.0.0.0 --http-port 8555 \
  --http-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --http-corsdomain "*" --http-vhosts "*" \
  --ws --ws-addr 0.0.0.0 --ws-port 8556 --ws-origins "*" \
  --ws-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --unlock "0x${WALLET}" --password ./tmp/password.txt \
  --mine --etherbase "0x${WALLET}" \
  --syncmode full --gcmode=archive \
  --ipcpath "$IPC_PATH" \
  --networkid 551 --verbosity 4 > ./tmp/validator.log 2>&1 &

VALIDATOR_PID=$!
echo "Validator started with PID: $VALIDATOR_PID"

# Wait for the node to start
echo "Waiting for node to start..."
sleep 10

# Explicitly start mining
echo "Starting mining..."
../../build/bin/BRC --exec "miner.start()" attach "$IPC_PATH"

# Wait a bit and check progress
echo "Waiting for blocks to be produced..."
sleep 10

# Check block progress
echo "Checking block progress..."
BLOCK_NUM=$(../../build/bin/BRC --exec "eth.blockNumber" attach "$IPC_PATH")
echo "Current block number: $BLOCK_NUM"

# Check if mining is enabled
MINING=$(../../build/bin/BRC --exec "eth.mining" attach "$IPC_PATH")
echo "Mining enabled: $MINING"

# Keep checking for blocks for a short while
for i in {1..5}; do
  sleep 5
  BLOCK_NUM=$(../../build/bin/BRC --exec "eth.blockNumber" attach "$IPC_PATH")
  echo "Check $i - Current block number: $BLOCK_NUM"
done

echo "To view logs: tail -f ./tmp/validator.log"
echo "To check current block: ../../build/bin/BRC --exec \"eth.blockNumber\" attach \"$IPC_PATH\""
