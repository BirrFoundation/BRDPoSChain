#!/bin/bash
set -e

# Clean up any previous data
echo "Cleaning up previous data..."
rm -rf ./tmp/brdpos-node-fixed
mkdir -p ./tmp/brdpos-node-fixed/keystore

# Create a password file
echo "password" > ./tmp/password.txt

# Define the validator private key
echo "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201" > ./tmp/key.txt

# Import the private key
echo "Importing validator private key..."
RAW_ACCOUNT=$(../../build/bin/BRC account import --datadir ./tmp/brdpos-node-fixed --password ./tmp/password.txt ./tmp/key.txt | grep -o "{.*}" | tr -d "{}")
ACCOUNT="0x${RAW_ACCOUNT#brc}"
echo "Imported account: $ACCOUNT"

# Let's explicitly set the expected field name in the genesis file
echo "Creating BRDPoS genesis file..."
cat > ./tmp/brdpos-genesis.json << EOF
{
  "config": {
    "chainId": 3669,
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
  "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000${ACCOUNT#0x}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
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
../../build/bin/BRC --datadir ./tmp/brdpos-node-fixed init ./tmp/brdpos-genesis.json

# Get the actual keystore file
KEYSTORE_FILE=$(ls -1 ./tmp/brdpos-node-fixed/keystore/)
echo "Using keystore file: $KEYSTORE_FILE"

# Start the node with BRDPoS configuration and authorize the validator
echo "Starting BRDPoS node..."
nohup ../../build/bin/BRC --datadir ./tmp/brdpos-node-fixed \
  --port 30311 \
  --http \
  --http-addr "0.0.0.0" \
  --http-port 8651 \
  --http-api "eth,web3,debug,personal,admin,BRDPoS,miner,net" \
  --http-corsdomain "*" \
  --http-vhosts "*" \
  --ws \
  --ws-addr "0.0.0.0" \
  --ws-port 8652 \
  --ws-origins "*" \
  --unlock "$ACCOUNT" \
  --password ./tmp/password.txt \
  --mine \
  --miner-etherbase "$ACCOUNT" \
  --verbosity 5 \
  --networkid 3669 > ./tmp/brdpos-node-fixed.log 2>&1 &

NODE_PID=$!
echo "Node started with PID $NODE_PID"
echo "Check the logs with: tail -f ./tmp/brdpos-node-fixed.log"
echo "Waiting for node to start..."

# Wait for node to start and HTTP server to be ready
max_attempts=20
attempt=0
while ! curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    -H "Content-Type: application/json" http://localhost:8651 >/dev/null 2>&1; do
    
    if ! kill -0 $NODE_PID >/dev/null 2>&1; then
        echo "Node process has died. Check logs."
        exit 1
    fi
    
    attempt=$((attempt+1))
    if [ $attempt -ge $max_attempts ]; then
        echo "Timed out waiting for node to start. Check logs."
        tail -n 30 ./tmp/brdpos-node-fixed.log
        exit 1
    fi
    
    echo "Waiting for node to start (attempt $attempt/$max_attempts)..."
    sleep 2
done

echo "Node is up and running!"
echo ""

# Now let's authorize the account to sign blocks using the RPC API
echo "Authorizing account for BRDPoS signing..."
curl -X POST --data '{"jsonrpc":"2.0","method":"BRDPoS_authorize","params":["'$ACCOUNT'", true],"id":1}' -H "Content-Type: application/json" http://localhost:8651
echo ""
echo "Checking mining status..."
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' -H "Content-Type: application/json" http://localhost:8651

echo ""
echo "Waiting for mining to start and produce blocks..."
sleep 10

echo "Checking block number..."
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' -H "Content-Type: application/json" http://localhost:8651
echo ""
echo "Check the logs for more details:"
tail -n 20 ./tmp/brdpos-node-fixed.log 