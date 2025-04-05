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

echo -e "${BOLD}${CYAN}🔑 BRDPoS Private Key Extractor 🔑${NC}"
echo -e "${YELLOW}=================================${NC}\n"

# Check for Python and required modules
echo -e "${CYAN}Checking for required Python modules...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not found! Please install Python 3.${NC}"
    exit 1
fi

# Install required Python modules if needed
MODULES=("pycryptodome" "scrypt" "coincurve")
MISSING_MODULES=()

for module in "${MODULES[@]}"; do
    if ! python3 -c "import $module" &> /dev/null; then
        MISSING_MODULES+=("$module")
    fi
done

if [ ${#MISSING_MODULES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Some required Python modules are missing.${NC}"
    echo -e "${CYAN}Installing required modules...${NC}"
    
    # Create a virtual environment if it doesn't exist
    if [ ! -d "./venv" ]; then
        python3 -m venv ./venv
    fi
    
    # Activate the virtual environment
    source ./venv/bin/activate
    
    # Install the missing modules
    pip install "${MISSING_MODULES[@]}" pycryptodome
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install required modules.${NC}"
        echo -e "${YELLOW}Please try to install them manually:${NC}"
        echo -e "pip install ${MISSING_MODULES[@]} pycryptodome"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Required modules installed successfully.${NC}"
else
    echo -e "${GREEN}✅ All required modules are already installed.${NC}"
fi

DATADIR="./tmp/brdpos-node-fixed"

# Find keystore files
echo -e "\n${CYAN}Looking for keystore files...${NC}"
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
    echo -e "${RED}❌ No keystore files found in $DATADIR/keystore${NC}"
    
    # Check if there are any other keystore files in the tmp directory
    echo -e "${CYAN}Looking for keystore files in ./tmp/new_account...${NC}"
    
    if [ -d "./tmp/new_account" ]; then
        for file in "./tmp/new_account"/keystore_*.json; do
            if [ -f "$file" ]; then
                KEYSTORE_FILES+=("$file")
                FILENAME=$(basename "$file")
                echo -e "${GREEN}$index)${NC} ${YELLOW}$FILENAME${NC}"
                index=$((index + 1))
            fi
        done
    fi
    
    if [ ${#KEYSTORE_FILES[@]} -eq 0 ]; then
        echo -e "${RED}❌ No keystore files found.${NC}"
        exit 1
    fi
fi

# Select keystore
echo -e "\n${CYAN}Select a keystore file (1-${#KEYSTORE_FILES[@]}):${NC}"
read -r selection

if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#KEYSTORE_FILES[@]} ]; then
    echo -e "${RED}❌ Invalid selection.${NC}"
    exit 1
fi

SELECTED_KEYSTORE="${KEYSTORE_FILES[$((selection - 1))]}"
echo -e "\n${GREEN}Selected keystore:${NC} ${YELLOW}$(basename "$SELECTED_KEYSTORE")${NC}"

# Call the Python script to extract the private key
if [ -d "./venv" ]; then
    source ./venv/bin/activate
fi

python3 decrypt-keystore.py "$SELECTED_KEYSTORE"

echo -e "\n${CYAN}Done.${NC}" 