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

echo -e "${BOLD}${CYAN}🔑 BRDPoS Foundation Private Key 🔑${NC}"
echo -e "${YELLOW}=================================${NC}\n"

# This is the private key we used in the start-brdpos-3669.sh script
PRIVATE_KEY="2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201"
PUBLIC_ADDRESS="0x6704fbfcd5ef766b287262fa2281c105d57246a6"

echo -e "${CYAN}Foundation Private Key (for MetaMask import):${NC}"
echo -e "${YELLOW}$PRIVATE_KEY${NC}"
echo -e "\n${CYAN}Public Address:${NC}"
echo -e "${GREEN}$PUBLIC_ADDRESS${NC}"

echo -e "\n${RED}⚠️ IMPORTANT: This is the primary validator account for your BRDPoS Chain.${NC}"
echo -e "${RED}⚠️ Keep this key secure! Anyone with this key has control of your chain.${NC}"

echo -e "\n${BOLD}${GREEN}How to Import to MetaMask:${NC}"
echo -e "1. Open MetaMask extension"
echo -e "2. Click on your account icon in the top-right corner"
echo -e "3. Select \"Import Account\""
echo -e "4. Choose \"Private Key\""
echo -e "5. Paste the private key above (without any 0x prefix)"
echo -e "6. Click \"Import\""

# Save to file option
echo -e "\n${CYAN}Would you like to save this key to a file? (y/n)${NC}"
read -r save_to_file

if [ "$save_to_file" = "y" ] || [ "$save_to_file" = "Y" ]; then
    mkdir -p ./tmp/keys
    KEY_FILE="./tmp/keys/foundation_private_key.txt"
    echo "$PRIVATE_KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo -e "${GREEN}✅ Private key saved to:${NC} ${YELLOW}$KEY_FILE${NC}"
fi

echo 