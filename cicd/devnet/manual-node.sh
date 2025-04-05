#!/bin/bash
set -e  # Exit on error

# This script sets up a single XDPoS validator node with proper genesis configuration

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
../../build/bin/BRC account import --datadir ./tmp/validator --password ./tmp/password.txt ./tmp/validator/key.txt

# Use the known wallet address directly (from previous tests)
WALLET="71562b71999873db5b286df957af199ec94617f7"
echo "Using wallet address: 0x$WALLET"

# Store the wallet address for later use
echo "$WALLET" > ./tmp/validator/address.txt

# Copy the manually created genesis file
echo "Copying manual-genesis.json..."
cp ./manual-genesis.json ./tmp/genesis.json

# Display the genesis file for verification
echo "Genesis file:"
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
  --http-api eth,web3,debug,personal,admin,XDPoS,miner,net \
  --http-corsdomain "*" --http-vhosts "*" \
  --ws --ws-addr 0.0.0.0 --ws-port 8556 --ws-origins "*" \
  --ws-api eth,web3,debug,personal,admin,XDPoS,miner,net \
  --unlock "0x$WALLET" --password ./tmp/password.txt \
  --mine --etherbase "0x$WALLET" \
  --syncmode full --gcmode=archive \
  --ipcpath "$IPC_PATH" \
  --networkid 551 --verbosity 4 > ./tmp/validator.log 2>&1 &

VALIDATOR_PID=$!
echo "Validator started with PID: $VALIDATOR_PID"

# Wait for the node to start
echo "Waiting for node to start..."
sleep 10

# Check logs for any errors
echo "Checking validator logs (last 20 lines):"
tail -20 ./tmp/validator.log

# Explicitly start mining
echo "Starting mining..."
../../build/bin/BRC --exec "miner.start()" attach "$IPC_PATH" || {
  echo "Failed to connect to node. Checking logs for errors:"
  cat ./tmp/validator.log
  exit 1
}

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