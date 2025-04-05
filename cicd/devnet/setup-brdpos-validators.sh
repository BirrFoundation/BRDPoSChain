#!/bin/bash

# This script sets up a multi-node BRDPoS network with validators
# Based on the working reset-and-start-devnet.sh script

# Number of validator nodes to create
NUM_VALIDATORS=3

# Stop any running BRC processes
pkill -f BRC || true
sleep 2

# Clean up existing node data
echo "Cleaning up existing node data..."
rm -rf ./tmp
mkdir -p ./tmp

# Create password file
echo "" > ./tmp/password.txt

# Define hardcoded private keys and their corresponding addresses for validators
declare -a PRIVATE_KEYS=("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291" 
                         "c8c53657e41a402d4a4d45901a845f8e3c1e5c4c7a5f1f0e4d3f9a3b2c1d0e9f8" 
                         "d7d6d5d4d3d2d1d0c9c8c7c6c5c4c3c2c1b0b9b8b7b6b5b4b3b2b1a0a9a8a7a6a5")

declare -a WALLET_ADDRESSES=("71562b71999873db5b286df957af199ec94617f7" 
                            "0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b" 
                            "9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b")

# Create directories for each validator
for i in $(seq 1 $NUM_VALIDATORS); do
  mkdir -p ./tmp/validator$i
  mkdir -p ./tmp/validator$i/keystore
done

# Import private keys for each validator
echo "Importing validator private keys..."
for i in $(seq 1 $NUM_VALIDATORS); do
  idx=$((i-1))
  wallet=${WALLET_ADDRESSES[$idx]}
  private_key=${PRIVATE_KEYS[$idx]}
  
  echo "Setting up validator $i with address: 0x${wallet}"
  
  # Import the private key
  ../../build/bin/BRC account import --datadir ./tmp/validator$i --password ./tmp/password.txt <(echo "${private_key}")
  
  # Store the wallet address for later use
  echo "${wallet}" > ./tmp/validator$i/address.txt
done

# Create genesis.json with all validators
echo "Creating genesis.json with validators..."
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
      "foudationWalletAddr": "0x${WALLET_ADDRESSES[0]}"
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
EOF

# Add all validators to the genesis file
for i in $(seq 1 $NUM_VALIDATORS); do
  idx=$((i-1))
  wallet=${WALLET_ADDRESSES[$idx]}
  
  if [ $i -eq $NUM_VALIDATORS ]; then
    echo "    \"0x${wallet}\"" >> ./tmp/genesis.json
  else
    echo "    \"0x${wallet}\"," >> ./tmp/genesis.json
  fi
done

# Complete the genesis file
cat >> ./tmp/genesis.json << EOF
  ],
  "alloc": {
EOF

# Allocate funds to all validators
for i in $(seq 1 $NUM_VALIDATORS); do
  idx=$((i-1))
  wallet=${WALLET_ADDRESSES[$idx]}
  
  if [ $i -eq $NUM_VALIDATORS ]; then
    cat >> ./tmp/genesis.json << EOF
    "0x${wallet}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
EOF
  else
    cat >> ./tmp/genesis.json << EOF
    "0x${wallet}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
EOF
  fi
done

# Complete the genesis file
cat >> ./tmp/genesis.json << EOF
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

# Initialize each validator node with the genesis file
echo "Initializing validator nodes with genesis..."
for i in $(seq 1 $NUM_VALIDATORS); do
  ../../build/bin/BRC --datadir ./tmp/validator$i init ./tmp/genesis.json
done

# Start the first node as the bootnode
echo "Starting bootnode (validator 1)..."
../../build/bin/BRC --datadir ./tmp/validator1 \
  --port 30301 \
  --http --http-addr 0.0.0.0 --http-port 8545 \
  --http-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --http-corsdomain "*" --http-vhosts "*" \
  --ws --ws-addr 0.0.0.0 --ws-port 8546 --ws-origins "*" \
  --ws-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --unlock "0x${WALLET_ADDRESSES[0]}" --password ./tmp/password.txt \
  --mine --etherbase "0x${WALLET_ADDRESSES[0]}" \
  --syncmode full --gcmode=archive \
  --networkid 551 --verbosity 4 > ./tmp/validator1.log 2>&1 &

BOOTNODE_PID=$!
echo "Bootnode started with PID: $BOOTNODE_PID"

# Wait for the bootnode to start
echo "Waiting for bootnode to start..."
sleep 10

# Get the enode of the bootnode
echo "Getting bootnode enode..."
BOOTNODE_ENODE=$(../../build/bin/BRC --exec "admin.nodeInfo.enode" attach ./tmp/validator1/BRC.ipc)
echo "Bootnode enode: $BOOTNODE_ENODE"

# Start the other validator nodes
for i in $(seq 2 $NUM_VALIDATORS); do
  idx=$((i-1))
  wallet=${WALLET_ADDRESSES[$idx]}
  
  echo "Starting validator $i..."
  ../../build/bin/BRC --datadir ./tmp/validator$i \
    --port $((30300 + $i)) \
    --http --http-addr 0.0.0.0 --http-port $((8544 + $i)) \
    --http-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
    --http-corsdomain "*" --http-vhosts "*" \
    --ws --ws-addr 0.0.0.0 --ws-port $((8545 + $i)) --ws-origins "*" \
    --ws-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
    --unlock "0x${wallet}" --password ./tmp/password.txt \
    --mine --etherbase "0x${wallet}" \
    --syncmode full --gcmode=archive \
    --bootnodes $BOOTNODE_ENODE \
    --networkid 551 --verbosity 4 > ./tmp/validator$i.log 2>&1 &
  
  echo "Validator $i started with PID: $!"
done

echo "Multi-node BRDPoS network setup complete!"
echo "Validator 1 (Bootnode) HTTP-RPC: http://localhost:8545"
echo "Validator 2 HTTP-RPC: http://localhost:8546"
echo "Validator 3 HTTP-RPC: http://localhost:8547"

# Function to check block progress
check_progress() {
  echo "Checking block progress..."
  for i in $(seq 1 $NUM_VALIDATORS); do
    BLOCK_NUM=$(../../build/bin/BRC --exec "eth.blockNumber" attach ./tmp/validator$i/BRC.ipc 2>/dev/null || echo "Node not ready")
    echo "Validator $i block number: $BLOCK_NUM"
    
    # Check if mining is enabled
    MINING=$(../../build/bin/BRC --exec "eth.mining" attach ./tmp/validator$i/BRC.ipc 2>/dev/null || echo "Node not ready")
    echo "Validator $i mining enabled: $MINING"
    
    # Check peers
    PEERS=$(../../build/bin/BRC --exec "admin.peers.length" attach ./tmp/validator$i/BRC.ipc 2>/dev/null || echo "Node not ready")
    echo "Validator $i peer count: $PEERS"
  done
}

# Wait a bit and check progress
echo "Waiting for blocks to be produced..."
sleep 20
check_progress

# Create a helper script to check node status
cat > ./check-validators.sh << EOF
#!/bin/bash

# Check if nodes are running
ps aux | grep BRC | grep -v grep

# Check block progress
for i in \$(seq 1 $NUM_VALIDATORS); do
  BLOCK_NUM=\$(../../build/bin/BRC --exec "eth.blockNumber" attach ./tmp/validator\$i/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Validator \$i block number: \$BLOCK_NUM"
  
  # Check if mining is enabled
  MINING=\$(../../build/bin/BRC --exec "eth.mining" attach ./tmp/validator\$i/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Validator \$i mining enabled: \$MINING"
  
  # Check peers
  PEERS=\$(../../build/bin/BRC --exec "admin.peers.length" attach ./tmp/validator\$i/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Validator \$i peer count: \$PEERS"
done
EOF

chmod +x ./check-validators.sh

echo "To check progress again, run: ./check-validators.sh"
echo "To view logs: tail -f ./tmp/validator*.log"
