#!/bin/bash

# This script sets up a local BRDPoS network with multiple validator nodes
# It creates multiple validator nodes and configures them to work together

# Number of validator nodes to create
NUM_VALIDATORS=3

# Clean up existing data
rm -rf ./tmp
mkdir -p ./tmp
mkdir -p ./tmp/brcchain

# Create password file
touch ./tmp/.pwd

# Create validator keys and addresses
echo "Creating validator keys and addresses..."
for i in $(seq 1 $NUM_VALIDATORS); do
  # Create directory for each validator
  mkdir -p ./tmp/validator$i

  # Generate a private key for each validator
  # For testing purposes, we'll use hardcoded private keys
  case $i in
    1)
      PRIVATE_KEY="289c2857d4598e37fb9647507e47a309d6133539bf21a8b9cb6df88fd5232032"
      ;;
    2)
      PRIVATE_KEY="289c2857d4598e37fb9647507e47a309d6133539bf21a8b9cb6df88fd5232033"
      ;;
    3)
      PRIVATE_KEY="289c2857d4598e37fb9647507e47a309d6133539bf21a8b9cb6df88fd5232034"
      ;;
    *)
      PRIVATE_KEY="289c2857d4598e37fb9647507e47a309d6133539bf21a8b9cb6df88fd523203$i"
      ;;
  esac

  echo "$PRIVATE_KEY" > ./tmp/validator$i/key
  
  # Import the key and get the address
  WALLET=$(../../build/bin/BRC account import --password ./tmp/.pwd --datadir ./tmp/validator$i ./tmp/validator$i/key | sed -n 's/Address: {\(.*\)}/\1/p')
  echo "Validator $i address: 0x$WALLET"
  
  # Store the address for later use
  echo "0x$WALLET" > ./tmp/validator$i/address
done

# Collect all validator addresses
VALIDATORS=()
for i in $(seq 1 $NUM_VALIDATORS); do
  ADDR=$(cat ./tmp/validator$i/address)
  if [ ! -z "$ADDR" ]; then
    VALIDATORS+=("$ADDR")
  else
    echo "Error: No address found for validator $i"
    exit 1
  fi
done

# Check if we have all validator addresses
if [ ${#VALIDATORS[@]} -ne $NUM_VALIDATORS ]; then
  echo "Error: Not all validator addresses were collected"
  exit 1
fi

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
      "foudationWalletAddr": "${VALIDATORS[0]}"
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
    echo "    \"${VALIDATORS[$i-1]}\"" >> ./tmp/genesis.json
  else
    echo "    \"${VALIDATORS[$i-1]}\"," >> ./tmp/genesis.json
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
    "${VALIDATORS[$i-1]}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
EOF
  else
    cat >> ./tmp/genesis.json << EOF
    "${VALIDATORS[$i-1]}": {
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

# Create enode list for bootstrapping
echo "Creating enode list for bootstrapping..."
ENODE_LIST="./tmp/bootnodes.list"
touch $ENODE_LIST

# Start the first node as the bootnode
echo "Starting bootnode (validator 1)..."
../../build/bin/BRC --datadir ./tmp/validator1 \
  --port 30301 \
  --http --http-addr 0.0.0.0 --http-port 8545 \
  --http-api db,eth,debug,miner,net,shh,txpool,personal,web3,BRDPoS \
  --http-corsdomain "*" --http-vhosts "*" \
  --ws --ws-addr 0.0.0.0 --ws-port 8546 --ws-origins "*" \
  --unlock "$(cat ./tmp/validator1/address)" --password ./tmp/.pwd \
  --mine --etherbase "$(cat ./tmp/validator1/address)" \
  --syncmode full --gcmode=archive \
  --networkid 551 --verbosity 4 > ./tmp/validator1.log 2>&1 &

# Wait for the bootnode to start
sleep 5

# Get the enode of the bootnode
BOOTNODE_ENODE=$(../../build/bin/BRC --exec "admin.nodeInfo.enode" attach ./tmp/validator1/BRC.ipc)
echo "Bootnode enode: $BOOTNODE_ENODE"
echo $BOOTNODE_ENODE > $ENODE_LIST

# Start the other validator nodes
for i in $(seq 2 $NUM_VALIDATORS); do
  echo "Starting validator $i..."
  ../../build/bin/BRC --datadir ./tmp/validator$i \
    --port $((30300 + $i)) \
    --http --http-addr 0.0.0.0 --http-port $((8544 + $i)) \
    --http-api db,eth,debug,miner,net,shh,txpool,personal,web3,BRDPoS \
    --http-corsdomain "*" --http-vhosts "*" \
    --ws --ws-addr 0.0.0.0 --ws-port $((8545 + $i)) --ws-origins "*" \
    --unlock "$(cat ./tmp/validator$i/address)" --password ./tmp/.pwd \
    --mine --etherbase "$(cat ./tmp/validator$i/address)" \
    --syncmode full --gcmode=archive \
    --bootnodes $BOOTNODE_ENODE \
    --networkid 551 --verbosity 4 > ./tmp/validator$i.log 2>&1 &
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
sleep 10
check_progress

echo "To check progress again, run: ./check-nodes.sh"

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
