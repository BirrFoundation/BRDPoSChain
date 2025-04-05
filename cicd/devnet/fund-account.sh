#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}BRDPoS Chain Account Funding Tool${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# Foundation account information
FOUNDATION_ADDRESS="0x71562b71999873DB5b286dF957af199Ec94617F7"
RPC_URL="http://192.168.1.180:8651"

# Check if an address was provided
if [ "$1" ]; then
    TARGET_ADDRESS="$1"
    # Remove 'brc' prefix if present
    if [[ "$TARGET_ADDRESS" == brc* ]]; then
        ETH_ADDRESS="0x${TARGET_ADDRESS:3}"
    elif [[ "$TARGET_ADDRESS" == 0x* ]]; then
        ETH_ADDRESS="$TARGET_ADDRESS"
    else
        ETH_ADDRESS="0x$TARGET_ADDRESS"
    fi
else
    # Ask for the address to fund
    echo -e "${YELLOW}Enter the address to fund (with or without 0x prefix):${NC}"
    read INPUT_ADDRESS
    
    # Remove 'brc' prefix if present
    if [[ "$INPUT_ADDRESS" == brc* ]]; then
        ETH_ADDRESS="0x${INPUT_ADDRESS:3}"
    elif [[ "$INPUT_ADDRESS" == 0x* ]]; then
        ETH_ADDRESS="$INPUT_ADDRESS"
    else
        ETH_ADDRESS="0x$INPUT_ADDRESS"
    fi
fi

# Validate the address format
if ! [[ "$ETH_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    echo -e "${RED}Error: Invalid Ethereum address format.${NC}"
    echo "Address should be 40 hexadecimal characters with an optional 0x prefix."
    exit 1
fi

# Ask for amount to send (default: 1 BRC)
echo -e "${YELLOW}Enter amount to send in BRC (default: 1):${NC}"
read AMOUNT
if [ -z "$AMOUNT" ]; then
    AMOUNT="1"
fi

# Convert amount to wei (1 BRC = 10^18 wei)
# For simplicity, we'll just use a predefined value for common amounts
case "$AMOUNT" in
    "0.1")
        WEI_HEX="0x16345785D8A0000" # 0.1 BRC
        ;;
    "0.5")
        WEI_HEX="0x6F05B59D3B20000" # 0.5 BRC
        ;;
    "1")
        WEI_HEX="0xDE0B6B3A7640000" # 1 BRC
        ;;
    "2")
        WEI_HEX="0x1BC16D674EC80000" # 2 BRC
        ;;
    "5")
        WEI_HEX="0x4563918244F40000" # 5 BRC
        ;;
    "10")
        WEI_HEX="0x8AC7230489E80000" # 10 BRC
        ;;
    "100")
        WEI_HEX="0x56BC75E2D63100000" # 100 BRC
        ;;
    *)
        echo -e "${YELLOW}Using default of 1 BRC${NC}"
        WEI_HEX="0xDE0B6B3A7640000" # 1 BRC
        ;;
esac

# Set up the transaction data for sending BRC
TX_DATA="{\"jsonrpc\":\"2.0\",\"method\":\"eth_sendTransaction\",\"params\":[{\"from\":\"$FOUNDATION_ADDRESS\",\"to\":\"$ETH_ADDRESS\",\"value\":\"$WEI_HEX\"}],\"id\":1}"

echo -e "\n${YELLOW}Sending $AMOUNT BRC from foundation account to:${NC}"
echo -e "${BLUE}$ETH_ADDRESS${NC}"

# Use curl to send the transaction
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl command not found.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Sending transaction...${NC}"
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" --data "$TX_DATA" $RPC_URL)

# Check for error in response
if [[ "$RESPONSE" == *"error"* ]]; then
    echo -e "${RED}Error: Transaction failed.${NC}"
    echo -e "Response: $RESPONSE"
    exit 1
fi

# Extract transaction hash
TX_HASH=$(echo "$RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TX_HASH" ]; then
    echo -e "\n${GREEN}✅ Transaction sent successfully!${NC}"
    echo -e "${YELLOW}Transaction Hash:${NC} $TX_HASH"
    
    # Wait a bit and check for receipt
    echo -e "\n${YELLOW}Waiting for transaction confirmation...${NC}"
    sleep 5
    
    # Check transaction receipt
    RECEIPT_DATA="{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}"
    RECEIPT=$(curl -s -X POST -H "Content-Type: application/json" --data "$RECEIPT_DATA" $RPC_URL)
    
    # Check if transaction is confirmed
    if [[ "$RECEIPT" == *"blockNumber"* ]]; then
        BLOCK_NUMBER=$(echo "$RECEIPT" | grep -o '"blockNumber":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✅ Transaction confirmed in block:${NC} $BLOCK_NUMBER"
        echo -e "\n${GREEN}Successfully sent $AMOUNT BRC to:${NC}"
        echo -e "${BLUE}$ETH_ADDRESS${NC}"
    else
        echo -e "${YELLOW}Transaction pending. Check later with:${NC}"
        echo -e "curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}' $RPC_URL"
    fi
else
    echo -e "${RED}Error: Could not get transaction hash.${NC}"
    echo -e "Response: $RESPONSE"
    exit 1
fi

echo -e "\n${YELLOW}You can now import this account into MetaMask and use these funds.${NC}" 