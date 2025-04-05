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

# Node configuration
NODE_ENDPOINT="http://localhost:8651"
DATADIR="./tmp/brdpos-node-fixed"
BRC_BIN="../../build/bin/BRC"

# Function to print a header
print_header() {
    clear
    echo -e "${BOLD}${CYAN}🔑 BRDPoS Account Manager 🔑${NC}"
    echo -e "${YELLOW}=============================${NC}"
    echo
}

show_menu() {
    print_header
    echo -e "${BOLD}Please select an operation:${NC}"
    echo -e "${CYAN}1)${NC} 🆕 Create New Account"
    echo -e "${CYAN}2)${NC} 📋 List All Accounts"
    echo -e "${CYAN}3)${NC} 💰 Check Account Balance"
    echo -e "${CYAN}4)${NC} 📤 Export Private Key"
    echo -e "${CYAN}5)${NC} 📥 Import Private Key"
    echo -e "${CYAN}6)${NC} 💸 Transfer Funds"
    echo -e "${CYAN}7)${NC} 🛡️ Register as Validator"
    echo -e "${CYAN}0)${NC} 🚪 Exit"
    echo
    echo -e "${YELLOW}Enter your choice [0-7]:${NC} "
    read -r choice
}

create_account() {
    print_header
    echo -e "${BOLD}🆕 Create New Account${NC}\n"
    
    # Ensure the tmp directory exists
    mkdir -p ./tmp
    
    # Check datadir
    if [ ! -d "$DATADIR" ]; then
        echo -e "${YELLOW}⚠️  Data directory not found. Creating...${NC}"
        mkdir -p "$DATADIR/keystore"
    fi
    
    # Ask for password
    echo -e "${CYAN}Please enter a password for the new account:${NC}"
    read -s password
    echo -e "${CYAN}Please confirm password:${NC}"
    read -s password_confirm
    
    if [ "$password" != "$password_confirm" ]; then
        echo -e "\n${RED}❌ Passwords do not match!${NC}"
        return
    fi
    
    # Create temp password file
    echo "$password" > ./tmp/newaccount_pwd.txt
    
    echo -e "\n${CYAN}Creating new account...${NC}"
    
    # Creating new account with full command output for debugging
    ACCOUNT_OUTPUT=$(../../build/bin/BRC account new --datadir "$DATADIR" --password ./tmp/newaccount_pwd.txt 2>&1)
    
    # Print full output for debugging
    echo -e "${CYAN}Command output:${NC}\n$ACCOUNT_OUTPUT"
    
    # Extract address - extract the actual BRC-prefixed address to preserve it
    if [[ "$ACCOUNT_OUTPUT" =~ Public\ address\ of\ the\ key:\ +([a-zA-Z0-9]+) ]]; then
        BRC_ADDR="${BASH_REMATCH[1]}"
        echo -e "${GREEN}✅ New account created successfully!${NC}"
        echo -e "${CYAN}Account Address (with BRC prefix):${NC} ${YELLOW}$BRC_ADDR${NC}"
        
        # Also create the 0x version for compatibility
        if [[ "$BRC_ADDR" =~ ^brc([0-9a-fA-F]{40})$ ]]; then
            ACCOUNT="0x${BASH_REMATCH[1]}"
            echo -e "${CYAN}Account Address (0x format):${NC} ${YELLOW}$ACCOUNT${NC}"
        else
            ACCOUNT="0x${BRC_ADDR#brc}"
            echo -e "${CYAN}Account Address (0x format):${NC} ${YELLOW}$ACCOUNT${NC}"
        fi
        
        # Find keystore file for this account
        KEYSTORE_FILE=$(ls -t "$DATADIR/keystore/" | head -1)
        
        if [ -z "$KEYSTORE_FILE" ]; then
            echo -e "${YELLOW}⚠️  Could not find keystore file.${NC}"
        else
            echo -e "${CYAN}Keystore file:${NC} $KEYSTORE_FILE"
            
            # Copy the keystore file content for use in our custom extraction logic
            cp "$DATADIR/keystore/$KEYSTORE_FILE" ./tmp/latest_keystore.json
        fi
        
        # Offer to extract private key (using a different approach)
        echo -e "\n${CYAN}Would you like to extract the private key? (y/n)${NC}"
        read -r export_key
        
        if [ "$export_key" = "y" ] || [ "$export_key" = "Y" ]; then
            extract_private_key_method2 "$BRC_ADDR" "$password"
        fi
        
        # Ask if user wants to fund this account with test BRC
        echo -e "\n${CYAN}Would you like to fund this account with test BRC? (y/n)${NC}"
        read -r fund_account
        
        if [ "$fund_account" = "y" ] || [ "$fund_account" = "Y" ]; then
            transfer_funds "0x6704fbfcd5ef766b287262fa2281c105d57246a6" "$ACCOUNT" "1000"
        fi
    else
        echo -e "${RED}❌ Failed to extract account address. Raw output:${NC}"
        echo "$ACCOUNT_OUTPUT"
        echo -e "${YELLOW}Please check that the BRC node is properly set up.${NC}"
    fi
    
    # Remove temp password file
    rm ./tmp/newaccount_pwd.txt
}

# Add the new alternative method for extracting private keys
extract_private_key_method2() {
    print_header
    echo -e "${BOLD}🔑 Extracting Private Key (Alternative Method)${NC}\n"
    
    target_account="$1"
    provided_password="$2"
    
    # Convert BRC address to 0x format if needed
    if [[ "$target_account" == brc* ]]; then
        eth_account="0x${target_account#brc}"
    else
        eth_account="$target_account"
    fi
    
    echo -e "${CYAN}Address:${NC} ${YELLOW}$target_account${NC}"
    
    # If latest keystore wasn't prepared, find it
    if [ ! -f "./tmp/latest_keystore.json" ]; then
        KEYSTORE_FILE=$(ls -t "$DATADIR/keystore/" | head -1)
        if [ -n "$KEYSTORE_FILE" ]; then
            cp "$DATADIR/keystore/$KEYSTORE_FILE" ./tmp/latest_keystore.json
        else
            echo -e "${RED}❌ Could not find keystore file.${NC}"
            return
        fi
    fi
    
    # Ask for password if not provided
    if [ -z "$provided_password" ]; then
        echo -e "${CYAN}Enter password for account:${NC}"
        read -s password
    else
        password="$provided_password"
    fi
    
    echo -e "\n${CYAN}Attempting to extract private key...${NC}"
    
    # Create a Python script to extract the private key
    cat > ./tmp/extract_key.py << EOF
import json
import sys
import binascii
from getpass import getpass
import os
import hashlib
from Crypto.Cipher import AES
from Crypto.Util import Counter
from eth_keys import keys
from eth_utils import decode_hex, encode_hex

# Read keystore file
with open('./tmp/latest_keystore.json', 'r') as f:
    keystore = json.load(f)

password = sys.argv[1]
password_bytes = password.encode('utf-8')

# Extract the ciphertext, iv, salt, etc.
ciphertext = decode_hex(keystore['crypto']['ciphertext'])
salt = decode_hex(keystore['crypto']['kdfparams']['salt'])
iv = decode_hex(keystore['crypto']['cipherparams']['iv'])
kdf = keystore['crypto']['kdf']
dklen = keystore['crypto']['kdfparams']['dklen']
n = keystore['crypto']['kdfparams'].get('n', None)
r = keystore['crypto']['kdfparams'].get('r', None)
p = keystore['crypto']['kdfparams'].get('p', None)
c = keystore['crypto']['kdfparams'].get('c', None)

# Derive the key using the appropriate KDF
if kdf == 'pbkdf2':
    derived_key = hashlib.pbkdf2_hmac('sha256', password_bytes, salt, c, dklen)
elif kdf == 'scrypt':
    try:
        import scrypt
        derived_key = scrypt.hash(password_bytes, salt, n, r, p, dklen)
    except ImportError:
        print("Error: scrypt module not available. Install with: pip install scrypt")
        sys.exit(1)
else:
    print(f"Unsupported KDF: {kdf}")
    sys.exit(1)

# Create AES cipher
derived_key_half = derived_key[:16]
cipher = AES.new(derived_key_half, AES.MODE_CTR, counter=Counter.new(128, initial_value=int.from_bytes(iv, byteorder='big')))

# Decrypt private key
private_key_bytes = cipher.decrypt(ciphertext)

# Convert to hex
private_key_hex = "0x" + private_key_bytes.hex()
print(private_key_hex)
EOF

    # Try to install required Python packages if not already installed
    echo -e "${CYAN}Checking for required Python packages...${NC}"
    pip3 install pycryptodome eth-keys eth-utils >/dev/null 2>&1
    
    # Run the Python script
    if command -v python3 &>/dev/null; then
        PRIVATE_KEY=$(python3 ./tmp/extract_key.py "$password" 2>/dev/null)
        
        if [[ $PRIVATE_KEY == 0x* && ${#PRIVATE_KEY} -eq 66 ]]; then
            echo -e "${GREEN}✅ Private key extracted successfully!${NC}"
            echo -e "${CYAN}Private Key:${NC} ${YELLOW}$PRIVATE_KEY${NC}"
            
            # Offer to save to file
            echo -e "\n${CYAN}Would you like to save the private key to a file? (y/n)${NC}"
            read -r save_key
            
            if [ "$save_key" = "y" ] || [ "$save_key" = "Y" ]; then
                echo -e "${CYAN}Enter filename (or press Enter for default):${NC}"
                read -r filename
                
                if [ -z "$filename" ]; then
                    filename="BRDPoS_privatekey_${target_account:3:8}.txt"
                fi
                
                echo "$PRIVATE_KEY" > "$filename"
                echo -e "${GREEN}✅ Private key saved to $filename${NC}"
            fi
        else
            echo -e "${RED}❌ Failed to extract private key with Python. Using fallback method...${NC}"
            hex_dump_method "$target_account" "$password"
        fi
    else
        echo -e "${YELLOW}⚠️ Python 3 not found. Using fallback method...${NC}"
        hex_dump_method "$target_account" "$password"
    fi
    
    # Clean up temporary files
    rm -f ./tmp/extract_key.py
    rm -f ./tmp/latest_keystore.json
}

# Add a more basic fallback method to extract key details through hexdump
hex_dump_method() {
    echo -e "${CYAN}Attempting to extract key details using hexdump...${NC}"
    
    KEYSTORE_FILE=$(ls -t "$DATADIR/keystore/" | head -1)
    if [ -z "$KEYSTORE_FILE" ]; then
        echo -e "${RED}❌ Could not find keystore file.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Found keystore:${NC} $KEYSTORE_FILE"
    
    # Use hexdump to display the raw keystore content
    echo -e "${CYAN}Keystore hex content:${NC}"
    hexdump -C "$DATADIR/keystore/$KEYSTORE_FILE" | head -20
    
    echo -e "\n${YELLOW}⚠️ Could not automatically extract private key.${NC}"
    echo -e "${YELLOW}⚠️ To extract your private key, you can try:${NC}"
    echo -e "  ${GREEN}1.${NC} Use a third-party tool like MyEtherWallet with your keystore file"
    echo -e "  ${GREEN}2.${NC} Copy your keystore file to a secure location:"
    echo -e "     ${MAGENTA}cp $DATADIR/keystore/$KEYSTORE_FILE ~/secure_backup/${NC}"
}

list_accounts() {
    print_header
    echo -e "${BOLD}📋 List All Accounts${NC}\n"
    
    # Check if datadir exists
    if [ ! -d "$DATADIR" ]; then
        echo -e "${RED}❌ Data directory not found.${NC}"
        return
    fi
    
    # Prepare the directory structure
    mkdir -p "$DATADIR/keystore"
    
    # Get accounts with full command output for debugging
    echo -e "${CYAN}Fetching accounts...${NC}"
    ACCOUNT_OUTPUT=$(../../build/bin/BRC account list --datadir "$DATADIR" 2>&1)
    
    # Print the full output for debugging
    echo -e "${CYAN}Raw output:${NC}\n$ACCOUNT_OUTPUT\n"
    
    # Extract accounts with proper handling of BRC prefix
    ACCOUNTS=$(echo "$ACCOUNT_OUTPUT" | grep -E -o '(brc|0x)[0-9a-fA-F]{40}')
    
    if [ -z "$ACCOUNTS" ]; then
        echo -e "${YELLOW}⚠️  No accounts found in the output.${NC}"
        
        # Check if we can find keystore files directly
        KEYSTORE_COUNT=$(find "$DATADIR/keystore" -type f | wc -l)
        if [ "$KEYSTORE_COUNT" -gt 0 ]; then
            echo -e "${CYAN}Found $KEYSTORE_COUNT keystore files. Attempting to extract accounts from filenames...${NC}\n"
            
            for keystore_file in "$DATADIR/keystore"/*; do
                if [ -f "$keystore_file" ]; then
                    # Try to extract the address from the filename
                    FILENAME=$(basename "$keystore_file")
                    if [[ "$FILENAME" =~ --([a-zA-Z0-9]+)$ ]]; then
                        ACCOUNT="${BASH_REMATCH[1]}"
                        
                        # Check if it starts with brc
                        if [[ "$ACCOUNT" == brc* ]]; then
                            echo -e "${GREEN}Found account from keystore:${NC} ${YELLOW}$ACCOUNT${NC}"
                            ACCOUNTS="$ACCOUNTS"$'\n'"$ACCOUNT"
                        else
                            echo -e "${GREEN}Found account from keystore:${NC} ${YELLOW}brc$ACCOUNT${NC}"
                            ACCOUNTS="$ACCOUNTS"$'\n'"brc$ACCOUNT"
                        fi
                    fi
                fi
            done
            
            if [ -z "$ACCOUNTS" ]; then
                echo -e "${RED}❌ Could not extract any accounts from keystore files.${NC}"
                return
            fi
        else
            echo -e "${RED}❌ No keystore files found.${NC}"
            return
        fi
    fi
    
    echo -e "${GREEN}Available Accounts:${NC}\n"
    
    # Print accounts with balances
    index=1
    while IFS= read -r account; do
        # Skip empty lines
        if [ -z "$account" ]; then
            continue
        fi
        
        # Convert brc prefix to 0x for JSON-RPC calls if needed
        eth_account="$account"
        original_account="$account"
        if [[ "$account" == brc* ]]; then
            eth_account="0x${account#brc}"
        fi
        
        echo -e "${CYAN}$index)${NC} ${YELLOW}$original_account${NC}"
        
        # Get balance
        BALANCE_RESULT=$(curl -s -X POST \
            --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$eth_account'", "latest"],"id":1}' \
            -H "Content-Type: application/json" "$NODE_ENDPOINT")
        
        BALANCE_HEX=$(echo "$BALANCE_RESULT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
            
        if [ -n "$BALANCE_HEX" ]; then
            # Convert hex to decimal
            BALANCE_WEI=$((16#${BALANCE_HEX#0x}))
            # Convert wei to BRC (1e18)
            BALANCE_BRC=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
            
            echo -e "   ${GREEN}Balance: $BALANCE_BRC BRC${NC}"
            
            # If this is the validator account, mark it
            VALIDATOR_ADDR="0x6704fbfcd5ef766b287262fa2281c105d57246a6"
            if [[ "$eth_account" == "$VALIDATOR_ADDR" ]]; then
                echo -e "   ${MAGENTA}(Validator Account)${NC}"
            fi
        else
            echo -e "   ${RED}Failed to fetch balance. Response: $BALANCE_RESULT${NC}"
        fi
        
        # Show the keystore file path
        for keystore_file in "$DATADIR/keystore"/*; do
            if grep -q "$account" "$keystore_file" || grep -q "${account#brc}" "$keystore_file" || grep -q "${account#0x}" "$keystore_file"; then
                echo -e "   ${BLUE}Keystore: $(basename "$keystore_file")${NC}"
                break
            fi
        done
        
        echo
        index=$((index + 1))
    done <<< "$ACCOUNTS"
}

check_balance() {
    print_header
    echo -e "${BOLD}💰 Check Account Balance${NC}\n"
    
    echo -e "${CYAN}Enter account address (or leave empty to choose from list):${NC}"
    read -r account
    
    if [ -z "$account" ]; then
        # Get accounts, supporting both 0x and brc prefixes
        ACCOUNTS=$(../../build/bin/BRC account list --datadir "$DATADIR" 2>&1 | grep -E -o '(brc|0x)[0-9a-fA-F]{40}')
        
        if [ -z "$ACCOUNTS" ]; then
            echo -e "${RED}❌ No accounts found.${NC}"
            return
        fi
        
        echo -e "\n${CYAN}Select an account:${NC}"
        
        # Print accounts list
        index=1
        accounts_array=()
        
        while IFS= read -r acc; do
            echo -e "${CYAN}$index)${NC} ${YELLOW}$acc${NC}"
            accounts_array+=("$acc")
            index=$((index + 1))
        done <<< "$ACCOUNTS"
        
        echo
        echo -e "${CYAN}Enter selection:${NC}"
        read -r selection
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#accounts_array[@]} ]; then
            echo -e "${RED}❌ Invalid selection.${NC}"
            return
        fi
        
        account=${accounts_array[$((selection - 1))]}
    fi
    
    # Check if account format is valid (supporting both 0x and brc prefixes)
    if ! [[ "$account" =~ ^(brc|0x)[0-9a-fA-F]{40}$ ]]; then
        echo -e "${RED}❌ Invalid account address format.${NC}"
        return
    fi
    
    # Convert brc prefix to 0x for JSON-RPC calls if needed
    eth_account="$account"
    if [[ "$account" == brc* ]]; then
        eth_account="0x${account#brc}"
    fi
    
    # Get balance
    BALANCE_RESULT=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$eth_account'", "latest"],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT")
        
    BALANCE_HEX=$(echo "$BALANCE_RESULT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        
    if [ -n "$BALANCE_HEX" ]; then
        # Convert hex to decimal
        BALANCE_WEI=$((16#${BALANCE_HEX#0x}))
        # Convert wei to BRC (1e18)
        BALANCE_BRC=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
        
        echo -e "\n${CYAN}Account:${NC} ${YELLOW}$account${NC}"
        if [[ "$account" != "$eth_account" ]]; then
            echo -e "${CYAN}Ethereum format:${NC} ${BLUE}$eth_account${NC}"
        fi
        
        echo -e "${CYAN}Balance:${NC} ${GREEN}$BALANCE_BRC BRC${NC}"
        
        # Get transaction count
        TX_COUNT_HEX=$(curl -s -X POST \
            --data '{"jsonrpc":"2.0","method":"eth_getTransactionCount","params":["'$eth_account'", "latest"],"id":1}' \
            -H "Content-Type: application/json" "$NODE_ENDPOINT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
            
        if [ -n "$TX_COUNT_HEX" ]; then
            TX_COUNT=$((16#${TX_COUNT_HEX#0x}))
            echo -e "${CYAN}Transaction Count:${NC} $TX_COUNT"
        fi
    else
        echo -e "${RED}❌ Failed to fetch balance. Response: $BALANCE_RESULT${NC}"
    fi
}

export_private_key() {
    print_header
    echo -e "${BOLD}📤 Export Private Key${NC}\n"
    
    target_account="$1"
    provided_password="$2"
    
    if [ -z "$target_account" ]; then
        # Get accounts
        ACCOUNTS=$(../../build/bin/BRC account list --datadir "$DATADIR" | grep -E -o '(0x|brc)[0-9a-fA-F]{40}')
        
        if [ -z "$ACCOUNTS" ]; then
            echo -e "${RED}❌ No accounts found.${NC}"
            return
        fi
        
        echo -e "${CYAN}Select an account:${NC}"
        
        # Print accounts list
        index=1
        accounts_array=()
        
        while IFS= read -r acc; do
            # Convert brc prefix to 0x if needed
            if [[ "$acc" == brc* ]]; then
                acc="0x${acc#brc}"
            fi
            echo -e "${CYAN}$index)${NC} ${YELLOW}$acc${NC}"
            accounts_array+=("$acc")
            index=$((index + 1))
        done <<< "$ACCOUNTS"
        
        echo
        echo -e "${CYAN}Enter selection:${NC}"
        read -r selection
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#accounts_array[@]} ]; then
            echo -e "${RED}❌ Invalid selection.${NC}"
            return
        fi
        
        target_account=${accounts_array[$((selection - 1))]}
    fi
    
    # Find keystore file - handle both with and without 0x prefix
    account_addr=${target_account#0x}
    keystore_file=$(find "$DATADIR/keystore/" -type f -name "*.json" | xargs grep -l "$account_addr" | head -1)
    
    if [ -z "$keystore_file" ]; then
        echo -e "${YELLOW}⚠️ Keystore file not found directly. Trying an alternative approach...${NC}"
        # Try listing all files and take the newest one
        keystore_file=$(ls -t "$DATADIR/keystore/" | head -1)
        if [ -n "$keystore_file" ]; then
            keystore_file="$DATADIR/keystore/$keystore_file"
        fi
    fi
    
    if [ -z "$keystore_file" ]; then
        echo -e "${RED}❌ Keystore file not found for account $target_account.${NC}"
        return
    fi
    
    echo -e "${CYAN}Using keystore file:${NC} $keystore_file"
    
    # Ask for password if not provided
    if [ -z "$provided_password" ]; then
        echo -e "${CYAN}Enter password for account:${NC}"
        read -s password
    else
        password="$provided_password"
    fi
    
    # Create temp password file
    echo "$password" > ./tmp/export_pwd.txt
    
    echo -e "\n${CYAN}Exporting private key...${NC}"
    # Export private key with full output for debugging
    EXTRACT_OUTPUT=$(../../build/bin/BRC account extract --keystore "$keystore_file" --password ./tmp/export_pwd.txt 2>&1)
    
    # Print full output for debugging
    echo -e "${CYAN}Command output:${NC}\n$EXTRACT_OUTPUT"
    
    # Try to extract private key in different formats
    if [[ "$EXTRACT_OUTPUT" =~ (0x[0-9a-fA-F]{64}) ]]; then
        privatekey="${BASH_REMATCH[1]}"
    else
        # Try generic extraction of hex strings that could be private keys
        privatekey=$(echo "$EXTRACT_OUTPUT" | grep -o '[0-9a-fA-F]\{64\}' | head -1)
        if [ -n "$privatekey" ]; then
            privatekey="0x$privatekey"
        fi
    fi
    
    # Remove temp password file
    rm ./tmp/export_pwd.txt
    
    if [ -n "$privatekey" ]; then
        echo -e "${GREEN}✅ Private key extracted successfully!${NC}"
        echo -e "${CYAN}Account:${NC} ${YELLOW}$target_account${NC}"
        echo -e "${CYAN}Private Key:${NC} ${YELLOW}$privatekey${NC}"
        
        # Offer to save to file
        echo -e "\n${CYAN}Would you like to save the private key to a file? (y/n)${NC}"
        read -r save_key
        
        if [ "$save_key" = "y" ] || [ "$save_key" = "Y" ]; then
            echo -e "${CYAN}Enter filename (or press Enter for default):${NC}"
            read -r filename
            
            if [ -z "$filename" ]; then
                filename="BRDPoS_privatekey_${account_addr:0:8}.txt"
            fi
            
            echo "$privatekey" > "$filename"
            echo -e "${GREEN}✅ Private key saved to $filename${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to extract private key. Incorrect password or unsupported keystore format.${NC}"
    fi
}

import_private_key() {
    print_header
    echo -e "${BOLD}📥 Import Private Key${NC}\n"
    
    echo -e "${CYAN}Enter private key (with or without 0x prefix):${NC}"
    read -r privatekey
    
    # Validate private key format
    if [ ${#privatekey} -eq 66 ] && [[ $privatekey == 0x* ]]; then
        privatekey=${privatekey#0x}
    elif [ ${#privatekey} -eq 64 ] && [[ $privatekey =~ ^[0-9a-fA-F]+$ ]]; then
        # Valid format without 0x
        :
    else
        echo -e "${RED}❌ Invalid private key format. Must be 64 hexadecimal characters with optional 0x prefix.${NC}"
        return
    fi
    
    # Ask for password
    echo -e "${CYAN}Enter password for the new account:${NC}"
    read -s password
    echo -e "${CYAN}Confirm password:${NC}"
    read -s password_confirm
    
    if [ "$password" != "$password_confirm" ]; then
        echo -e "\n${RED}❌ Passwords do not match!${NC}"
        return
    fi
    
    # Create temp files
    echo "$password" > ./tmp/import_pwd.txt
    echo "0x$privatekey" > ./tmp/import_key.txt
    
    echo -e "\n${CYAN}Importing private key...${NC}"
    # Import private key
    ACCOUNT=$(${BRC_BIN} account import --datadir "$DATADIR" --password ./tmp/import_pwd.txt ./tmp/import_key.txt | grep -o '0x[0-9a-fA-F]*' | grep -o '0x[0-9a-fA-F]*')
    
    # Clean up temp files
    rm ./tmp/import_pwd.txt
    rm ./tmp/import_key.txt
    
    if [ -n "$ACCOUNT" ]; then
        echo -e "${GREEN}✅ Private key imported successfully!${NC}"
        echo -e "${CYAN}Account Address:${NC} ${YELLOW}$ACCOUNT${NC}"
        
        # Ask if user wants to fund this account with test BRC
        echo -e "\n${CYAN}Would you like to fund this account with test BRC? (y/n)${NC}"
        read -r fund_account
        
        if [ "$fund_account" = "y" ] || [ "$fund_account" = "Y" ]; then
            transfer_funds "0x6704fbfcd5ef766b287262fa2281c105d57246a6" "$ACCOUNT" "1000"
        fi
    else
        echo -e "${RED}❌ Failed to import private key.${NC}"
    fi
}

transfer_funds() {
    print_header
    echo -e "${BOLD}💸 Transfer Funds${NC}\n"
    
    from_account="$1"
    to_account="$2"
    amount="$3"
    
    if [ -z "$from_account" ]; then
        # Get accounts, supporting both 0x and brc prefixes
        ACCOUNTS=$(../../build/bin/BRC account list --datadir "$DATADIR" 2>&1 | grep -E -o '(brc|0x)[0-9a-fA-F]{40}')
        
        if [ -z "$ACCOUNTS" ]; then
            echo -e "${RED}❌ No accounts found.${NC}"
            return
        fi
        
        echo -e "${CYAN}Select source account:${NC}"
        
        # Print accounts list with balances
        index=1
        accounts_array=()
        display_accounts=()
        
        while IFS= read -r acc; do
            # Convert brc prefix to 0x for JSON-RPC calls if needed
            eth_account="$acc"
            if [[ "$acc" == brc* ]]; then
                eth_account="0x${acc#brc}"
            fi
            
            # Get balance
            BALANCE_HEX=$(curl -s -X POST \
                --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$eth_account'", "latest"],"id":1}' \
                -H "Content-Type: application/json" "$NODE_ENDPOINT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
                
            if [ -n "$BALANCE_HEX" ]; then
                # Convert hex to decimal
                BALANCE_WEI=$((16#${BALANCE_HEX#0x}))
                # Convert wei to BRC (1e18)
                BALANCE_BRC=$(echo "scale=6; $BALANCE_WEI / 1000000000000000000" | bc)
                
                echo -e "${CYAN}$index)${NC} ${YELLOW}$acc${NC} (${GREEN}$BALANCE_BRC BRC${NC})"
            else
                echo -e "${CYAN}$index)${NC} ${YELLOW}$acc${NC} (${RED}Balance unknown${NC})"
            fi
            
            accounts_array+=("$eth_account")  # Always store the 0x version for JSON-RPC
            display_accounts+=("$acc")        # Store the display version (could be brc or 0x)
            index=$((index + 1))
        done <<< "$ACCOUNTS"
        
        echo
        echo -e "${CYAN}Enter selection:${NC}"
        read -r selection
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#accounts_array[@]} ]; then
            echo -e "${RED}❌ Invalid selection.${NC}"
            return
        fi
        
        from_account=${accounts_array[$((selection - 1))]}
        from_display=${display_accounts[$((selection - 1))]}
    else
        # Convert brc prefix to 0x for JSON-RPC calls if needed
        if [[ "$from_account" == brc* ]]; then
            from_display="$from_account"
            from_account="0x${from_account#brc}"
        else
            from_display="$from_account"
        fi
    fi
    
    if [ -z "$to_account" ]; then
        echo -e "\n${CYAN}Enter destination address:${NC}"
        read -r to_account
        
        # Validate address format (supporting both 0x and brc prefixes)
        if ! [[ "$to_account" =~ ^(brc|0x)[0-9a-fA-F]{40}$ ]]; then
            echo -e "${RED}❌ Invalid destination address format.${NC}"
            return
        fi
    fi
    
    # Convert destination brc prefix to 0x for JSON-RPC calls if needed
    to_display="$to_account"
    if [[ "$to_account" == brc* ]]; then
        to_account="0x${to_account#brc}"
    fi
    
    if [ -z "$amount" ]; then
        echo -e "\n${CYAN}Enter amount in BRC:${NC}"
        read -r amount
        
        # Validate amount format
        if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo -e "${RED}❌ Invalid amount format.${NC}"
            return
        fi
    fi
    
    # Convert BRC to wei (multiply by 10^18)
    amount_wei=$(echo "scale=0; $amount * 1000000000000000000 / 1" | bc)
    # Convert to hex
    amount_hex="0x$(echo "obase=16; $amount_wei" | bc)"
    
    echo -e "\n${CYAN}Transaction Details:${NC}"
    echo -e "${CYAN}From:${NC} ${YELLOW}$from_display${NC}"
    echo -e "${CYAN}To:${NC} ${YELLOW}$to_display${NC}"
    echo -e "${CYAN}Amount:${NC} ${GREEN}$amount BRC${NC}"
    
    echo -e "\n${CYAN}Confirm transaction? (y/n)${NC}"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Transaction cancelled.${NC}"
        return
    fi
    
    echo -e "${CYAN}Sending transaction...${NC}"
    # Send transaction
    TX_RESULT=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'$from_account'","to":"'$to_account'","value":"'$amount_hex'"}],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT")
    
    # Print full result for debugging
    echo -e "${CYAN}Raw response:${NC}\n$TX_RESULT\n"
    
    TX_HASH=$(echo "$TX_RESULT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    ERROR_MSG=$(echo "$TX_RESULT" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        
    if [ -n "$TX_HASH" ]; then
        echo -e "${GREEN}✅ Transaction sent successfully!${NC}"
        echo -e "${CYAN}Transaction Hash:${NC} ${YELLOW}$TX_HASH${NC}"
    else
        echo -e "${RED}❌ Failed to send transaction.${NC}"
        
        if [ -n "$ERROR_MSG" ]; then
            echo -e "${RED}Error:${NC} $ERROR_MSG"
        fi
        
        # Ask if user wants to try unlocking the account
        echo -e "\n${CYAN}Would you like to unlock the account and try again? (y/n)${NC}"
        read -r unlock_account
        
        if [ "$unlock_account" = "y" ] || [ "$unlock_account" = "Y" ]; then
            echo -e "${CYAN}Enter password for account $from_display:${NC}"
            read -s password
            
            # Unlock account
            UNLOCK_RESULT=$(curl -s -X POST \
                --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'$from_account'", "'$password'", 300],"id":1}' \
                -H "Content-Type: application/json" "$NODE_ENDPOINT")
            
            # Print full result for debugging
            echo -e "\n${CYAN}Unlock response:${NC}\n$UNLOCK_RESULT\n"
            
            UNLOCK_SUCCESS=$(echo "$UNLOCK_RESULT" | grep -o '"result":true' || echo "")
                
            if [ -n "$UNLOCK_SUCCESS" ]; then
                echo -e "${GREEN}✅ Account unlocked successfully!${NC}"
                
                echo -e "${CYAN}Sending transaction...${NC}"
                # Send transaction again
                TX_RESULT=$(curl -s -X POST \
                    --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'$from_account'","to":"'$to_account'","value":"'$amount_hex'"}],"id":1}' \
                    -H "Content-Type: application/json" "$NODE_ENDPOINT")
                
                # Print full result for debugging
                echo -e "${CYAN}Raw response:${NC}\n$TX_RESULT\n"
                
                TX_HASH=$(echo "$TX_RESULT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
                    
                if [ -n "$TX_HASH" ]; then
                    echo -e "${GREEN}✅ Transaction sent successfully!${NC}"
                    echo -e "${CYAN}Transaction Hash:${NC} ${YELLOW}$TX_HASH${NC}"
                else
                    ERROR_MSG=$(echo "$TX_RESULT" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
                    echo -e "${RED}❌ Failed to send transaction even after unlocking the account.${NC}"
                    if [ -n "$ERROR_MSG" ]; then
                        echo -e "${RED}Error:${NC} $ERROR_MSG"
                    fi
                fi
            else
                ERROR_MSG=$(echo "$UNLOCK_RESULT" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
                echo -e "${RED}❌ Failed to unlock account.${NC}"
                if [ -n "$ERROR_MSG" ]; then
                    echo -e "${RED}Error:${NC} $ERROR_MSG"
                fi
            fi
        fi
    fi
}

register_validator() {
    print_header
    echo -e "${BOLD}🛡️ Register as Validator${NC}\n"
    
    echo -e "${YELLOW}⚠️  This is a development environment using chain ID 3669.${NC}"
    echo -e "${YELLOW}⚠️  Adding more validators requires modifying the genesis configuration.${NC}"
    echo -e "${YELLOW}⚠️  For now, this will just display information about becoming a validator.${NC}\n"
    
    echo -e "${CYAN}Current Validator:${NC}"
    VALIDATORS=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"BRDPoS_getSigners","params":[null],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
        grep -o '"result":\[[^]]*\]' | grep -o '"0x[^"]*"' | tr -d '"')
        
    if [ -n "$VALIDATORS" ]; then
        echo -e "${YELLOW}$VALIDATORS${NC}"
    else
        echo -e "${RED}❌ Failed to get current validator.${NC}"
    fi
    
    echo -e "\n${CYAN}To become a validator on a real network, you would:${NC}"
    echo -e " ${GREEN}1.${NC} Create an account with sufficient funds"
    echo -e " ${GREEN}2.${NC} Register in the validator smart contract"
    echo -e " ${GREEN}3.${NC} Run a node with the '--mine' flag"
    echo -e " ${GREEN}4.${NC} Authorize your account for signing blocks"
    
    echo -e "\n${CYAN}For testing purposes, you can restart your node with a new validator account.${NC}"
}

# Main program logic
while true; do
    show_menu
    
    case $choice in
        1) create_account ;;
        2) list_accounts ;;
        3) check_balance ;;
        4) export_private_key ;;
        5) import_private_key ;;
        6) transfer_funds ;;
        7) register_validator ;;
        0) 
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option!${NC}"
            sleep 1
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
done 