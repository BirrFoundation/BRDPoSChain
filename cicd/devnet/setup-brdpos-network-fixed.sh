#!/bin/bash

# This script sets up a multi-node BRDPoS network with validators
# Using proper private key format and configuration

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

# Define hardcoded private keys for validators (without 0x prefix)
# These are test keys only - do not use in production
declare -a PRIVATE_KEYS=(
  "b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291"
  "ea6c44ac03bff858b476bba40716402b03e41b8e97e276d1baec7c37d42484a0"
  "689af8efa8c651a91ad287602527f3af2fe9f6501a7ac4b061667b5a93e037fd"
)

# Create directories for each validator
for i in $(seq 1 $NUM_VALIDATORS); do
  mkdir -p ./tmp/validator$i
done

# Import private keys for each validator
echo "Importing validator private keys..."
VALIDATOR_ADDRESSES=()

for i in $(seq 1 $NUM_VALIDATORS); do
  idx=$((i-1))
  private_key=${PRIVATE_KEYS[$idx]}
  
  echo "Setting up validator $i..."
  
  # Save the private key to a file
  echo "$private_key" > ./tmp/validator$i/key.txt
  
  # Import the private key
  WALLET_OUTPUT=$(../../build/bin/BRC account import --datadir ./tmp/validator$i --password ./tmp/password.txt ./tmp/validator$i/key.txt 2>&1)
  
  # Extract the address from the output
  WALLET=$(echo "$WALLET_OUTPUT" | grep -o '0x[0-9a-fA-F]\{40\}' || echo "$WALLET_OUTPUT" | grep -o '{[^}]*}' | sed 's/{//;s/}//')
  
  # Remove brc prefix if present
  WALLET=${WALLET#brc}
  # Remove 0x prefix if present
  WALLET=${WALLET#0x}
  
  echo "Validator $i address: 0x$WALLET"
  
  # Store the wallet address for later use
  echo "$WALLET" > ./tmp/validator$i/address.txt
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
      "foudationWalletAddr": "0x${VALIDATOR_ADDRESSES[0]}"
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
  wallet=${VALIDATOR_ADDRESSES[$idx]}
  
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
  wallet=${VALIDATOR_ADDRESSES[$idx]}
  
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

# Display the genesis file for verification
echo "Genesis file created:"
cat ./tmp/genesis.json

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
  --unlock "0x${VALIDATOR_ADDRESSES[0]}" --password ./tmp/password.txt \
  --mine --etherbase "0x${VALIDATOR_ADDRESSES[0]}" \
  --syncmode full --gcmode=archive \
  --networkid 551 --verbosity 4 > ./tmp/validator1.log 2>&1 &

BOOTNODE_PID=$!
echo "Bootnode started with PID: $BOOTNODE_PID"

# Wait for the bootnode to start
echo "Waiting for bootnode to start..."
sleep 10

# Get the enode of the bootnode
echo "Getting bootnode enode..."
BOOTNODE_ENODE=$(../../build/bin/BRC --exec "admin.nodeInfo.enode" attach ./tmp/validator1/BRC.ipc 2>/dev/null)
# Remove quotes from enode URL
BOOTNODE_ENODE=$(echo $BOOTNODE_ENODE | sed 's/^"//;s/"$//')
if [ -z "$BOOTNODE_ENODE" ]; then
  echo "Failed to get bootnode enode. Check logs at ./tmp/validator1.log"
  exit 1
fi
echo "Bootnode enode: $BOOTNODE_ENODE"

# Start the other validator nodes
for i in $(seq 2 $NUM_VALIDATORS); do
  idx=$((i-1))
  wallet=${VALIDATOR_ADDRESSES[$idx]}
  
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
    --bootnodes "$BOOTNODE_ENODE" \
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
