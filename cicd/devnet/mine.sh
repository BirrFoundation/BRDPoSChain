#!/bin/bash

# This script sets up a simple ERPoS validator node and focuses solely on creating blocks

# Stop any running BRC processes
pkill -f BRC || true
sleep 2

# Clean up existing node data
echo "Cleaning up existing node data..."
rm -rf ./miner
mkdir -p ./miner

# Create password file
echo "" > ./miner/password.txt

# Define hardcoded private key for validator (without 0x prefix)
PRIVATE_KEY="b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291"

# Create directory for validator
mkdir -p ./miner/validator

# Import private key for validator
echo "Importing validator private key..."
echo "$PRIVATE_KEY" > ./miner/validator/key.txt

# Import the private key
WALLET_OUTPUT=$(../../build/bin/BRC account import --datadir ./miner/validator --password ./miner/password.txt ./miner/validator/key.txt 2>&1)

# Extract the address from the output
WALLET=$(echo "$WALLET_OUTPUT" | grep -o '0x[0-9a-fA-F]\{40\}' || echo "$WALLET_OUTPUT" | grep -o '{[^}]*}' | sed 's/{//;s/}//')

# Remove brc prefix if present
WALLET=${WALLET#brc}
# Remove 0x prefix if present
WALLET=${WALLET#0x}

echo "Validator address: 0x$WALLET"

# Store the wallet address for later use
echo "$WALLET" > ./miner/validator/address.txt

# Create an ultra-minimal genesis.json
echo "Creating minimal genesis.json..."
cat > ./miner/genesis.json << EOF
{
  "config": {
    "chainId": 999,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0
  },
  "nonce": "0x0000000000000042",
  "timestamp": "0x0",
  "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "gasLimit": "0x1312d00",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "0x${WALLET}": {
      "balance": "0x1000000000000000000000000000000000000000000000000000000000000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

# Initialize the validator with the genesis file
echo "Initializing validator node with genesis..."
../../build/bin/BRC --datadir ./miner/validator init ./miner/genesis.json

# Start the validator node
echo "Starting validator node..."
../../build/bin/BRC --datadir ./miner/validator \
  --port 30888 \
  --http --http-addr 0.0.0.0 --http-port 8599 \
  --http-api eth,web3,debug,personal,admin,miner,net \
  --http-corsdomain "*" --http-vhosts "*" \
  --ws --ws-addr 0.0.0.0 --ws-port 8600 --ws-origins "*" \
  --ws-api eth,web3,debug,personal,admin,miner,net \
  --unlock "0x${WALLET}" --password ./miner/password.txt \
  --mine --miner.threads 2 --etherbase "0x${WALLET}" \
  --networkid 999 --verbosity 4 > ./miner/validator.log 2>&1 &

VALIDATOR_PID=$!
echo "Validator started with PID: $VALIDATOR_PID"

# Wait for the node to start
for i in {1..30}; do
    if [ -S "./miner/validator/BRC.ipc" ]; then
        echo "IPC socket found"
        break
    fi
    echo "Waiting for IPC socket... attempt $i"
    sleep 2
    
    if [ $i -eq 30 ]; then
        echo "Failed to detect IPC socket. Check ./miner/validator.log for errors"
        exit 1
    fi
done

# Ensure mining is active
echo "Starting mining..."
../../build/bin/BRC --exec "miner.start(); console.log('Mining status:', eth.mining);" attach ./miner/validator/BRC.ipc

# Wait for blocks to be created
echo "Waiting for blocks to be mined..."
for i in {1..10}; do
    sleep 3
    BLOCK_NUM=$(../../build/bin/BRC --exec "eth.blockNumber" attach ./miner/validator/BRC.ipc 2>/dev/null)
    echo "Check $i - Block number: $BLOCK_NUM"
    
    if [ "$BLOCK_NUM" -gt 0 ]; then
        echo "SUCCESS! Blocks are being created."
        break
    fi
    
    # If at attempt 5, try to force block creation
    if [ $i -eq 5 ]; then
        echo "Trying to force block creation..."
        ../../build/bin/BRC --exec "console.log('Sending transaction...'); try { eth.sendTransaction({from: eth.coinbase, to: eth.coinbase, value: '1000000000000000000'}); } catch(e) { console.log('Error:', e); }" attach ./miner/validator/BRC.ipc
    fi
done

# Check final status
FINAL_BLOCK=$(../../build/bin/BRC --exec "eth.blockNumber" attach ./miner/validator/BRC.ipc 2>/dev/null)
echo "Final block number: $FINAL_BLOCK"

if [ "$FINAL_BLOCK" -gt 0 ]; then
    echo "SUCCESS: Blocks successfully created!"
    # Show block details
    ../../build/bin/BRC --exec "console.log(JSON.stringify(eth.getBlock(eth.blockNumber), null, 2));" attach ./miner/validator/BRC.ipc
    
    echo "Node is running and creating blocks. Access with:"
    echo "  HTTP endpoint: http://localhost:8599"
    echo "  WebSocket endpoint: ws://localhost:8600"
else
    echo "WARNING: Failed to create blocks."
    tail -n 20 ./miner/validator.log
fi

echo "Useful commands:"
echo "1. View logs: tail -f ./miner/validator.log"
echo "2. Check current block: ../../build/bin/BRC --exec \"eth.blockNumber\" attach ./miner/validator/BRC.ipc"
echo "3. Check mining status: ../../build/bin/BRC --exec \"eth.mining\" attach ./miner/validator/BRC.ipc"
echo "4. Get validator balance: ../../build/bin/BRC --exec \"eth.getBalance(eth.coinbase)\" attach ./miner/validator/BRC.ipc" 