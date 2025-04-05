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

echo -e "${BOLD}${CYAN}🔑 Create Funded Account for MetaMask 🔑${NC}"
echo -e "${YELLOW}====================================${NC}\n"

DATADIR="./tmp/brdpos-node-fixed"
FOUNDATION_ADDR="0x6704fbfcd5ef766b287262fa2281c105d57246a6"
NODE_URL="http://localhost:8651"

# Check if the node is running
if ! pgrep -f "BRC.*--datadir ./tmp/brdpos-node" > /dev/null; then
    echo -e "${RED}❌ BRDPoS node is not running!${NC}"
    echo -e "${YELLOW}Please start the node with:${NC} ./start-brdpos-3669.sh"
    exit 1
fi

# Create a password for the new account
echo -e "${CYAN}Enter a password for your new account:${NC}"
read -s password
echo -e "${CYAN}Confirm password:${NC}"
read -s password_confirm

if [ "$password" != "$password_confirm" ]; then
    echo -e "${RED}❌ Passwords do not match!${NC}"
    exit 1
fi

# Save password to a temporary file
mkdir -p ./tmp/new_account
echo "$password" > ./tmp/new_account/password.txt

echo -e "\n${CYAN}Creating new account...${NC}"
ACCOUNT_OUTPUT=$(../../build/bin/BRC account new --datadir "$DATADIR" --password ./tmp/new_account/password.txt 2>&1)
echo -e "$ACCOUNT_OUTPUT"

# Extract the account address
if [[ "$ACCOUNT_OUTPUT" =~ [pP]ublic.+key:[[:space:]]*([a-zA-Z0-9]+) ]]; then
    ACCOUNT="${BASH_REMATCH[1]}"
    echo -e "\n${GREEN}✅ Extracted raw account:${NC} ${YELLOW}$ACCOUNT${NC}"
elif [[ "$ACCOUNT_OUTPUT" =~ [pP]ublic[[:space:]]*address[[:space:]]*of[[:space:]]*the[[:space:]]*key:[[:space:]]*([a-zA-Z0-9]+) ]]; then
    ACCOUNT="${BASH_REMATCH[1]}"
    echo -e "\n${GREEN}✅ Extracted raw account:${NC} ${YELLOW}$ACCOUNT${NC}"
elif [[ "$ACCOUNT_OUTPUT" =~ \{(brc[a-zA-Z0-9]+)\} ]]; then
    ACCOUNT="${BASH_REMATCH[1]}"
    echo -e "\n${GREEN}✅ Extracted raw account:${NC} ${YELLOW}$ACCOUNT${NC}"
else
    # Manually scan for the address format in the output
    ACCOUNT_PATTERN="brc[a-fA-F0-9]+"
    if [[ "$ACCOUNT_OUTPUT" =~ $ACCOUNT_PATTERN ]]; then
        ACCOUNT="${BASH_REMATCH[0]}"
        echo -e "\n${GREEN}✅ Extracted raw account:${NC} ${YELLOW}$ACCOUNT${NC}"
    else
        echo -e "\n${RED}❌ Failed to extract account address!${NC}"
        echo -e "${YELLOW}Raw output:${NC}\n$ACCOUNT_OUTPUT"
        exit 1
    fi
fi

# Convert to Ethereum format
if [[ "$ACCOUNT" == brc* ]]; then
    ETH_ACCOUNT="0x${ACCOUNT#brc}"
    BRC_ACCOUNT="$ACCOUNT"
else
    ETH_ACCOUNT="0x$ACCOUNT"
    BRC_ACCOUNT="brc$ACCOUNT"
fi

echo -e "${GREEN}✅ Created new account:${NC}"
echo -e "${CYAN}Ethereum format:${NC} ${YELLOW}$ETH_ACCOUNT${NC}"
echo -e "${CYAN}BRC format:${NC} ${YELLOW}$BRC_ACCOUNT${NC}"

# Fund the account with the foundation account
echo -e "\n${CYAN}Funding the new account from foundation...${NC}"

# Unlock foundation account
UNLOCK_RESULT=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'$FOUNDATION_ADDR'", "birrcoin123", 60],"id":1}' \
    -H "Content-Type: application/json" "$NODE_URL")

echo -e "${CYAN}Unlock result:${NC} $UNLOCK_RESULT"

# Send funds to the new account (100,000 BRC)
AMOUNT="0x152d02c7e14af6800000" # 100,000 BRC in wei (100000 * 10^18)
TX_RESULT=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'$FOUNDATION_ADDR'","to":"'$ETH_ACCOUNT'","value":"'$AMOUNT'"}],"id":1}' \
    -H "Content-Type: application/json" "$NODE_URL")

echo -e "${CYAN}Transaction result:${NC} $TX_RESULT"

# Extract the transaction hash
if [[ "$TX_RESULT" =~ \"result\":\"(0x[a-fA-F0-9]+)\" ]]; then
    TX_HASH="${BASH_REMATCH[1]}"
    echo -e "\n${GREEN}✅ Sent 100,000 BRC to your new account!${NC}"
    echo -e "${CYAN}Transaction hash:${NC} ${YELLOW}$TX_HASH${NC}"
else
    echo -e "\n${RED}❌ Failed to send transaction!${NC}"
fi

# Wait for the transaction to be mined
echo -e "\n${CYAN}Waiting for transaction to be mined...${NC}"
sleep 5

# Check the balance
BALANCE_RESULT=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$ETH_ACCOUNT'", "latest"],"id":1}' \
    -H "Content-Type: application/json" "$NODE_URL")

if [[ "$BALANCE_RESULT" =~ \"result\":\"(0x[a-fA-F0-9]+)\" ]]; then
    BALANCE_HEX="${BASH_REMATCH[1]}"
    BALANCE_WEI=$((16#${BALANCE_HEX#0x}))
    BALANCE_BRC=$(echo "scale=2; $BALANCE_WEI / 1000000000000000000" | bc)
    echo -e "\n${GREEN}✅ New account balance:${NC} ${YELLOW}$BALANCE_BRC BRC${NC}"
else
    echo -e "\n${RED}❌ Failed to check balance!${NC}"
fi

# Find the keystore file
echo -e "\n${CYAN}Locating keystore file...${NC}"
KEYSTORE_FILE=""

# Try to find the most recent keystore file
LATEST_KEYSTORE=$(ls -t "$DATADIR/keystore/"* | head -1)

if [ -n "$LATEST_KEYSTORE" ]; then
    KEYSTORE_FILE="$LATEST_KEYSTORE"
    echo -e "${GREEN}✅ Found latest keystore file:${NC} ${YELLOW}$(basename "$KEYSTORE_FILE")${NC}"
else
    # Try searching by address pattern in all keystore files
    for file in "$DATADIR/keystore"/*; do
        # Extract the address from filename pattern
        FILENAME=$(basename "$file")
        if [[ "$FILENAME" =~ --([a-zA-Z0-9]+)$ ]]; then
            FILE_ADDR="${BASH_REMATCH[1]}"
            
            # Compare addresses (with and without prefix)
            if [[ "$ACCOUNT" == *"$FILE_ADDR"* ]] || [[ "$FILE_ADDR" == *"${ACCOUNT#brc}"* ]]; then
                KEYSTORE_FILE="$file"
                echo -e "${GREEN}✅ Found keystore file by address match:${NC} ${YELLOW}$(basename "$KEYSTORE_FILE")${NC}"
                break
            fi
        fi
        
        # Search inside file content as last resort
        if grep -q "${ACCOUNT#brc}" "$file"; then
            KEYSTORE_FILE="$file"
            echo -e "${GREEN}✅ Found keystore file by content match:${NC} ${YELLOW}$(basename "$KEYSTORE_FILE")${NC}"
            break
        fi
    done
fi

if [ -n "$KEYSTORE_FILE" ]; then
    echo -e "\n${GREEN}✅ Found keystore file:${NC} ${YELLOW}$(basename "$KEYSTORE_FILE")${NC}"
    
    # Copy keystore file to a more accessible location
    mkdir -p ./tmp/new_account
    NEW_KEYSTORE="./tmp/new_account/keystore_$(date +"%Y%m%d_%H%M%S").json"
    cp "$KEYSTORE_FILE" "$NEW_KEYSTORE"
    chmod 600 "$NEW_KEYSTORE"
    
    echo -e "\n${GREEN}✅ Copied keystore to:${NC} ${YELLOW}$NEW_KEYSTORE${NC}"
    echo -e "${CYAN}Password is stored in:${NC} ${YELLOW}./tmp/new_account/password.txt${NC}"
else
    echo -e "${RED}❌ Could not find keystore file for the account!${NC}"
fi

# Print MetaMask instructions
echo -e "\n${BOLD}${GREEN}MetaMask Import Instructions:${NC}"
echo -e "1. In MetaMask, click 'Import Account'"
echo -e "2. Select 'JSON File'"
echo -e "3. Browse and select the keystore file: ${YELLOW}$NEW_KEYSTORE${NC}"
echo -e "4. Enter the password you created for this account"
echo -e "5. Click 'Import'"

echo -e "\n${BOLD}${GREEN}Account Information:${NC}"
echo -e "${CYAN}Account Address:${NC} ${YELLOW}$ETH_ACCOUNT${NC}"
echo -e "${CYAN}Keystore File:${NC} ${YELLOW}$NEW_KEYSTORE${NC}"
echo -e "${CYAN}Current Balance:${NC} ${YELLOW}$BALANCE_BRC BRC${NC}"

echo -e "\n${RED}⚠️ IMPORTANT: Keep your password and keystore file secure!${NC}"
echo 