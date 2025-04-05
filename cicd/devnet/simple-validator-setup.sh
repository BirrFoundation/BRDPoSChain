#!/bin/bash

# This script sets up a single BRDPoS validator node with proper configuration

# Clean up existing data
echo "Cleaning up existing data..."
pkill -f BRC || true
sleep 2
rm -rf ./tmp
mkdir -p ./tmp

# Create password file (empty password)
echo "" > ./tmp/password.txt

# Create a new account
echo "Creating validator account..."
../../build/bin/BRC account new --password ./tmp/password.txt --datadir ./tmp/brcchain > ./tmp/wallet_output.txt
WALLET=$(cat ./tmp/wallet_output.txt | grep -o '0x[0-9a-fA-F]\{40\}' | head -1)

if [ -z "$WALLET" ]; then
  echo "Failed to create wallet address"
  exit 1
fi

echo "Validator address: $WALLET"

# Create genesis.json with the validator
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
      "foudationWalletAddr": "$WALLET"
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
    "$WALLET"
  ],
  "alloc": {
    "$WALLET": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
EOF

# Initialize the node with the genesis file
echo "Initializing node with genesis..."
../../build/bin/BRC --datadir ./tmp/brcchain init ./tmp/genesis.json

# Start the node
echo "Starting validator node..."
../../build/bin/BRC --datadir ./tmp/brcchain \
  --port 30303 \
  --http --http-addr 0.0.0.0 --http-port 8545 \
  --http-api db,eth,debug,miner,net,shh,txpool,personal,web3,BRDPoS \
  --http-corsdomain "*" --http-vhosts "*" \
  --ws --ws-addr 0.0.0.0 --ws-port 8546 --ws-origins "*" \
  --unlock "$WALLET" --password ./tmp/password.txt \
  --mine --etherbase "$WALLET" \
  --syncmode full --gcmode=archive \
  --networkid 551 --verbosity 4 > ./tmp/validator.log 2>&1 &

NODE_PID=$!
echo "Node started with PID: $NODE_PID"

# Wait for the node to start
echo "Waiting for node to start..."
sleep 10

# Check if the node is running
if ps -p $NODE_PID > /dev/null; then
  echo "Node is running with PID: $NODE_PID"
else
  echo "Node failed to start"
  exit 1
fi

# Function to check block progress
check_progress() {
  echo "Checking block progress..."
  BLOCK_NUM=$(../../build/bin/BRC --exec "eth.blockNumber" attach ./tmp/brcchain/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Block number: $BLOCK_NUM"
  
  # Check if mining is enabled
  MINING=$(../../build/bin/BRC --exec "eth.mining" attach ./tmp/brcchain/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Mining enabled: $MINING"
  
  # Check coinbase address
  COINBASE=$(../../build/bin/BRC --exec "eth.coinbase" attach ./tmp/brcchain/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Coinbase address: $COINBASE"
}

# Wait a bit and check progress
echo "Waiting for blocks to be produced..."
sleep 20
check_progress

echo "To check progress again, run: ./check-node.sh"
echo "To view logs: tail -f ./tmp/validator.log"

# Create a helper script to check node status
cat > ./check-node.sh << EOF
#!/bin/bash

# Check if node is running
ps aux | grep BRC | grep -v grep

# Check block progress
BLOCK_NUM=\$(../../build/bin/BRC --exec "eth.blockNumber" attach ./tmp/brcchain/BRC.ipc 2>/dev/null || echo "Node not ready")
echo "Block number: \$BLOCK_NUM"

# Check if mining is enabled
MINING=\$(../../build/bin/BRC --exec "eth.mining" attach ./tmp/brcchain/BRC.ipc 2>/dev/null || echo "Node not ready")
echo "Mining enabled: \$MINING"

# Check coinbase address
COINBASE=\$(../../build/bin/BRC --exec "eth.coinbase" attach ./tmp/brcchain/BRC.ipc 2>/dev/null || echo "Node not ready")
echo "Coinbase address: \$COINBASE"

# Check peers
PEERS=\$(../../build/bin/BRC --exec "admin.peers" attach ./tmp/brcchain/BRC.ipc 2>/dev/null || echo "Node not ready")
echo "Peers: \$PEERS"
EOF

chmod +x ./check-node.sh
