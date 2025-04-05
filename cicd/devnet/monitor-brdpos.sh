#!/bin/bash

# ANSI color codes
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Node HTTP endpoint
NODE_ENDPOINT="http://localhost:8651"

clear
echo -e "${BOLD}${CYAN}✨ BRDPoS Node Monitoring Script ✨${NC}"
echo -e "${YELLOW}=======================================${NC}"

# Function to check node status
check_node_status() {
    echo -e "\n${CYAN}Checking node status...${NC}"
    
    # Check if the node is running
    if ! pgrep -f "BRC.*--datadir ./tmp/brdpos-node" > /dev/null; then
        echo -e "${RED}❌ BRDPoS node is not running!${NC}"
        return 1
    fi
    
    # Check if HTTP API is available
    NETWORK_INFO=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
        -H "Content-Type: application/json" "http://localhost:8651")
    
    if [ -z "$NETWORK_INFO" ]; then
        echo -e "${RED}❌ Cannot connect to BRDPoS HTTP API!${NC}"
        return 1
    fi
    
    # Extract network ID 
    NETWORK_ID=$(echo "$NETWORK_INFO" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$NETWORK_ID" != "3669" ]; then
        echo -e "${YELLOW}⚠️ Connected to network ID $NETWORK_ID (expected 3669)${NC}"
    else
        echo -e "${GREEN}✅ Connected to BRDPoS network (ID: $NETWORK_ID)${NC}"
    fi
    
    return 0
}

# Function to get block number
get_block_number() {
    curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
        grep -o '"result":"[^"]*"' | cut -d'"' -f4
}

# Function to convert hex to decimal
hex_to_dec() {
    echo $((16#${1#0x}))
}

# Function to get current validator
get_current_validator() {
    curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"BRDPoS_getSigners","params":[null],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
        grep -o '"result":\[[^]]*\]' | grep -o '"0x[^"]*"' | tr -d '"'
}

# Get and display network info
echo -e "\n${BOLD}📡 Fetching BRDPoS Network Information...${NC}"
NETWORK_INFO=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"BRDPoS_networkInformation","params":[],"id":1}' \
    -H "Content-Type: application/json" "$NODE_ENDPOINT")

NETWORK_ID=$(echo "$NETWORK_INFO" | grep -o '"NetworkId":[^,]*' | cut -d':' -f2)
PERIOD=$(echo "$NETWORK_INFO" | grep -o '"period":[^,]*' | cut -d':' -f2)
EPOCH=$(echo "$NETWORK_INFO" | grep -o '"epoch":[^,]*' | cut -d':' -f2)
REWARD=$(echo "$NETWORK_INFO" | grep -o '"reward":[^,]*' | cut -d':' -f2)

echo -e "${CYAN}🔗 Network ID:${NC} $NETWORK_ID"
echo -e "${CYAN}⏱️  Block Period:${NC} $PERIOD seconds"
echo -e "${CYAN}🔄 Epoch Length:${NC} $EPOCH blocks"
echo -e "${CYAN}💰 Block Reward:${NC} $REWARD tokens"

# Get validator info
VALIDATOR=$(get_current_validator)
echo -e "\n${BOLD}💻 Current Validator:${NC} $VALIDATOR"

# Check mining status
MINING=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' \
    -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
    grep -o '"result":[^,}]*' | cut -d':' -f2 | tr -d ' "')

if [ "$MINING" == "true" ]; then
    echo -e "${GREEN}✅ Mining is active${NC}"
else
    echo -e "${RED}❌ Mining is not active${NC}"
fi

# Block monitoring loop
echo -e "\n${BOLD}🔄 Starting Block Monitoring...${NC}"
echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"

prev_block_hex="0x0"
start_time=$(date +%s)

# Print header
print_header

# Check if node is running
check_node_status
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}👉 Run the node setup script first: ./run-brdpos-node-fixed.sh${NC}"
    exit 1
fi

while true; do
    # Get current block number
    current_block_hex=$(get_block_number)
    
    if [ -z "$current_block_hex" ]; then
        echo -e "${RED}❌ Cannot connect to node${NC}"
        sleep 5
        continue
    fi
    
    current_block=$(hex_to_dec "$current_block_hex")
    
    # Only display if block number changed
    if [ "$current_block_hex" != "$prev_block_hex" ]; then
        # Get latest block
        BLOCK_INFO=$(curl -s -X POST \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$current_block_hex\", false],\"id\":1}" \
            -H "Content-Type: application/json" "$NODE_ENDPOINT")
        
        TIMESTAMP_HEX=$(echo "$BLOCK_INFO" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
        TIMESTAMP=$(hex_to_dec "$TIMESTAMP_HEX")
        TIMESTAMP_HUMAN=$(date -r "$TIMESTAMP")
        
        # Calculate blocks per minute
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ $elapsed_time -gt 0 ] && [ $current_block -gt 0 ]; then
            blocks_per_minute=$(echo "scale=2; $current_block * 60 / $elapsed_time" | bc)
        else
            blocks_per_minute="calculating..."
        fi
        
        # Progress indicator
        progress=$(($current_block % 10))
        bar=""
        for ((i=0; i<10; i++)); do
            if [ $i -lt $progress ]; then
                bar="${bar}▓"
            else
                bar="${bar}░"
            fi
        done
        
        # Emoji indicator based on block number
        emoji="🔄"
        if (( $current_block % 5 == 0 )); then emoji="⛓️"; fi
        if (( $current_block % 10 == 0 )); then emoji="🎯"; fi
        if (( $current_block % 50 == 0 )); then emoji="💎"; fi
        if (( $current_block % 100 == 0 )); then emoji="🚀"; fi
        
        # Print block info with progress bar
        echo -e "${emoji} ${BOLD}Block ${CYAN}#$current_block${NC} ${GREEN}$bar${NC} (${YELLOW}$blocks_per_minute blocks/min${NC})"
        echo -e "   ${BOLD}Time:${NC} $TIMESTAMP_HUMAN"
        
        # Update previous block
        prev_block_hex=$current_block_hex
    fi
    
    sleep 1
done 