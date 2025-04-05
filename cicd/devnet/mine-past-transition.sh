#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}${BOLD}BRDPoS Consensus Transition Monitor${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

echo -e "${YELLOW}BRDPoS Blockchain Transition Points:${NC}"
echo -e "• ${BOLD}0-449${NC}: Consensus v1 normal operation"
echo -e "• ${BOLD}450${NC}: Gap point - blockchain pauses to prepare for transition"
echo -e "• ${BOLD}450-899${NC}: Consensus v1 continues after restart"
echo -e "• ${BOLD}900${NC}: Epoch switch/checkpoint and final v1 block"
echo -e "• ${BOLD}901+${NC}: Consensus v2 begins operation"
echo

echo -e "${YELLOW}Current Status:${NC}"

# Function to get current block number
get_block_number() {
    local RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://192.168.1.180:8651)
    
    if [[ "$RESPONSE" == *"result"* ]]; then
        local HEX=$(echo "$RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        local BLOCK=$((16#${HEX#0x}))
        echo $BLOCK
    else
        echo "-1"  # Error condition
    fi
}

# Initial check
CURRENT_BLOCK=$(get_block_number)

if [ "$CURRENT_BLOCK" -eq "-1" ]; then
    echo -e "${RED}❌ Cannot connect to the node.${NC}"
    echo -e "Please run ${YELLOW}./start-brdpos-3669.sh${NC} to start the node."
    exit 1
fi

echo -e "Current block number: ${BLUE}$CURRENT_BLOCK${NC}"

# Determine which phase we're in
if [ "$CURRENT_BLOCK" -lt 450 ]; then
    PHASE="v1 pre-gap"
    NEXT_MILESTONE=450
    MSG="approaching gap point (450)"
elif [ "$CURRENT_BLOCK" -lt 900 ]; then
    PHASE="v1 post-gap"
    NEXT_MILESTONE=900
    MSG="approaching epoch switch/checkpoint (900)"
elif [ "$CURRENT_BLOCK" -eq 900 ]; then
    PHASE="epoch switch"
    NEXT_MILESTONE=901
    MSG="at exact transition point (900)"
else
    PHASE="v2"
    NEXT_MILESTONE=901  # Already passed
    MSG="in v2 consensus mode"
fi

echo -e "Current phase: ${YELLOW}$PHASE${NC}"
echo -e "Status: ${BLUE}$MSG${NC}"

# Wait for block 901 if not already there
if [ "$CURRENT_BLOCK" -lt 901 ]; then
    echo
    echo -e "${YELLOW}Waiting for blockchain to reach block 901...${NC}"
    echo -e "This may take some time. Press Ctrl+C to cancel."
    echo
    
    # Initialize counter to track progress
    LAST_REPORTED_BLOCK=$CURRENT_BLOCK
    
    # Progress display
    echo -e "Block progress: $CURRENT_BLOCK / 901"
    
    # Loop until we hit block 901
    while true; do
        sleep 5  # Check every 5 seconds
        CURRENT_BLOCK=$(get_block_number)
        
        if [ "$CURRENT_BLOCK" -eq "-1" ]; then
            echo -e "\n${RED}❌ Lost connection to the node.${NC}"
            echo -e "The node may have stopped. If it's at the gap point (450), restart with:"
            echo -e "${YELLOW}./start-brdpos-3669.sh${NC}"
            exit 1
        fi
        
        # Only update if the block number changed
        if [ "$CURRENT_BLOCK" -ne "$LAST_REPORTED_BLOCK" ]; then
            echo -e "\rBlock progress: $CURRENT_BLOCK / 901                "
            LAST_REPORTED_BLOCK=$CURRENT_BLOCK
            
            # Check if we hit any milestones
            if [ "$CURRENT_BLOCK" -eq 450 ]; then
                echo -e "\n${YELLOW}Reached gap point (450)${NC}"
                echo -e "The node may pause here. If it stops, restart with:"
                echo -e "${YELLOW}./start-brdpos-3669.sh${NC}"
            elif [ "$CURRENT_BLOCK" -eq 900 ]; then
                echo -e "\n${YELLOW}Reached epoch switch/checkpoint (900)${NC}"
                echo -e "This is the last block using consensus v1."
            elif [ "$CURRENT_BLOCK" -ge 901 ]; then
                echo -e "\n${GREEN}✅ Success! Reached block 901+${NC}"
                echo -e "The blockchain has transitioned to consensus v2."
                break
            fi
        fi
    done
else
    echo -e "${GREEN}✅ Already past block 901${NC}"
    echo -e "The blockchain is operating in consensus v2 mode."
fi

echo
echo -e "${YELLOW}${BOLD}BRDPoS Consensus Information:${NC}"
echo
echo -e "${BLUE}Consensus v1 (blocks 0-900):${NC}"
echo "• Simple delegated-proof-of-stake (DPoS) consensus"
echo "• Gap period at block 450 for preparation"
echo "• Epoch length of 900 blocks with checkpoint at block 900"
echo
echo -e "${BLUE}Consensus v2 (blocks 901+):${NC}"
echo "• Enhanced BFT-based consensus mechanism"
echo "• Support for validator signatures and quorum certificates"
echo "• Improved finality guarantees and network security"
echo
echo -e "${BLUE}Key Parameters:${NC}"
echo "• Period: 2 (seconds between blocks)"
echo "• Epoch: 900 (blocks per epoch cycle)"
echo "• Gap: 450 (blocks before epoch where preparation happens)"
echo "• SwitchBlock: 900 (block where v1 to v2 transition occurs)"
echo
echo -e "${GREEN}${BOLD}Your blockchain is now ready for use with MetaMask.${NC}"
echo -e "Run ${YELLOW}./show-network-info.sh${NC} for connection details." 