#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}MetaMask Import Troubleshooting${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# Foundation account key
FOUNDATION_KEY="2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201"
FOUNDATION_ADDRESS="0x71562b71999873DB5b286dF957af199Ec94617F7"

# Verify key format
if [[ "$FOUNDATION_KEY" =~ ^[0-9a-f]{64}$ ]]; then
    echo -e "${GREEN}✓ Private key format looks valid (64 hex characters)${NC}"
else
    echo -e "${RED}✗ Private key has incorrect format - should be 64 hex characters${NC}"
fi

# Check length (should be 64 characters)
KEY_LENGTH=${#FOUNDATION_KEY}
echo -e "Private key length: ${BLUE}$KEY_LENGTH characters${NC} (should be 64)"

echo -e "\n${YELLOW}MetaMask Import Process:${NC}"
echo "1. First ensure you have connected to the BRDPoS Chain network:"
echo "   → Chain ID: 3669"
echo "   → RPC URL: http://192.168.1.180:8651"
echo
echo "2. To import the account:"
echo "   → Open MetaMask"
echo "   → Click on your profile icon in the top-right corner"
echo "   → Select 'Import Account' from the menu"
echo "   → Choose 'Private Key' type (not JSON)"
echo "   → Copy and paste EXACTLY this key (no spaces, no 0x prefix):"
echo
echo -e "${BLUE}$FOUNDATION_KEY${NC}"
echo
echo "   → Click Import"
echo

# Clipboard operations
if command -v pbcopy &> /dev/null; then
    echo "$FOUNDATION_KEY" | pbcopy
    echo -e "${GREEN}✓ Private key has been copied to clipboard${NC}"
    echo "  Just paste directly into MetaMask's private key field"
fi

echo -e "\n${YELLOW}Common Issues:${NC}"
echo "• Ensure you're not adding \"0x\" prefix when pasting"
echo "• Verify there are no trailing spaces or newlines"
echo "• Try switching to a different MetaMask network first, then back to BRDPoS Chain"
echo "• If using the mobile app, the import process might be different"
echo "• For desktop, try accessing MetaMask by clicking the extension icon"
echo "• Restart your browser or MetaMask extension if issues persist"
echo
echo -e "${YELLOW}Alternative Method:${NC}"
echo "If you still have issues, try our JSON import method instead:"
echo "  ./import-to-metamask.sh" 