#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}BRDPoS Chain Foundation Account${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# This is the foundation account private key from the genesis file
echo -e "${YELLOW}Private Key (for MetaMask import):${NC}"
echo "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201"
echo

echo -e "${YELLOW}Public Address:${NC}"
echo "0x71562b71999873DB5b286dF957af199Ec94617F7"
echo "brc71562b71999873DB5b286dF957af199Ec94617F7"
echo

echo -e "${YELLOW}Instructions:${NC}"
echo "1. Open MetaMask"
echo "2. Click on your account icon (top-right) then 'Import Account'"
echo "3. Select 'Private Key' method"
echo "4. Paste the above private key (without 0x prefix)"
echo "5. Click 'Import'"
echo
echo "Make sure you're connected to the BRDPoS Chain network (Chain ID: 3669)"
echo

# Offer to copy to clipboard if pbcopy is available
if command -v pbcopy > /dev/null; then
    echo "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201" | pbcopy
    echo -e "${GREEN}Private key copied to clipboard!${NC}"
fi 