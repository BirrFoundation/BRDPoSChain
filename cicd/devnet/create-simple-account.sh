#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}BRDPoS Simple Account Creator for MetaMask${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# Check for brdpos binary
BRDPOS="./brdpos"
if [ ! -x "$BRDPOS" ]; then
    # Check for brdpos in PATH
    if command -v brdpos &> /dev/null; then
        BRDPOS="brdpos"
    else
        # Try to find it in tmp directory
        BRDPOS="./tmp/brdpos-node-fixed/brdpos"
        if [ ! -x "$BRDPOS" ]; then
            echo -e "${RED}Error: brdpos binary not found.${NC}"
            exit 1
        fi
    fi
fi

echo -e "${YELLOW}Creating a new account with simple parameters...${NC}"

# Create a temporary directory for the new keystore
TMP_KEYSTORE=$(mktemp -d)
chmod 700 "$TMP_KEYSTORE"

# Use a very simple password for easier import
PASSWORD="password123"
echo -e "Using password: ${BLUE}$PASSWORD${NC}"
echo -n "$PASSWORD" > "$TMP_KEYSTORE/password.txt"
chmod 600 "$TMP_KEYSTORE/password.txt"

# Create a new account
echo -e "\n${YELLOW}Generating new account...${NC}"
ACCOUNT=$($BRDPOS account new --keystore "$TMP_KEYSTORE" --password "$TMP_KEYSTORE/password.txt" 2>&1)
ACCOUNT_ADDRESS=$(echo "$ACCOUNT" | grep -o "0x[0-9a-fA-F]\{40\}")

if [ -z "$ACCOUNT_ADDRESS" ]; then
    echo -e "${RED}Error: Failed to create account.${NC}"
    echo "$ACCOUNT"
    rm -rf "$TMP_KEYSTORE"
    exit 1
fi

echo -e "${GREEN}Successfully created account: $ACCOUNT_ADDRESS${NC}"

# Find the keystore file
KEYSTORE_FILE=$(find "$TMP_KEYSTORE" -type f -name "UTC--*" | head -1)

if [ ! -f "$KEYSTORE_FILE" ]; then
    echo -e "${RED}Error: Keystore file not found.${NC}"
    rm -rf "$TMP_KEYSTORE"
    exit 1
fi

# Copy the keystore file to the current directory with a simple name
SIMPLE_KEYSTORE="simple_account.json"
cp "$KEYSTORE_FILE" "$SIMPLE_KEYSTORE"
chmod 600 "$SIMPLE_KEYSTORE"

# Save the password to a simple file
SIMPLE_PASSWORD="simple_password.txt"
echo -n "$PASSWORD" > "$SIMPLE_PASSWORD"
chmod 600 "$SIMPLE_PASSWORD"

# Clean up the temporary directory
rm -rf "$TMP_KEYSTORE"

echo -e "\n${GREEN}✓ Account created successfully!${NC}"
echo -e "${YELLOW}Account Address:${NC} $ACCOUNT_ADDRESS"
echo -e "${YELLOW}Keystore File:${NC} $SIMPLE_KEYSTORE"
echo -e "${YELLOW}Password File:${NC} $SIMPLE_PASSWORD"
echo -e "${YELLOW}Password:${NC} $PASSWORD"

# Fund the account with a simple transaction from the foundation account
echo -e "\n${YELLOW}Funding the account with BRC...${NC}"

# Set up the transaction data for sending 1 BRC
FOUNDATION_KEY="2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201"
TX_DATA="{\"jsonrpc\":\"2.0\",\"method\":\"eth_sendTransaction\",\"params\":[{\"from\":\"0x71562b71999873DB5b286dF957af199Ec94617F7\",\"to\":\"$ACCOUNT_ADDRESS\",\"value\":\"0xDE0B6B3A7640000\"}],\"id\":1}"

# Use curl to send the transaction if available
if command -v curl &> /dev/null; then
    echo -e "Sending 1 BRC to $ACCOUNT_ADDRESS..."
    curl -s -X POST -H "Content-Type: application/json" --data "$TX_DATA" http://192.168.1.180:8651 > /dev/null
    echo -e "${GREEN}✓ Transaction sent!${NC}"
else
    echo -e "${YELLOW}curl command not found. You'll need to fund this account manually.${NC}"
fi

echo -e "\n${YELLOW}MetaMask Import Instructions:${NC}"
echo "1. Open MetaMask"
echo "2. Click on your account icon (top-right) then 'Import Account'"
echo "3. Select 'JSON File' option"
echo "4. Browse and select this file: $SIMPLE_KEYSTORE"
echo "5. Enter this password: $PASSWORD"
echo "6. Click Import"
echo
echo -e "${YELLOW}Note:${NC} If MetaMask freezes during import, try these alternatives:"
echo "A) Using a Private Key instead:"
echo "   Run: $BRDPOS account extract-key --keystore $SIMPLE_KEYSTORE"
echo "   Enter the password when prompted."
echo "B) Use our foundation account instead:"
echo "   Private Key: $FOUNDATION_KEY"
echo
echo -e "${GREEN}Your new account is ready!${NC}" 