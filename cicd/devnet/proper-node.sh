#!/bin/bash
set -e

# Clean up any previous data
rm -rf ./tmp/proper-node
mkdir -p ./tmp/proper-node/keystore

# Create a password file
echo "password" > ./tmp/password.txt

# Define the private key for the validator (this is a test key, don't use in production)
echo "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201" > ./tmp/key.txt

# Import the private key
../../build/bin/BRC account import --datadir ./tmp/proper-node --password ./tmp/password.txt ./tmp/key.txt

# Initialize the node with the proper genesis file
../../build/bin/BRC --datadir ./tmp/proper-node init ./proper-genesis.json

# Start the node
../../build/bin/BRC --datadir ./tmp/proper-node \
  --port 30310 \
  --http \
  --http-addr 0.0.0.0 \
  --http-port 8650 \
  --http-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --http-corsdomain "*" \
  --http-vhosts "*" \
  --unlock 0x71562b71999873db5b286df957af199ec94617f7 \
  --password ./tmp/password.txt \
  --mine \
  --miner-etherbase 0x71562b71999873db5b286df957af199ec94617f7 \
  --verbosity 5 > ./tmp/proper-node.log 2>&1 &

echo "Node started with PID $!"
echo "Check the logs with: tail -f ./tmp/proper-node.log"
tail -n 20 ./tmp/proper-node.log 