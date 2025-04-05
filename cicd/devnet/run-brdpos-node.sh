#!/bin/bash
set -e

# Clean up any previous data
echo "Cleaning up previous data..."
rm -rf ./tmp/brdpos-node
mkdir -p ./tmp/brdpos-node/keystore

# Create a password file
echo "password" > ./tmp/password.txt

# Define the validator private key
echo "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201" > ./tmp/key.txt

# Import the private key
echo "Importing validator private key..."
RAW_ACCOUNT=$(../../build/bin/BRC account import --datadir ./tmp/brdpos-node --password ./tmp/password.txt ./tmp/key.txt | grep -o "{.*}" | tr -d "{}")
ACCOUNT="0x${RAW_ACCOUNT#brc}"
echo "Imported account: $ACCOUNT"

# Let's explicitly set the expected field name in the genesis file
echo "Creating BRDPoS genesis file..."
cat > ./tmp/brdpos-genesis.json << EOF
{
  "config": {
    "chainId": 551,
    "homesteadBlock": 1,
    "eip150Block": 2,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 3,
    "eip158Block": 3,
    "byzantiumBlock": 4,
    "BRDPoS": {
      "period": 2,
      "epoch": 900,
      "reward": 5000,
      "rewardCheckpoint": 900,
      "gap": 450,
      "foudationWalletAddr": "0x746249c61f5832c5eed53172776b460491bdcd5c",
      "v2": {
        "switchBlock": 900,
        "config": {
          "maxMasternodes": 108,
          "switchRound": 0,
          "certificateThreshold": 0.667,
          "timeoutSyncThreshold": 3,
          "timeoutPeriod": 5,
          "minePeriod": 2,
          "expTimeoutConfig": {
            "base": 2.0,
            "maxExponent": 5
          }
        },
        "allConfigs": {
          "0": {
            "maxMasternodes": 108,
            "switchRound": 0,
            "certificateThreshold": 0.667,
            "timeoutSyncThreshold": 3,
            "timeoutPeriod": 5,
            "minePeriod": 2,
            "expTimeoutConfig": {
              "base": 2.0,
              "maxExponent": 5
            }
          }
        }
      }
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
    "${ACCOUNT}"
  ],
  "alloc": {
    "${ACCOUNT}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
    "0x746249c61f5832c5eed53172776b460491bdcd5c": {
      "balance": "0x100000000000000000000000000000000000000000000000000000000000000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

# Initialize the node with the BRDPoS genesis file
echo "Initializing node with BRDPoS genesis..."
../../build/bin/BRC --datadir ./tmp/brdpos-node init ./tmp/brdpos-genesis.json

# Get the actual keystore file
KEYSTORE_FILE=$(ls -1 ./tmp/brdpos-node/keystore/)
echo "Using keystore file: $KEYSTORE_FILE"

# Start the node with BRDPoS configuration
echo "Starting BRDPoS node..."
nohup ../../build/bin/BRC --datadir ./tmp/brdpos-node \
  --port 30310 \
  --http \
  --http-addr "0.0.0.0" \
  --http-port 8650 \
  --http-api "eth,web3,debug,personal,admin,BRDPoS,miner,net" \
  --http-corsdomain "*" \
  --http-vhosts "*" \
  --unlock "$ACCOUNT" \
  --password ./tmp/password.txt \
  --mine \
  --miner-etherbase "$ACCOUNT" \
  --verbosity 5 \
  --networkid 551 > ./tmp/brdpos-node.log 2>&1 &

echo "Node started with PID $!"
echo "Check the logs with: tail -f ./tmp/brdpos-node.log"
sleep 2
tail -n 20 ./tmp/brdpos-node.log 