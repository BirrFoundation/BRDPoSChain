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

DATADIR="./tmp/brdpos-node-fixed"
BACKUP_DIR="./backups"

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to print a header
print_header() {
    clear
    echo -e "${BOLD}${CYAN}💾 BRDPoS Keystore Backup/Restore 💾${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo
}

backup_keystore() {
    print_header
    echo -e "${BOLD}📤 Backing Up Keystore Files${NC}\n"
    
    # Check if keystore directory exists
    if [ ! -d "$DATADIR/keystore" ]; then
        echo -e "${RED}❌ Keystore directory not found.${NC}"
        return
    fi
    
    # Check if there are any keystore files
    KEYSTORE_COUNT=$(find "$DATADIR/keystore" -type f | wc -l)
    if [ "$KEYSTORE_COUNT" -eq 0 ]; then
        echo -e "${RED}❌ No keystore files found.${NC}"
        return
    fi
    
    # Create timestamped backup directory
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_PATH="$BACKUP_DIR/keystore_backup_$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"
    
    # Copy all keystore files
    echo -e "${CYAN}Copying keystore files...${NC}"
    cp -v "$DATADIR/keystore"/* "$BACKUP_PATH/"
    
    # Create a metadata file
    echo "Backup created on $(date)" > "$BACKUP_PATH/backup_info.txt"
    echo "Original path: $DATADIR/keystore" >> "$BACKUP_PATH/backup_info.txt"
    
    # Get account addresses
    echo -e "\n${CYAN}Accounts in this backup:${NC}"
    ACCOUNT_COUNT=0
    for file in "$DATADIR/keystore"/*; do
        if [ -f "$file" ]; then
            # Try to extract the address from the filename
            FILENAME=$(basename "$file")
            if [[ "$FILENAME" =~ --([a-zA-Z0-9]+)$ ]]; then
                ACCOUNT="${BASH_REMATCH[1]}"
                echo -e " ${GREEN}$(($ACCOUNT_COUNT + 1))${NC}) ${YELLOW}$ACCOUNT${NC}"
                echo "Account $((ACCOUNT_COUNT + 1)): $ACCOUNT" >> "$BACKUP_PATH/backup_info.txt"
                ACCOUNT_COUNT=$((ACCOUNT_COUNT + 1))
            fi
        fi
    done
    
    echo -e "\n${GREEN}✅ Backup completed successfully!${NC}"
    echo -e "${CYAN}Backup location:${NC} ${YELLOW}$BACKUP_PATH${NC}"
    echo -e "\n${YELLOW}⚠️  Important:${NC} Remember the passwords for your accounts! They are NOT stored in the backup."
}

restore_keystore() {
    print_header
    echo -e "${BOLD}📥 Restoring Keystore Files${NC}\n"
    
    # List available backups
    echo -e "${CYAN}Available backups:${NC}"
    BACKUPS=($(find "$BACKUP_DIR" -type d -name "keystore_backup_*" | sort -r))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${RED}❌ No backups found.${NC}"
        return
    fi
    
    for i in "${!BACKUPS[@]}"; do
        BACKUP_PATH="${BACKUPS[$i]}"
        BACKUP_NAME=$(basename "$BACKUP_PATH")
        TIMESTAMP="${BACKUP_NAME#keystore_backup_}"
        
        # Format timestamp for display
        DISPLAY_DATE=$(echo "$TIMESTAMP" | sed 's/\([0-9]\{8\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2:\3:\4/')
        
        # Count keystore files
        FILE_COUNT=$(find "$BACKUP_PATH" -type f -not -name "backup_info.txt" | wc -l)
        
        echo -e "${CYAN}$((i+1))${NC}) ${YELLOW}$DISPLAY_DATE${NC} - ${GREEN}$FILE_COUNT accounts${NC}"
        
        # Display accounts if info file exists
        if [ -f "$BACKUP_PATH/backup_info.txt" ]; then
            grep "Account" "$BACKUP_PATH/backup_info.txt" | while read -r line; do
                echo -e "   ${BLUE}${line#Account *: }${NC}"
            done
        fi
        
        echo
    done
    
    echo -e "${CYAN}Enter selection (or 0 to cancel):${NC}"
    read -r selection
    
    if [ "$selection" = "0" ]; then
        echo -e "${YELLOW}⚠️  Restore cancelled.${NC}"
        return
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#BACKUPS[@]} ]; then
        echo -e "${RED}❌ Invalid selection.${NC}"
        return
    fi
    
    SELECTED_BACKUP="${BACKUPS[$((selection-1))]}"
    
    echo -e "\n${CYAN}Selected:${NC} ${YELLOW}$(basename "$SELECTED_BACKUP")${NC}"
    echo -e "${RED}⚠️  WARNING:${NC} This will replace all existing keystore files!"
    echo -e "${CYAN}Do you want to continue? (y/n)${NC}"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Restore cancelled.${NC}"
        return
    fi
    
    # Create keystore directory if it doesn't exist
    mkdir -p "$DATADIR/keystore"
    
    # Backup current keystore files if any exist
    CURRENT_FILES=$(find "$DATADIR/keystore" -type f | wc -l)
    if [ "$CURRENT_FILES" -gt 0 ]; then
        TEMP_BACKUP="$BACKUP_DIR/pre_restore_backup_$(date +"%Y%m%d_%H%M%S")"
        echo -e "${CYAN}Backing up current keystore files to:${NC} ${YELLOW}$TEMP_BACKUP${NC}"
        mkdir -p "$TEMP_BACKUP"
        cp -v "$DATADIR/keystore"/* "$TEMP_BACKUP/"
    fi
    
    # Remove current keystore files
    rm -f "$DATADIR/keystore"/*
    
    # Copy backup files to keystore directory
    echo -e "${CYAN}Restoring keystore files...${NC}"
    find "$SELECTED_BACKUP" -type f -not -name "backup_info.txt" -exec cp -v {} "$DATADIR/keystore/" \;
    
    echo -e "\n${GREEN}✅ Keystore files restored successfully!${NC}"
}

export_all_private_keys() {
    print_header
    echo -e "${BOLD}🔑 Export All Private Keys${NC}\n"
    
    # Check if keystore directory exists
    if [ ! -d "$DATADIR/keystore" ]; then
        echo -e "${RED}❌ Keystore directory not found.${NC}"
        return
    fi
    
    # Check if there are any keystore files
    KEYSTORE_COUNT=$(find "$DATADIR/keystore" -type f | wc -l)
    if [ "$KEYSTORE_COUNT" -eq 0 ]; then
        echo -e "${RED}❌ No keystore files found.${NC}"
        return
    fi
    
    echo -e "${CYAN}Found $KEYSTORE_COUNT keystore files.${NC}"
    echo -e "${YELLOW}⚠️ WARNING: This will create a file with all your private keys in plain text!${NC}"
    echo -e "${CYAN}Do you want to continue? (y/n)${NC}"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Export cancelled.${NC}"
        return
    fi
    
    echo -e "${CYAN}Enter password for your accounts:${NC}"
    read -s password
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    EXPORT_FILE="$BACKUP_DIR/private_keys_$TIMESTAMP.txt"
    
    echo "BRDPoS Private Keys Export - $(date)" > "$EXPORT_FILE"
    echo "⚠️ WARNING: KEEP THIS FILE SECURE! Anyone with these private keys can access your accounts!" >> "$EXPORT_FILE"
    echo "=======================================================================" >> "$EXPORT_FILE"
    echo "" >> "$EXPORT_FILE"
    
    SUCCESS_COUNT=0
    
    echo -e "\n${CYAN}Attempting to extract private keys...${NC}"
    
    for keystore_file in "$DATADIR/keystore"/*; do
        if [ -f "$keystore_file" ]; then
            # Try to extract the address from the filename
            FILENAME=$(basename "$keystore_file")
            if [[ "$FILENAME" =~ --([a-zA-Z0-9]+)$ ]]; then
                ACCOUNT="${BASH_REMATCH[1]}"
                
                echo -e "${CYAN}Processing account:${NC} ${YELLOW}$ACCOUNT${NC}"
                
                # Copy the keystore file for extraction
                cp "$keystore_file" ./tmp/export_keystore.json
                
                # Create the Python script for key extraction
                cat > ./tmp/extract_key.py << EOF
import json
import sys
import hashlib
from Crypto.Cipher import AES
from Crypto.Util import Counter
from eth_utils import decode_hex

# Read keystore file
with open('./tmp/export_keystore.json', 'r') as f:
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

                # Run the Python script
                if command -v python3 &>/dev/null; then
                    PRIVATE_KEY=$(python3 ./tmp/extract_key.py "$password" 2>/dev/null)
                    
                    if [[ $PRIVATE_KEY == 0x* && ${#PRIVATE_KEY} -eq 66 ]]; then
                        echo -e "${GREEN}✅ Private key extracted successfully!${NC}"
                        echo "Account: $ACCOUNT" >> "$EXPORT_FILE"
                        echo "Private Key: $PRIVATE_KEY" >> "$EXPORT_FILE"
                        echo "" >> "$EXPORT_FILE"
                        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                    else
                        echo -e "${RED}❌ Failed to extract private key for $ACCOUNT${NC}"
                        echo "Account: $ACCOUNT" >> "$EXPORT_FILE"
                        echo "Private Key: EXTRACTION FAILED" >> "$EXPORT_FILE"
                        echo "" >> "$EXPORT_FILE"
                    fi
                else
                    echo -e "${RED}❌ Python 3 not found. Cannot extract private keys.${NC}"
                    break
                fi
            fi
        fi
    done
    
    # Clean up temporary files
    rm -f ./tmp/extract_key.py
    rm -f ./tmp/export_keystore.json
    
    if [ "$SUCCESS_COUNT" -gt 0 ]; then
        echo -e "\n${GREEN}✅ Successfully extracted $SUCCESS_COUNT private keys!${NC}"
        echo -e "${CYAN}Export file:${NC} ${YELLOW}$EXPORT_FILE${NC}"
        
        # Set restrictive permissions on the export file
        chmod 600 "$EXPORT_FILE"
        
        echo -e "\n${RED}⚠️  WARNING:${NC} Keep this file secure! Anyone with these private keys can access your accounts."
    else
        echo -e "\n${RED}❌ Failed to extract any private keys.${NC}"
        if [ -f "$EXPORT_FILE" ]; then
            rm "$EXPORT_FILE"
        fi
    fi
}

# Display the menu
print_header
echo -e "${BOLD}Please select an operation:${NC}"
echo -e "${CYAN}1)${NC} 💾 Backup Keystore Files"
echo -e "${CYAN}2)${NC} 📂 Restore Keystore Files"
echo -e "${CYAN}3)${NC} 🔑 Export All Private Keys"
echo -e "${CYAN}0)${NC} 🚪 Exit"
echo
echo -e "${YELLOW}Enter your choice [0-3]:${NC} "
read -r choice

case $choice in
    1) backup_keystore ;;
    2) restore_keystore ;;
    3) export_all_private_keys ;;
    0) 
        echo -e "${GREEN}👋 Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid option!${NC}"
        ;;
esac

echo -e "\n${YELLOW}Press Enter to continue...${NC}"
read -r 