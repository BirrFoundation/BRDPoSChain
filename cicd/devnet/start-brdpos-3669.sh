#!/bin/bash

# ANSI color codes
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Print header
echo -e "${BOLD}${CYAN}🚀 Starting BRDPoS Chain (ID: 3669) 🚀${NC}"
echo -e "${YELLOW}====================================${NC}"
echo

# Clean up previous runs
echo -e "${CYAN}Checking for existing BRDPoS nodes...${NC}"
EXISTING_PIDS=$(pgrep -f "BRC.*--datadir ./tmp/brdpos-node" || echo "")

if [ -n "$EXISTING_PIDS" ]; then
    echo -e "${YELLOW}⚠️  Found existing BRDPoS node processes:${NC}"
    ps -p $EXISTING_PIDS -o pid,command
    
    echo -e "${CYAN}Stopping existing nodes...${NC}"
    kill $EXISTING_PIDS 2>/dev/null
    sleep 2
    
    # Check if processes are still running
    if pgrep -f "BRC.*--datadir ./tmp/brdpos-node" > /dev/null; then
        echo -e "${RED}❌ Failed to stop all nodes. Trying SIGKILL...${NC}"
        kill -9 $(pgrep -f "BRC.*--datadir ./tmp/brdpos-node") 2>/dev/null
        sleep 1
    fi
else
    echo -e "${GREEN}✅ No existing BRDPoS nodes found.${NC}"
fi

# Clean up data directories
echo -e "${CYAN}Cleaning up data directories...${NC}"
rm -rf ./tmp/brdpos-node-fixed
mkdir -p ./tmp/brdpos-node-fixed/keystore
mkdir -p ./tmp/validator

# Create password file
echo -e "${CYAN}Creating password file...${NC}"
echo "birrcoin123" > ./tmp/password.txt

# Import validator private key
echo -e "${CYAN}Importing validator private key...${NC}"
echo "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201" > ./tmp/validator/key.txt
IMPORT_OUTPUT=$(../../build/bin/BRC account import --datadir ./tmp/brdpos-node-fixed --password ./tmp/password.txt ./tmp/validator/key.txt 2>&1)
echo -e "${CYAN}Import output:${NC} $IMPORT_OUTPUT"

# Extract account address from import output
if [[ "$IMPORT_OUTPUT" =~ \{([0-9a-fA-F]+)\} ]]; then
    RAW_ACCOUNT="${BASH_REMATCH[1]}"
    ACCOUNT="0x${RAW_ACCOUNT#brc}"
    echo -e "${GREEN}Extracted account address: ${YELLOW}$ACCOUNT${NC}"
elif [[ "$IMPORT_OUTPUT" =~ (0x|brc)([0-9a-fA-F]{40}) ]]; then
    if [[ "${BASH_REMATCH[1]}" == "brc" ]]; then
        ACCOUNT="0x${BASH_REMATCH[2]}"
    else
        ACCOUNT="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    fi
    echo -e "${GREEN}Extracted account address: ${YELLOW}$ACCOUNT${NC}"
else
    echo -e "${RED}❌ Failed to extract account address from import output.${NC}"
    echo -e "${CYAN}Using default validator address.${NC}"
    ACCOUNT="0x6704fbfcd5ef766b287262fa2281c105d57246a6"
fi

# Create genesis file
echo -e "${CYAN}Creating BRDPoS genesis file...${NC}"
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
    "constantinopleBlock": 5,
    "petersburgBlock": 6,
    "istanbulBlock": 7,
    "BRDPoS": {
      "period": 2,
      "epoch": 900,
      "reward": 5000,
      "rewardCheckpoint": 900,
      "gap": 450,
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
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

echo -e "${GREEN}✅ Created genesis file with validator: ${YELLOW}$ACCOUNT${NC}"

# Initialize node with genesis file
echo -e "${CYAN}Initializing node with BRDPoS genesis...${NC}"
../../build/bin/BRC --datadir ./tmp/brdpos-node-fixed init ./tmp/brdpos-genesis.json

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to initialize node.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node initialized successfully.${NC}"

# Start the node
echo -e "${CYAN}Starting BRDPoS node...${NC}"
../../build/bin/BRC --datadir ./tmp/brdpos-node-fixed \
  --port 30311 \
  --http \
  --http-addr 0.0.0.0 \
  --http-port 8651 \
  --http-api eth,web3,debug,personal,admin,BRDPoS,miner,net \
  --http-corsdomain "*" \
  --http-vhosts "*" \
  --ws \
  --ws-addr 0.0.0.0 \
  --ws-port 8652 \
  --ws-origins "*" \
  --unlock "$ACCOUNT" \
  --password ./tmp/password.txt \
  --mine \
  --miner-etherbase "$ACCOUNT" \
  --verbosity 5 \
  --networkid 3669 > ./tmp/brdpos-node-fixed.log 2>&1 &

NODE_PID=$!

# Check if the node started successfully
if ! ps -p $NODE_PID > /dev/null; then
    echo -e "${RED}❌ Failed to start BRDPoS node.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ BRDPoS node started with PID $NODE_PID${NC}"

# Wait for node to start
echo -e "${CYAN}Waiting for node to start...${NC}"
sleep 5

# Try different methods to enable mining
echo -e "${CYAN}Starting mining...${NC}"

# Method 1: Try miner.start
curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"miner_start","params":[],"id":1}' \
    -H "Content-Type: application/json" http://localhost:8651

sleep 2

# Method 2: Try to set etherbase
curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"miner_setEtherbase","params":["'$ACCOUNT'"],"id":1}' \
    -H "Content-Type: application/json" http://localhost:8651

sleep 2

# Try a third method for completeness
curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"miner_setExtra","params":["BRDPoS"],"id":1}' \
    -H "Content-Type: application/json" http://localhost:8651

# Also try personal_unlockAccount again to ensure the account is unlocked
curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'$ACCOUNT'", "birrcoin123", 0],"id":1}' \
    -H "Content-Type: application/json" http://localhost:8651

# Check if mining is active
echo -e "${CYAN}Checking mining status...${NC}"
sleep 2
MINING_STATUS=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' \
    -H "Content-Type: application/json" http://localhost:8651 | \
    grep -o '"result":[^,}]*' | cut -d':' -f2)
    
if [ "$MINING_STATUS" = "true" ]; then
    echo -e "${GREEN}✅ BRDPoS node is mining successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Mining not active yet. Trying one more time...${NC}"
    
    # Try one more time with a different approach
    curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"miner_start","params":[1],"id":1}' \
        -H "Content-Type: application/json" http://localhost:8651
    
    sleep 3
    
    # Check status again
    MINING_STATUS=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' \
        -H "Content-Type: application/json" http://localhost:8651 | \
        grep -o '"result":[^,}]*' | cut -d':' -f2)
        
    if [ "$MINING_STATUS" = "true" ]; then
        echo -e "${GREEN}✅ BRDPoS node is now mining!${NC}"
    else
        echo -e "${YELLOW}⚠️  Mining still not active. Check logs for details.${NC}"
        echo -e "${YELLOW}You can manually start mining with:${NC} curl -X POST --data '{\"jsonrpc\":\"2.0\",\"method\":\"miner_start\",\"params\":[],\"id\":1}' -H \"Content-Type: application/json\" http://localhost:8651"
    fi
fi

# Check block number
sleep 2
BLOCK_NUMBER=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    -H "Content-Type: application/json" http://localhost:8651 | \
    grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
if [ -n "$BLOCK_NUMBER" ]; then
    BLOCK_DEC=$((16#${BLOCK_NUMBER#0x}))
    echo -e "${GREEN}✅ Current block number: ${YELLOW}$BLOCK_DEC${NC}"
else
    echo -e "${YELLOW}⚠️  Could not get current block number.${NC}"
fi

echo
echo -e "${GREEN}🚀 BRDPoS Chain (ID: 3669) is running! 🚀${NC}"
echo -e "${CYAN}To monitor the blockchain:${NC} ${YELLOW}./monitor-brdpos.sh${NC}"
echo -e "${CYAN}To manage accounts:${NC} ${YELLOW}./account-manager.sh${NC}"
echo -e "${CYAN}To backup keystores:${NC} ${YELLOW}./backup-keys.sh${NC}"
echo 