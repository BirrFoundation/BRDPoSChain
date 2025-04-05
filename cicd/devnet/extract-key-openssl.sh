#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}BRDPoS Chain Private Key Extractor (Node.js)${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed.${NC}"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

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
    echo "$((i+1)). $(basename "${KEYSTORE_FILES[$i]}")"
done
echo

# Ask user to select a keystore file
read -p "Select a keystore file (number): " selection
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#KEYSTORE_FILES[@]} ]; then
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

SELECTED_FILE="${KEYSTORE_FILES[$((selection-1))]}"
echo -e "Selected: ${BLUE}$(basename "$SELECTED_FILE")${NC}"

# Ask for the password
read -s -p "Enter password for keystore: " PASSWORD
echo

# Create a temporary Node.js script to decrypt the keystore
TMP_SCRIPT=$(mktemp)
cat > "$TMP_SCRIPT" <<'EOF'
const fs = require('fs');
const crypto = require('crypto');

// Get command line arguments
const keystoreFile = process.argv[2];
const password = process.argv[3];

try {
    // Read the keystore file
    const keystore = JSON.parse(fs.readFileSync(keystoreFile, 'utf8'));
    
    // Handle different key formats
    const cryptoObj = keystore.crypto || keystore.Crypto;
    if (!cryptoObj) {
        console.error('Error: Invalid keystore format - no crypto object found');
        process.exit(1);
    }
    
    // Get KDF parameters
    const kdf = cryptoObj.kdf;
    const kdfparams = cryptoObj.kdfparams;
    
    // Convert hex strings to buffers
    const salt = Buffer.from(kdfparams.salt, 'hex');
    const iv = Buffer.from(cryptoObj.cipherparams.iv, 'hex');
    const ciphertext = Buffer.from(cryptoObj.ciphertext, 'hex');
    
    // Derive key based on KDF
    let derivedKey;
    if (kdf === 'pbkdf2') {
        derivedKey = crypto.pbkdf2Sync(
            Buffer.from(password),
            salt,
            kdfparams.c,
            kdfparams.dklen,
            'sha256'
        );
    } else if (kdf === 'scrypt') {
        // For scrypt, we'll use Node's crypto.scryptSync
        derivedKey = crypto.scryptSync(
            Buffer.from(password),
            salt,
            kdfparams.dklen,
            {
                N: kdfparams.n,
                r: kdfparams.r,
                p: kdfparams.p,
                maxmem: 128 * kdfparams.n * kdfparams.r
            }
        );
    } else {
        console.error(`Error: Unsupported KDF: ${kdf}`);
        process.exit(1);
    }
    
    // Verify the derived key with MAC
    const mac = crypto.createHash('sha3-256')
        .update(Buffer.concat([derivedKey.slice(16, 32), ciphertext]))
        .digest('hex');
    
    if (mac !== cryptoObj.mac) {
        console.error('Error: Invalid password or corrupt keystore');
        process.exit(1);
    }
    
    // Decrypt the private key
    const decipher = crypto.createDecipheriv(
        'aes-128-ctr',
        derivedKey.slice(0, 16),
        iv
    );
    
    const privateKey = Buffer.concat([
        decipher.update(ciphertext),
        decipher.final()
    ]);
    
    // Print the private key
    console.log('\nPrivate key extracted successfully:');
    console.log(privateKey.toString('hex'));
    
    // Display address
    let address = keystore.address;
    if (address.startsWith('0x')) {
        address = address.slice(2);
    }
    
    console.log(`\nCorresponding address: 0x${address}`);
    if (!address.startsWith('brc')) {
        console.log(`BRC format: brc${address}`);
    }
    
} catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
}
EOF

# Run the Node.js script to extract the private key
echo -e "\n${YELLOW}Attempting to extract private key...${NC}"
node "$TMP_SCRIPT" "$SELECTED_FILE" "$PASSWORD"

# Clean up
rm "$TMP_SCRIPT"

# Provide import instructions
echo -e "\n${YELLOW}To import this account into MetaMask:${NC}"
echo "1. Open MetaMask"
echo "2. Click on your account icon (top-right) then 'Import Account'"
echo "3. Select 'Private Key' method"
echo "4. Paste the private key (without 0x prefix)"
echo "5. Click 'Import'"
echo
echo "Make sure you're connected to the BRDPoS Chain network (Chain ID: 3669)" 