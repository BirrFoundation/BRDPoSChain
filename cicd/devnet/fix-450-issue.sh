#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}${BOLD}BRDPoS Chain 450 Block Limit Fix${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# Check if node is running
NODE_STATUS=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://192.168.1.180:8651)

if [[ -z "$NODE_STATUS" ]] || [[ "$NODE_STATUS" == *"error"* ]]; then
    echo -e "${YELLOW}Node appears to be stopped, which is expected if it hit the 450 block limit.${NC}"
else
    echo -e "${YELLOW}Node appears to be still running. Will proceed anyway.${NC}"
fi

echo -e "\n${BLUE}Looking at current genesis configuration...${NC}"
if [ ! -f "./tmp/brdpos-genesis.json" ]; then
    echo -e "${RED}Genesis file not found at ./tmp/brdpos-genesis.json${NC}"
    exit 1
fi

# Check current gap setting
CURRENT_GAP=$(grep -o '"gap": [0-9]*' ./tmp/brdpos-genesis.json | cut -d':' -f2 | tr -d ' ')
echo -e "Current 'gap' setting: ${YELLOW}$CURRENT_GAP${NC}"

# Create backup of original genesis
cp ./tmp/brdpos-genesis.json ./tmp/brdpos-genesis-original.json
echo -e "${GREEN}✓ Created backup of original genesis file${NC}"

echo -e "\n${BLUE}Creating updated genesis file with higher limits...${NC}"

# Update the genesis file - increase gap and epoch values
sed -i '' 's/"gap": 450/"gap": 9000/' ./tmp/brdpos-genesis.json
sed -i '' 's/"epoch": 900/"epoch": 9000/' ./tmp/brdpos-genesis.json
sed -i '' 's/"rewardCheckpoint": 900/"rewardCheckpoint": 9000/' ./tmp/brdpos-genesis.json
sed -i '' 's/"switchBlock": 900/"switchBlock": 9000/' ./tmp/brdpos-genesis.json

# Verify changes
NEW_GAP=$(grep -o '"gap": [0-9]*' ./tmp/brdpos-genesis.json | cut -d':' -f2 | tr -d ' ')
NEW_EPOCH=$(grep -o '"epoch": [0-9]*' ./tmp/brdpos-genesis.json | cut -d':' -f2 | tr -d ' ')
NEW_CHECKPOINT=$(grep -o '"rewardCheckpoint": [0-9]*' ./tmp/brdpos-genesis.json | cut -d':' -f2 | tr -d ' ')
NEW_SWITCH=$(grep -o '"switchBlock": [0-9]*' ./tmp/brdpos-genesis.json | cut -d':' -f2 | tr -d ' ')

echo -e "${GREEN}✓ Updated genesis configuration:${NC}"
echo -e "  • Gap: ${YELLOW}$NEW_GAP${NC} (was $CURRENT_GAP)"
echo -e "  • Epoch: ${YELLOW}$NEW_EPOCH${NC}"
echo -e "  • Reward Checkpoint: ${YELLOW}$NEW_CHECKPOINT${NC}"
echo -e "  • Switch Block: ${YELLOW}$NEW_SWITCH${NC}"

# Stop existing nodes
echo -e "\n${BLUE}Stopping any existing nodes...${NC}"
EXISTING_PIDS=$(pgrep -f "BRC.*--datadir ./tmp/brdpos-node" || echo "")
if [ -n "$EXISTING_PIDS" ]; then
    echo -e "Found existing processes: $EXISTING_PIDS"
    kill $EXISTING_PIDS 2>/dev/null
    sleep 2
    
    # Force kill if still running
    if pgrep -f "BRC.*--datadir ./tmp/brdpos-node" > /dev/null; then
        echo -e "Using force kill for remaining processes..."
        kill -9 $(pgrep -f "BRC.*--datadir ./tmp/brdpos-node") 2>/dev/null
        sleep 1
    fi
else
    echo -e "No running nodes found."
fi

# Restart the node with the new genesis file
echo -e "\n${BLUE}Restarting node with updated configuration...${NC}"
echo -e "${YELLOW}Running ./start-brdpos-3669.sh${NC}"
./start-brdpos-3669.sh

# Final instructions
echo -e "\n${GREEN}${BOLD}Node has been restarted with updated configuration!${NC}"
echo -e "The blockchain should now continue past block 450."
echo -e "Check the current block number with: ${YELLOW}./show-network-info.sh${NC}"
echo -e "Monitor for any additional issues as the chain progresses." 