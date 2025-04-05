#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}${BOLD}MetaMask Chrome Extension Troubleshooting${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

echo -e "${YELLOW}${BOLD}Chrome-Specific MetaMask Issues${NC}"
echo
echo -e "If you're having trouble importing accounts in Chrome but it works on mobile:"
echo

echo -e "${BOLD}1. Reset MetaMask Extension${NC}"
echo "This is often the quickest solution:"
echo "  • Click the Chrome menu (three dots in top right)"
echo "  • Go to Extensions"
echo "  • Find MetaMask and click 'Details'"
echo "  • Scroll down and click 'Repair' or 'Update'"
echo "  • If issues persist, consider removing and reinstalling"
echo

echo -e "${BOLD}2. Test Minimal Private Key${NC}"
echo "Try this extremely simple private key format:"
echo -e "${BLUE}1111111111111111111111111111111111111111111111111111111111111111${NC}"
echo "This is a valid private key with 64 characters, all '1's."
echo

echo -e "${BOLD}3. Check Extension Permissions${NC}"
echo "Make sure MetaMask has necessary permissions:"
echo "  • Click the MetaMask icon"
echo "  • Check if it shows any permission warnings"
echo "  • Try clicking 'This can read and change site data' if present"
echo

echo -e "${BOLD}4. Try Incognito Mode${NC}"
echo "Open an incognito window, enable the MetaMask extension there, and try importing."
echo

echo -e "${BOLD}5. Check for Browser Conflicts${NC}"
echo "Some extensions may conflict with MetaMask. Try temporarily disabling:"
echo "  • Ad blockers"
echo "  • Privacy extensions"
echo "  • Other cryptocurrency wallets"
echo

echo -e "${BOLD}6. Clear Browser Cache${NC}"
echo "Clear Chrome's cache and cookies:"
echo "  • Chrome menu > More tools > Clear browsing data"
echo "  • Select 'Cookies and other site data' and 'Cached images and files'"
echo "  • Click 'Clear data'"
echo

echo -e "${BOLD}7. Alternative Import Format${NC}"
echo "Try adding '0x' prefix when importing (some versions behave differently):"
echo -e "${BLUE}0x2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201${NC}"
echo

echo -e "${BOLD}8. Browser Console Errors${NC}"
echo "Check for errors in the browser console:"
echo "  • Right-click on the MetaMask popup"
echo "  • Select 'Inspect' or press F12"
echo "  • Go to the Console tab"
echo "  • Look for any red error messages"
echo

echo -e "${YELLOW}If you're still having issues after trying these steps:${NC}"
echo "1. Try Firefox or another Chromium-based browser (Edge, Brave)"
echo "2. Continue using the mobile app that's working"
echo "3. Report the issue to MetaMask support with the specific error message"
echo

# Copy simple key to clipboard if pbcopy is available
if command -v pbcopy &> /dev/null; then
    echo "1111111111111111111111111111111111111111111111111111111111111111" | pbcopy
    echo -e "${GREEN}✓ Simple test private key copied to clipboard!${NC}"
fi 