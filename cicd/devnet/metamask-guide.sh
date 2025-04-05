#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}${BOLD}MetaMask + BRDPoS Integration Guide${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

echo -e "${YELLOW}${BOLD}STEP 1: Verify Network Connection${NC}"
echo
echo -e "First, let's check if the BRDPoS node is running:"

# Check node connection
NODE_STATUS=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://192.168.1.180:8651)

if [[ "$NODE_STATUS" == *"error"* ]] || [[ -z "$NODE_STATUS" ]]; then
    echo -e "${RED}❌ Cannot connect to the BRDPoS node.${NC}"
    echo -e "${YELLOW}Possible causes:${NC}"
    echo "  • The node is not running (try ./start-brdpos-3669.sh)"
    echo "  • There's a network connectivity issue"
    echo "  • The RPC URL is incorrect"
    exit 1
else
    NETWORK_ID=$(echo "$NODE_STATUS" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✅ Node is accessible (Network ID: $NETWORK_ID)${NC}"
fi

echo -e "\n${YELLOW}${BOLD}STEP 2: MetaMask Network Configuration${NC}"
echo
echo -e "${BOLD}Add the BRDPoS network to MetaMask with these settings:${NC}"
echo -e "  ${BLUE}Network Name:${NC}     BRDPoS Chain"
echo -e "  ${BLUE}RPC URL:${NC}          http://192.168.1.180:8651"
echo -e "  ${BLUE}Chain ID:${NC}         3669"
echo -e "  ${BLUE}Currency Symbol:${NC}  BRC"
echo -e "  ${BLUE}Block Explorer:${NC}   (leave empty)"
echo
echo -e "${YELLOW}To add this network:${NC}"
echo "  1. Open MetaMask"
echo "  2. Click on the network dropdown at the top"
echo "  3. Click 'Add Network' > 'Add Network Manually'"
echo "  4. Enter the details above and save"

echo -e "\n${YELLOW}${BOLD}STEP 3: Account Options${NC}"
echo
echo -e "${BOLD}You have several options to access accounts:${NC}"
echo

echo -e "${GREEN}OPTION A: Use Foundation Account (Recommended)${NC}"
echo -e "The foundation account has a large balance and validator privileges."
echo -e "Private Key: ${BLUE}2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201${NC}"
echo -e "Address: ${BLUE}0x71562b71999873DB5b286dF957af199Ec94617F7${NC}"
echo
echo -e "${YELLOW}To import the foundation account:${NC}"
echo "  1. In MetaMask, click your profile icon (top-right)"
echo "  2. Select 'Import Account'"
echo "  3. Select 'Private Key' type"
echo "  4. Paste this exact key: 2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201"
echo "  5. Click Import"
echo

echo -e "${GREEN}OPTION B: Use a New Random Account${NC}"
echo -e "You can create a completely new account using our wallet generator:"
echo -e "  ${BLUE}$ node eth-wallet.js${NC}"
echo
echo -e "This will generate a new private key and address."
echo

echo -e "${GREEN}OPTION C: Use JSON Keystore Import${NC}"
echo -e "If neither of the above works, try importing via keystore JSON:"
echo -e "  ${BLUE}$ ./import-to-metamask.sh${NC}"
echo
echo -e "${RED}Note:${NC} If MetaMask freezes on JSON import, revert to options A or B."

echo -e "\n${YELLOW}${BOLD}STEP 4: Verify Balance${NC}"
echo
echo -e "Once you've imported an account, verify your balance in MetaMask."
echo -e "The foundation account should show a large balance of BRC."
echo
echo -e "If you created a new account, you can fund it using:"
echo -e "  ${BLUE}$ ./fund-account.sh YOUR_ADDRESS${NC}"
echo
echo -e "${RED}Note:${NC} Funding requires a running node with the foundation account accessible."

echo -e "\n${YELLOW}${BOLD}TROUBLESHOOTING${NC}"
echo
echo -e "${BOLD}If you still can't import an account:${NC}"
echo "  • Make sure you're using the latest version of MetaMask"
echo "  • Try using a different browser"
echo "  • Try restarting the node with: ./start-brdpos-3669.sh"
echo "  • Verify the MetaMask extension is properly installed"
echo
echo -e "${BOLD}If MetaMask can't connect to the network:${NC}"
echo "  • Verify the node is running: ./show-network-info.sh"
echo "  • Make sure your chain ID (3669) matches the genesis file"
echo "  • Check if there are any firewalls blocking the connection"
echo
echo -e "${BOLD}For the most reliable approach:${NC}"
echo "  1. Add the BRDPoS Chain network to MetaMask"
echo "  2. Import the foundation account via private key"
echo "  3. Verify you can see the balance"
echo
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}${BOLD}Happy BRDPoS development!${NC}"
echo -e "${BLUE}==================================================${NC}"

# Copy foundation key to clipboard if pbcopy is available
if command -v pbcopy &> /dev/null; then
    echo "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201" | pbcopy
    echo -e "\n${GREEN}✓ Foundation private key copied to clipboard!${NC}"
fi 