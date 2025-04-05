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

echo -e "${BOLD}${CYAN}🔑 BRDPoS Private Key Extractor for MetaMask 🔑${NC}"
echo -e "${YELLOW}===============================================${NC}\n"

# Check if keystore directory exists
if [ ! -d "$DATADIR/keystore" ]; then
    echo -e "${RED}❌ Keystore directory not found.${NC}"
    exit 1
fi

# List keystores
echo -e "${CYAN}Found keystore files:${NC}"
KEYSTORE_FILES=()
index=1

for file in "$DATADIR/keystore"/*; do
    if [ -f "$file" ]; then
        KEYSTORE_FILES+=("$file")
        FILENAME=$(basename "$file")
        
        # Try to extract address from filename
        if [[ "$FILENAME" =~ --([a-zA-Z0-9]+)$ ]]; then
            ADDRESS="${BASH_REMATCH[1]}"
            echo -e "${GREEN}$index)${NC} ${YELLOW}$ADDRESS${NC} - $FILENAME"
        else
            echo -e "${GREEN}$index)${NC} ${YELLOW}$FILENAME${NC}"
        fi
        
        index=$((index + 1))
    fi
done

if [ ${#KEYSTORE_FILES[@]} -eq 0 ]; then
    echo -e "${RED}❌ No keystore files found.${NC}"
    exit 1
fi

# Select keystore if multiple
if [ ${#KEYSTORE_FILES[@]} -gt 1 ]; then
    echo -e "\n${CYAN}Select a keystore (1-${#KEYSTORE_FILES[@]}):${NC}"
    read -r selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#KEYSTORE_FILES[@]} ]; then
        echo -e "${RED}❌ Invalid selection.${NC}"
        exit 1
    fi
    
    SELECTED_KEYSTORE="${KEYSTORE_FILES[$((selection - 1))]}"
else
    SELECTED_KEYSTORE="${KEYSTORE_FILES[0]}"
fi

echo -e "\n${CYAN}Selected keystore:${NC} ${YELLOW}$(basename "$SELECTED_KEYSTORE")${NC}"

# Get password
echo -e "\n${CYAN}Enter password for the keystore:${NC}"
read -s password

# Create extraction directory
mkdir -p ./tmp/extraction

# Create Python script for extraction
cat > ./tmp/extraction/extract.py << EOF
import json
import sys
import hashlib
from Crypto.Cipher import AES
from Crypto.Util import Counter
from binascii import hexlify, unhexlify

def extract_private_key(keystore_file, password):
    # Read keystore file
    with open(keystore_file, 'r') as f:
        keystore = json.load(f)
    
    password_bytes = password.encode('utf-8')
    
    # Get keystore params
    kdf = keystore['crypto']['kdf']
    kdf_params = keystore['crypto']['kdfparams']
    
    # Get derived key
    if kdf == 'pbkdf2':
        derived_key = hashlib.pbkdf2_hmac(
            'sha256', 
            password_bytes, 
            unhexlify(kdf_params['salt']), 
            kdf_params['c'], 
            kdf_params['dklen']
        )
    elif kdf == 'scrypt':
        # You would need the scrypt library for this
        # pip install scrypt
        try:
            import scrypt
            derived_key = scrypt.hash(
                password_bytes,
                unhexlify(kdf_params['salt']),
                kdf_params['n'],
                kdf_params['r'],
                kdf_params['p'],
                kdf_params['dklen']
            )
        except ImportError:
            print("Error: scrypt module not available. Install with: pip install scrypt")
            sys.exit(1)
    else:
        print(f"Unsupported KDF: {kdf}")
        sys.exit(1)
    
    # Check derived key if MAC is present
    ciphertext = unhexlify(keystore['crypto']['ciphertext'])
    mac = keystore['crypto']['mac']
    
    # Verify MAC before trying to decrypt
    derived_mac = hashlib.sha3_256(derived_key[16:32] + ciphertext).hexdigest()
    if derived_mac != mac:
        print("Error: Invalid password or corrupt keystore file")
        sys.exit(1)
    
    # Get decryption key and params
    decryption_key = derived_key[:16]
    
    # Get cipher params
    iv = unhexlify(keystore['crypto']['cipherparams']['iv'])
    
    # Create cipher and decrypt
    cipher = AES.new(decryption_key, AES.MODE_CTR, counter=Counter.new(128, initial_value=int.from_bytes(iv, byteorder='big')))
    private_key = cipher.decrypt(ciphertext)
    
    # Return private key as hex string
    return private_key.hex()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python extract.py <keystore_file> <password>")
        sys.exit(1)
    
    keystore_file = sys.argv[1]
    password = sys.argv[2]
    
    try:
        private_key = extract_private_key(keystore_file, password)
        print(private_key)
    except Exception as e:
        print(f"Error extracting private key: {e}")
        sys.exit(1)
EOF

# Run extraction script
if command -v python3 >/dev/null 2>&1; then
    echo -e "\n${CYAN}Attempting to extract private key...${NC}"
    PRIVATE_KEY=$(python3 ./tmp/extraction/extract.py "$SELECTED_KEYSTORE" "$password" 2>/dev/null)
    EXTRACTION_STATUS=$?
    
    if [ $EXTRACTION_STATUS -eq 0 ] && [ ${#PRIVATE_KEY} -eq 64 ]; then
        echo -e "\n${GREEN}✅ Successfully extracted private key!${NC}"
        echo -e "\n${CYAN}Private Key (for MetaMask):${NC}\n"
        echo -e "${YELLOW}$PRIVATE_KEY${NC}"
        echo -e "\n${RED}⚠️ IMPORTANT: Store this key securely! Anyone with this key has access to your funds.${NC}"
        
        # Save to file
        echo -e "\n${CYAN}Would you like to save this key to a file? (y/n)${NC}"
        read -r save_to_file
        
        if [ "$save_to_file" = "y" ] || [ "$save_to_file" = "Y" ]; then
            KEY_FILE="./tmp/extraction/private_key_$(date +"%Y%m%d_%H%M%S").txt"
            echo "$PRIVATE_KEY" > "$KEY_FILE"
            chmod 600 "$KEY_FILE"
            echo -e "${GREEN}✅ Private key saved to:${NC} ${YELLOW}$KEY_FILE${NC}"
        fi
    else
        echo -e "\n${RED}❌ Failed to extract private key.${NC}"
        
        # Try alternative method using NodeJS
        if command -v node >/dev/null 2>&1; then
            echo -e "\n${CYAN}Trying alternative extraction method (Node.js)...${NC}"
            
            # Create NodeJS script
            cat > ./tmp/extraction/extract.js << EOF
const fs = require('fs');
const crypto = require('crypto');

// Read keystore file
const keystore = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const password = process.argv[3];

// Extract parameters
const kdf = keystore.crypto.kdf;
const kdfparams = keystore.crypto.kdfparams;
const ciphertext = Buffer.from(keystore.crypto.ciphertext, 'hex');
const iv = Buffer.from(keystore.crypto.cipherparams.iv, 'hex');
const salt = Buffer.from(kdfparams.salt, 'hex');
const dklen = kdfparams.dklen;

// Derive key
let derivedKey;
if (kdf === 'pbkdf2') {
    derivedKey = crypto.pbkdf2Sync(
        Buffer.from(password), 
        salt, 
        kdfparams.c, 
        dklen, 
        'sha256'
    );
} else if (kdf === 'scrypt') {
    // Node.js doesn't have native scrypt with these parameters
    console.error('Scrypt KDF not supported in this script');
    process.exit(1);
} else {
    console.error('Unsupported KDF:', kdf);
    process.exit(1);
}

// Check MAC
const mac = crypto.createHash('sha3-256')
    .update(Buffer.concat([derivedKey.slice(16, 32), ciphertext]))
    .digest('hex');

if (mac !== keystore.crypto.mac) {
    console.error('Invalid password or corrupt keystore');
    process.exit(1);
}

// Decrypt
const decipher = crypto.createDecipheriv(
    'aes-128-ctr',
    derivedKey.slice(0, 16),
    iv
);

const privateKey = Buffer.concat([
    decipher.update(ciphertext),
    decipher.final()
]);

console.log(privateKey.toString('hex'));
EOF
            
            PRIVATE_KEY=$(node ./tmp/extraction/extract.js "$SELECTED_KEYSTORE" "$password" 2>/dev/null)
            EXTRACTION_STATUS=$?
            
            if [ $EXTRACTION_STATUS -eq 0 ] && [ ${#PRIVATE_KEY} -eq 64 ]; then
                echo -e "\n${GREEN}✅ Successfully extracted private key with Node.js!${NC}"
                echo -e "\n${CYAN}Private Key (for MetaMask):${NC}\n"
                echo -e "${YELLOW}$PRIVATE_KEY${NC}"
                echo -e "\n${RED}⚠️ IMPORTANT: Store this key securely! Anyone with this key has access to your funds.${NC}"
                
                # Save to file
                echo -e "\n${CYAN}Would you like to save this key to a file? (y/n)${NC}"
                read -r save_to_file
                
                if [ "$save_to_file" = "y" ] || [ "$save_to_file" = "Y" ]; then
                    KEY_FILE="./tmp/extraction/private_key_$(date +"%Y%m%d_%H%M%S").txt"
                    echo "$PRIVATE_KEY" > "$KEY_FILE"
                    chmod 600 "$KEY_FILE"
                    echo -e "${GREEN}✅ Private key saved to:${NC} ${YELLOW}$KEY_FILE${NC}"
                fi
            else
                echo -e "\n${RED}❌ Failed to extract with Node.js as well.${NC}"
                echo -e "${YELLOW}Trying one more approach...${NC}"
                
                # Use BRC's built-in account tools if available
                if [ -f "../../build/bin/BRC" ]; then
                    echo -e "\n${CYAN}Trying BRC's built-in tools...${NC}"
                    
                    # Extract address from keystore filename
                    FILENAME=$(basename "$SELECTED_KEYSTORE")
                    if [[ "$FILENAME" =~ --([a-zA-Z0-9]+)$ ]]; then
                        ADDRESS="${BASH_REMATCH[1]}"
                        
                        if [[ "$ADDRESS" == brc* ]]; then
                            ADDRESS="0x${ADDRESS#brc}"
                        else
                            ADDRESS="0x$ADDRESS"
                        fi
                        
                        echo -e "${CYAN}Extracted address:${NC} ${YELLOW}$ADDRESS${NC}"
                        echo "$password" > ./tmp/extraction/pwd.txt
                        
                        echo -e "${CYAN}Attempting BRC account extraction...${NC}"
                        KEY_OUTPUT=$(cd ../.. && ./build/bin/BRC account extract --keystore "$SELECTED_KEYSTORE" --password ./cicd/devnet/tmp/extraction/pwd.txt 2>/dev/null)
                        
                        if [[ "$KEY_OUTPUT" =~ 0x([0-9a-fA-F]{64}) ]]; then
                            PRIVATE_KEY="${BASH_REMATCH[1]}"
                            echo -e "\n${GREEN}✅ Successfully extracted private key with BRC tools!${NC}"
                            echo -e "\n${CYAN}Private Key (for MetaMask):${NC}\n"
                            echo -e "${YELLOW}$PRIVATE_KEY${NC}"
                            echo -e "\n${RED}⚠️ IMPORTANT: Store this key securely! Anyone with this key has access to your funds.${NC}"
                            
                            # Save to file
                            echo -e "\n${CYAN}Would you like to save this key to a file? (y/n)${NC}"
                            read -r save_to_file
                            
                            if [ "$save_to_file" = "y" ] || [ "$save_to_file" = "Y" ]; then
                                KEY_FILE="./tmp/extraction/private_key_$(date +"%Y%m%d_%H%M%S").txt"
                                echo "$PRIVATE_KEY" > "$KEY_FILE"
                                chmod 600 "$KEY_FILE"
                                echo -e "${GREEN}✅ Private key saved to:${NC} ${YELLOW}$KEY_FILE${NC}"
                            fi
                        else
                            echo -e "\n${RED}❌ Failed to extract with BRC tools.${NC}"
                            echo -e "${YELLOW}Last resort - trying direct decryption of the keystore file...${NC}"
                            
                            # Just output the keystore file for manual extraction
                            echo -e "\n${CYAN}Keystore content:${NC}"
                            cat "$SELECTED_KEYSTORE"
                            echo
                            echo -e "${YELLOW}You can try using an online Ethereum keystore extraction tool with the above content and your password.${NC}"
                        fi
                    else
                        echo -e "\n${RED}❌ Could not extract address from keystore filename.${NC}"
                    fi
                else
                    echo -e "\n${RED}❌ BRC binary not found.${NC}"
                fi
            fi
        else
            echo -e "\n${YELLOW}Node.js not found. Trying basic keystore inspection...${NC}"
            
            # Just output the keystore file for manual extraction
            echo -e "\n${CYAN}Keystore content:${NC}"
            cat "$SELECTED_KEYSTORE"
            echo
            echo -e "${YELLOW}You can try using an online Ethereum keystore extraction tool with the above content and your password.${NC}"
        fi
    fi
else
    echo -e "\n${RED}❌ Python 3 not found. Cannot extract private key.${NC}"
    
    # Just output the keystore file for manual extraction
    echo -e "\n${CYAN}Keystore content:${NC}"
    cat "$SELECTED_KEYSTORE"
    echo
    echo -e "${YELLOW}You can try using an online Ethereum keystore extraction tool with the above content and your password.${NC}"
fi

# Clean up
rm -rf ./tmp/extraction/extract.py ./tmp/extraction/extract.js ./tmp/extraction/pwd.txt

echo -e "\n${CYAN}Done.${NC}" 