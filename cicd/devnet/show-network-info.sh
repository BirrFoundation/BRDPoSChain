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

# Check if node is running
if ! pgrep -f "BRC.*--datadir ./tmp/brdpos-node" > /dev/null; then
    echo -e "${RED}❌ BRDPoS node is not running!${NC}"
    echo -e "${YELLOW}Please start the node with:${NC} ./start-brdpos-3669.sh"
    exit 1
fi

# Get IP address
HOST_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
if [ -z "$HOST_IP" ]; then
    HOST_IP="localhost"
fi

# Get current block information
BLOCK_INFO=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    -H "Content-Type: application/json" "http://localhost:8651")
    
BLOCK_HEX=$(echo "$BLOCK_INFO" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
if [ -n "$BLOCK_HEX" ]; then
    BLOCK_NUM=$((16#${BLOCK_HEX#0x}))
else
    BLOCK_NUM="unknown"
fi

# Print header
echo -e "\n${BOLD}${CYAN}=== BRDPoS Chain Connection Information ===${NC}\n"

# Print network information
echo -e "${BOLD}${GREEN}MetaMask Configuration:${NC}"
echo -e "${CYAN}Network Name:${NC}     ${YELLOW}BRDPoS Chain${NC}"
echo -e "${CYAN}New RPC URL:${NC}      ${YELLOW}http://$HOST_IP:8651${NC}"
echo -e "${CYAN}Chain ID:${NC}         ${YELLOW}3669${NC}"
echo -e "${CYAN}Currency Symbol:${NC}  ${YELLOW}BRC${NC}"
echo -e "${CYAN}Block Explorer:${NC}   ${YELLOW}(leave empty)${NC}"

# Print QR code for mobile connection if qrencode is available
if command -v qrencode >/dev/null 2>&1; then
    echo -e "\n${BOLD}${GREEN}Scan QR code to add to MetaMask mobile:${NC}"
    qrencode -t ANSIUTF8 "ethereum:?rpc-url=http://$HOST_IP:8651&chainId=3669&name=BRDPoS%20Chain&symbol=BRC"
fi

# Print current status
echo -e "\n${BOLD}${GREEN}Current Status:${NC}"
echo -e "${CYAN}Node Status:${NC}      ${GREEN}Running${NC}"
echo -e "${CYAN}Current Block:${NC}    ${YELLOW}$BLOCK_NUM${NC}"

# Print help text
echo -e "\n${BOLD}${GREEN}Instructions:${NC}"
echo -e "1. Open MetaMask and click on the network selector at the top"
echo -e "2. Click \"Add Network\" > \"Add a network manually\""
echo -e "3. Enter the details above"
echo -e "4. Click \"Save\" to connect"

# Print private key export instructions
echo -e "\n${BOLD}${GREEN}Import Accounts:${NC}"
echo -e "To import your validator account to MetaMask, export the private key:"
echo -e "${YELLOW}./backup-keys.sh${NC}"
echo -e "Then select option 3 to export your private keys."

# Print warning
echo -e "\n${BOLD}${RED}⚠️ WARNING:${NC} This is a development chain. Never use real Ethereum assets here!"
echo 