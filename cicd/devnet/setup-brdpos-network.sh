#!/bin/bash

# This script sets up a local BRDPoS network with multiple validator nodes
# It creates multiple validator nodes and configures them to work together

# Number of validator nodes to create
NUM_VALIDATORS=3

# Clean up existing data
echo "Cleaning up existing data..."
pkill -f BRC || true
sleep 2
rm -rf ./tmp
mkdir -p ./tmp

# Create password file (empty password)
echo "" > ./tmp/.pwd

# Create validator wallets
echo "Creating validator wallets..."
VALIDATOR_ADDRESSES=()

for i in $(seq 1 $NUM_VALIDATORS); do
  echo "Creating validator $i..."
  mkdir -p ./tmp/validator$i
  
  # Create a new account for each validator
  WALLET=$(../../build/bin/BRC account new --password ./tmp/.pwd --datadir ./tmp/validator$i | grep -o '0x[0-9a-fA-F]\+' | head -1)
  
  echo "Validator $i address: $WALLET"
  echo "$WALLET" > ./tmp/validator$i/address
  VALIDATOR_ADDRESSES+=("$WALLET")
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
      "foudationWalletAddr": "${VALIDATOR_ADDRESSES[0]}"
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
  if [ $i -eq $NUM_VALIDATORS ]; then
    echo "    \"${VALIDATOR_ADDRESSES[$i-1]}\"" >> ./tmp/genesis.json
  else
    echo "    \"${VALIDATOR_ADDRESSES[$i-1]}\"," >> ./tmp/genesis.json
  fi
done

# Complete the genesis file
cat >> ./tmp/genesis.json << EOF
  ],
  "alloc": {
EOF

# Allocate funds to all validators
for i in $(seq 1 $NUM_VALIDATORS); do
  if [ $i -eq $NUM_VALIDATORS ]; then
    cat >> ./tmp/genesis.json << EOF
    "${VALIDATOR_ADDRESSES[$i-1]}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
EOF
  else
    cat >> ./tmp/genesis.json << EOF
    "${VALIDATOR_ADDRESSES[$i-1]}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
EOF
  fi
done

# Complete the genesis file
cat >> ./tmp/genesis.json << EOF
  }
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
  --http-api db,eth,debug,miner,net,shh,txpool,personal,web3,BRDPoS \
  --http-corsdomain "*" --http-vhosts "*" \
  --ws --ws-addr 0.0.0.0 --ws-port 8546 --ws-origins "*" \
  --unlock "${VALIDATOR_ADDRESSES[0]}" --password ./tmp/.pwd \
  --mine --etherbase "${VALIDATOR_ADDRESSES[0]}" \
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
  echo "Starting validator $i..."
  ../../build/bin/BRC --datadir ./tmp/validator$i \
    --port $((30300 + $i)) \
    --http --http-addr 0.0.0.0 --http-port $((8544 + $i)) \
    --http-api db,eth,debug,miner,net,shh,txpool,personal,web3,BRDPoS \
    --http-corsdomain "*" --http-vhosts "*" \
    --ws --ws-addr 0.0.0.0 --ws-port $((8545 + $i)) --ws-origins "*" \
    --unlock "${VALIDATOR_ADDRESSES[$i-1]}" --password ./tmp/.pwd \
    --mine --etherbase "${VALIDATOR_ADDRESSES[$i-1]}" \
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
  done
}

# Wait a bit and check progress
echo "Waiting for blocks to be produced..."
sleep 20
check_progress

# Create a helper script to check node status
cat > ./check-nodes.sh << EOF
#!/bin/bash

# Check if nodes are running
ps aux | grep BRC | grep -v grep

# Check block progress
for i in \$(seq 1 $NUM_VALIDATORS); do
  BLOCK_NUM=\$(../../build/bin/BRC --exec "eth.blockNumber" attach ./tmp/validator\$i/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Validator \$i block number: \$BLOCK_NUM"
done
EOF

chmod +x ./check-nodes.sh

echo "To check progress again, run: ./check-nodes.sh"
echo "To view logs: tail -f ./tmp/validator*.log"
