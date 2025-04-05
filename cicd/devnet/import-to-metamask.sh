#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}BRDPoS Chain MetaMask Import Helper${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# Search for keystore files
KEYSTORE_DIR="./tmp/brdpos-node-fixed/keystore"
if [ ! -d "$KEYSTORE_DIR" ]; then
    echo -e "${RED}Error: Keystore directory not found: $KEYSTORE_DIR${NC}"
    exit 1
fi

# Find all keystore files
KEYSTORE_FILES=()
while IFS= read -r -d $'\0' file; do
    KEYSTORE_FILES+=("$file")
done < <(find "$KEYSTORE_DIR" -name "UTC--*" -type f -print0)

if [ ${#KEYSTORE_FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No keystore files found in $KEYSTORE_DIR${NC}"
    exit 1
fi

# Display keystore files
echo -e "${YELLOW}Found keystore files:${NC}"
for i in "${!KEYSTORE_FILES[@]}"; do
    FILENAME=$(basename "${KEYSTORE_FILES[$i]}")
    ADDRESS=$(echo "$FILENAME" | grep -o -E '[a-fA-F0-9]{40}')
    if [[ "$ADDRESS" == brc* ]]; then
        ADDRESS=${ADDRESS:3}  # Remove brc prefix if present
    fi
    echo "$((i+1)). $FILENAME (0x$ADDRESS)"
done
echo

# Ask user to select a keystore file
read -p "Select a keystore file (number): " selection
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#KEYSTORE_FILES[@]} ]; then
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

SELECTED_FILE="${KEYSTORE_FILES[$((selection-1))]}"
FILENAME=$(basename "$SELECTED_FILE")
echo -e "Selected: ${BLUE}$FILENAME${NC}"

# Ask for the password
read -s -p "Enter your password for this account: " PASSWORD
echo

# Save password to a file for reference
PASSWORD_FILE="account_password.txt"
echo "$PASSWORD" > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

echo -e "\n${GREEN}✓ Account information prepared for MetaMask import${NC}"
echo -e "\n${YELLOW}To import this account into MetaMask using JSON method:${NC}"
echo "1. Open MetaMask"
echo "2. Click on your account icon (top-right) then 'Import Account'"
echo "3. Select 'JSON File' method"
echo "4. Browse to this location and select: $SELECTED_FILE"
echo "5. Enter the password you just provided when prompted"
echo "6. Click 'Import'"
echo
echo "Your password has been saved to: $PASSWORD_FILE"
echo "⚠️ Keep this file secure and delete it when no longer needed!"
echo
echo "Make sure you're connected to the BRDPoS Chain network (Chain ID: 3669)"

# Offer copy path to clipboard if pbcopy is available
if command -v pbcopy > /dev/null; then
    echo "$SELECTED_FILE" | pbcopy
    echo -e "\n${GREEN}✓ Keystore path copied to clipboard!${NC}"
fi 