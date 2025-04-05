#!/bin/bash
set -e  # Exit on error

# Clean up existing node data
echo "Cleaning up existing node data..."
rm -rf ./tmp/better-node
mkdir -p ./tmp/better-node/keystore

# Create a password file
echo "password" > ./tmp/password.txt

# Import private key for validator
echo "Creating account..."
PRIVATE_KEY="b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291"
echo "$PRIVATE_KEY" > ./tmp/key.txt

# Import the private key
../../build/bin/BRC account import --datadir ./tmp/better-node --password ./tmp/password.txt ./tmp/key.txt

# Initialize node with our better genesis file
echo "Initializing node with better genesis..."
../../build/bin/BRC --datadir ./tmp/better-node init ./better-genesis.json

# Start the node
echo "Starting node..."
../../build/bin/BRC --datadir ./tmp/better-node \
  --port 30310 \
  --http --http-addr 0.0.0.0 --http-port 8650 \
  --http-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --http-corsdomain "*" --http-vhosts "*" \
  --unlock 0x71562b71999873db5b286df957af199ec94617f7 --password ./tmp/password.txt \
  --mine --miner-etherbase 0x71562b71999873db5b286df957af199ec94617f7 \
  --verbosity 4 > ./tmp/better-node.log 2>&1 &

echo "Node started in background with PID $! - Check logs with: tail -f ./tmp/better-node.log"
sleep 5
echo "Last 20 lines of the log:"
tail -20 ./tmp/better-node.log 