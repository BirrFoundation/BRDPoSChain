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

# Node HTTP endpoint
NODE_ENDPOINT="http://localhost:8651"

# Function to print a header
print_header() {
    clear
    echo -e "${BOLD}${CYAN}🛠️ BRDPoS Utilities 🛠️${NC}"
    echo -e "${YELLOW}=============================${NC}"
    echo
}

show_menu() {
    print_header
    echo -e "${BOLD}Please select an operation:${NC}"
    echo -e "${CYAN}1)${NC} 🚀 Start BRDPoS Node"
    echo -e "${CYAN}2)${NC} 🔄 Restart BRDPoS Node"
    echo -e "${CYAN}3)${NC} 🛑 Stop BRDPoS Node"
    echo -e "${CYAN}4)${NC} 📊 Monitor BRDPoS Node"
    echo -e "${CYAN}5)${NC} 🗑️  Clean Up All Data"
    echo -e "${CYAN}6)${NC} ℹ️  Node Status"
    echo -e "${CYAN}7)${NC} 📝 View Logs"
    echo -e "${CYAN}8)${NC} 📋 Show Chain Info"
    echo -e "${CYAN}9)${NC} 🔑 Create New Account"
    echo -e "${CYAN}0)${NC} 🚪 Exit"
    echo
    echo -e "${YELLOW}Enter your choice [0-9]:${NC} "
    read -r choice
}

start_node() {
    print_header
    echo -e "${BOLD}🚀 Starting BRDPoS Node...${NC}"
    
    # Check if node is already running
    if pgrep -f "BRC.*--datadir ./tmp/brdpos-node-fixed" > /dev/null; then
        echo -e "${YELLOW}⚠️  Node is already running!${NC}"
        return
    fi
    
    echo -e "${CYAN}Running the node setup script...${NC}"
    chmod +x run-brdpos-node-fixed.sh
    ./run-brdpos-node-fixed.sh
    
    echo -e "\n${GREEN}✅ Node startup initiated!${NC}"
    echo -e "${YELLOW}Use the monitoring tool to check node status.${NC}"
}

restart_node() {
    print_header
    echo -e "${BOLD}🔄 Restarting BRDPoS Node...${NC}"
    
    # Stop node
    stop_node_internal
    
    # Give time for the process to fully terminate
    echo -e "${CYAN}Waiting for node to fully stop...${NC}"
    sleep 3
    
    # Start node
    start_node
}

stop_node_internal() {
    echo -e "${CYAN}Stopping node processes...${NC}"
    pkill -f "BRC.*--datadir ./tmp/brdpos-node-fixed" || true
}

stop_node() {
    print_header
    echo -e "${BOLD}🛑 Stopping BRDPoS Node...${NC}"
    
    # Check if node is running
    if ! pgrep -f "BRC.*--datadir ./tmp/brdpos-node-fixed" > /dev/null; then
        echo -e "${YELLOW}⚠️  No node is currently running!${NC}"
        return
    fi
    
    stop_node_internal
    echo -e "${GREEN}✅ Node stopped successfully!${NC}"
}

monitor_node() {
    if [ -f "./monitor-brdpos.sh" ]; then
        chmod +x ./monitor-brdpos.sh
        ./monitor-brdpos.sh
    else
        print_header
        echo -e "${RED}❌ Monitor script not found!${NC}"
    fi
}

cleanup() {
    print_header
    echo -e "${BOLD}🗑️  Cleaning Up All BRDPoS Data...${NC}"
    
    # Stop running nodes first
    if pgrep -f "BRC.*--datadir ./tmp/brdpos-node" > /dev/null; then
        echo -e "${CYAN}Stopping running nodes first...${NC}"
        pkill -f "BRC.*--datadir ./tmp/brdpos-node" || true
        sleep 2
    fi
    
    echo -e "${CYAN}Removing data directories...${NC}"
    rm -rf ./tmp/brdpos-node*
    rm -f ./tmp/password.txt ./tmp/key.txt ./tmp/brdpos-genesis.json
    
    echo -e "${GREEN}✅ Cleanup completed!${NC}"
}

node_status() {
    print_header
    echo -e "${BOLD}ℹ️  Node Status${NC}"
    
    # Check if node is running
    if pgrep -f "BRC.*--datadir ./tmp/brdpos-node-fixed" > /dev/null; then
        echo -e "${GREEN}✅ BRDPoS node is running!${NC}"
        
        # Get PID and uptime
        PID=$(pgrep -f "BRC.*--datadir ./tmp/brdpos-node-fixed")
        if [ -n "$PID" ]; then
            start_time=$(ps -p "$PID" -o lstart= 2>/dev/null)
            if [ -n "$start_time" ]; then
                echo -e "${CYAN}Process ID:${NC} $PID"
                echo -e "${CYAN}Started at:${NC} $start_time"
            fi
        fi
        
        # Get block number
        BLOCK_HEX=$(curl -s -X POST \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
            grep -o '"result":"[^"]*"' | cut -d'"' -f4)
            
        if [ -n "$BLOCK_HEX" ]; then
            BLOCK_NUM=$((16#${BLOCK_HEX#0x}))
            echo -e "${CYAN}Current Block:${NC} #$BLOCK_NUM"
        else
            echo -e "${YELLOW}⚠️  Could not fetch block number${NC}"
        fi
        
        # Get mining status
        MINING=$(curl -s -X POST \
            --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' \
            -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
            grep -o '"result":[^,}]*' | cut -d':' -f2 | tr -d ' "')
            
        if [ "$MINING" == "true" ]; then
            echo -e "${GREEN}✅ Mining is active${NC}"
        else
            echo -e "${RED}❌ Mining is not active${NC}"
        fi
        
        # Get peer count
        PEER_COUNT_HEX=$(curl -s -X POST \
            --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
            -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
            grep -o '"result":"[^"]*"' | cut -d'"' -f4)
            
        if [ -n "$PEER_COUNT_HEX" ]; then
            PEER_COUNT=$((16#${PEER_COUNT_HEX#0x}))
            echo -e "${CYAN}Connected Peers:${NC} $PEER_COUNT"
        fi
    else
        echo -e "${RED}❌ BRDPoS node is not running!${NC}"
    fi
}

view_logs() {
    print_header
    echo -e "${BOLD}📝 BRDPoS Node Logs${NC}"
    
    LOG_FILE="./tmp/brdpos-node-fixed.log"
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "${CYAN}Showing last 20 lines of logs:${NC}\n"
        tail -n 20 "$LOG_FILE"
        
        echo -e "\n${YELLOW}Options:${NC}"
        echo -e "${CYAN}1)${NC} 📄 View more lines"
        echo -e "${CYAN}2)${NC} 🔄 Refresh current view"
        echo -e "${CYAN}3)${NC} 📥 Follow logs in real-time"
        echo -e "${CYAN}0)${NC} 🔙 Back to main menu"
        
        echo -e "\n${YELLOW}Enter choice:${NC} "
        read -r log_choice
        
        case $log_choice in
            1)
                echo -e "${YELLOW}Enter number of lines to view:${NC} "
                read -r num_lines
                if [[ "$num_lines" =~ ^[0-9]+$ ]]; then
                    print_header
                    echo -e "${BOLD}📝 BRDPoS Node Logs (Last $num_lines Lines)${NC}\n"
                    tail -n "$num_lines" "$LOG_FILE"
                    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                    read -r
                fi
                ;;
            2)
                view_logs
                ;;
            3)
                print_header
                echo -e "${BOLD}📥 Following BRDPoS Node Logs in Real-time${NC}"
                echo -e "${YELLOW}(Press Ctrl+C to stop)${NC}\n"
                tail -f "$LOG_FILE"
                ;;
            0|*)
                # Return to main menu
                ;;
        esac
    else
        echo -e "${RED}❌ Log file not found!${NC}"
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    fi
}

create_new_account() {
    print_header
    echo -e "${BOLD}🔑 Create New Account${NC}"
    
    # Check datadir
    DATADIR="./tmp/brdpos-node-fixed"
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
        echo -e "${RED}❌ Passwords do not match!${NC}"
        return
    fi
    
    # Create temp password file
    echo "$password" > ./tmp/newaccount_pwd.txt
    
    echo -e "\n${CYAN}Creating new account...${NC}"
    # Creating new account
    ACCOUNT=$(../../build/bin/BRC account new --datadir "$DATADIR" --password ./tmp/newaccount_pwd.txt | grep -o '0x[0-9a-fA-F]*')
    
    # Remove temp password file
    rm ./tmp/newaccount_pwd.txt
    
    if [ -n "$ACCOUNT" ]; then
        echo -e "${GREEN}✅ New account created successfully!${NC}"
        echo -e "${CYAN}Account Address:${NC} ${YELLOW}$ACCOUNT${NC}"
        
        # Offer to export private key
        echo -e "\n${CYAN}Would you like to export the private key? (y/n)${NC}"
        read -r export_key
        
        if [ "$export_key" = "y" ] || [ "$export_key" = "Y" ]; then
            # Create temp password file again
            echo "$password" > ./tmp/newaccount_pwd.txt
            
            KEYSTORE_FILE=$(ls -t "$DATADIR/keystore" | head -1)
            if [ -n "$KEYSTORE_FILE" ]; then
                echo -e "${CYAN}Exporting private key...${NC}"
                
                # Export the private key using BRC
                PRIVATE_KEY=$(../../build/bin/BRC account extract --keystore "$DATADIR/keystore/$KEYSTORE_FILE" --password ./tmp/newaccount_pwd.txt | grep -o '0x[0-9a-fA-F]*')
                
                if [ -n "$PRIVATE_KEY" ]; then
                    echo -e "${GREEN}✅ Private key exported successfully!${NC}"
                    echo -e "${CYAN}Private Key:${NC} ${YELLOW}$PRIVATE_KEY${NC}"
                else
                    echo -e "${RED}❌ Failed to export private key.${NC}"
                fi
            else
                echo -e "${RED}❌ Keystore file not found.${NC}"
            fi
            
            # Remove temp password file
            rm ./tmp/newaccount_pwd.txt
        fi
        
        # Ask if user wants to import to node
        echo -e "\n${CYAN}Would you like to fund this account with test BRC? (y/n)${NC}"
        read -r fund_account
        
        if [ "$fund_account" = "y" ] || [ "$fund_account" = "Y" ]; then
            echo -e "${CYAN}Creating funding transaction...${NC}"
            
            # Send transaction from coinbase to new account
            TX_HASH=$(curl -s -X POST \
                --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"0x6704fbfcd5ef766b287262fa2281c105d57246a6","to":"'$ACCOUNT'","value":"0x3635c9adc5dea00000"}],"id":1}' \
                -H "Content-Type: application/json" "$NODE_ENDPOINT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
                
            if [ -n "$TX_HASH" ]; then
                echo -e "${GREEN}✅ Funding transaction sent!${NC}"
                echo -e "${CYAN}Transaction Hash:${NC} ${YELLOW}$TX_HASH${NC}"
                echo -e "${CYAN}Amount:${NC} 1000 BRC"
            else
                echo -e "${RED}❌ Failed to send funding transaction.${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ Failed to create account.${NC}"
    fi
}

show_chain_info() {
    print_header
    echo -e "${BOLD}📋 BRDPoS Chain Information${NC}"
    
    # Check if node is running
    if ! pgrep -f "BRC.*--datadir ./tmp/brdpos-node-fixed" > /dev/null; then
        echo -e "${RED}❌ Node is not running!${NC}"
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
        return
    fi
    
    # Get chain ID
    CHAIN_ID=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
        grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        
    if [ -n "$CHAIN_ID" ]; then
        CHAIN_ID_NUM=$((16#${CHAIN_ID#0x}))
        echo -e "${CYAN}Chain ID:${NC} $CHAIN_ID_NUM"
    fi
    
    # Get network info
    NETWORK_INFO=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"BRDPoS_networkInformation","params":[],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT")
        
    if [ -n "$NETWORK_INFO" ]; then
        PERIOD=$(echo "$NETWORK_INFO" | grep -o '"period":[^,]*' | cut -d':' -f2)
        EPOCH=$(echo "$NETWORK_INFO" | grep -o '"epoch":[^,]*' | cut -d':' -f2)
        REWARD=$(echo "$NETWORK_INFO" | grep -o '"reward":[^,]*' | cut -d':' -f2)
        
        echo -e "${CYAN}Block Period:${NC} $PERIOD seconds"
        echo -e "${CYAN}Epoch Length:${NC} $EPOCH blocks"
        echo -e "${CYAN}Block Reward:${NC} $REWARD tokens"
    fi
    
    # Get current block
    LATEST_BLOCK=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT")
        
    if [ -n "$LATEST_BLOCK" ]; then
        BLOCK_NUMBER_HEX=$(echo "$LATEST_BLOCK" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
        BLOCK_NUMBER=$((16#${BLOCK_NUMBER_HEX#0x}))
        TIMESTAMP_HEX=$(echo "$LATEST_BLOCK" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
        TIMESTAMP=$((16#${TIMESTAMP_HEX#0x}))
        TIMESTAMP_HUMAN=$(date -r "$TIMESTAMP")
        
        echo -e "\n${BOLD}Latest Block Information:${NC}"
        echo -e "${CYAN}Block Number:${NC} #$BLOCK_NUMBER"
        echo -e "${CYAN}Timestamp:${NC} $TIMESTAMP_HUMAN"
        
        # Calculate epoch progress
        if [ -n "$EPOCH" ] && [ "$EPOCH" -gt 0 ]; then
            CURRENT_EPOCH=$((BLOCK_NUMBER / EPOCH))
            EPOCH_PROGRESS=$((BLOCK_NUMBER % EPOCH))
            EPOCH_PERCENT=$((EPOCH_PROGRESS * 100 / EPOCH))
            
            echo -e "${CYAN}Current Epoch:${NC} $CURRENT_EPOCH"
            echo -e "${CYAN}Epoch Progress:${NC} $EPOCH_PROGRESS/$EPOCH blocks ($EPOCH_PERCENT%)"
            
            # Progress bar
            BAR_LENGTH=20
            FILLED_LENGTH=$((BAR_LENGTH * EPOCH_PROGRESS / EPOCH))
            
            BAR="["
            for ((i=0; i<BAR_LENGTH; i++)); do
                if [ $i -lt $FILLED_LENGTH ]; then
                    BAR="${BAR}█"
                else
                    BAR="${BAR}░"
                fi
            done
            BAR="${BAR}]"
            
            echo -e "${GREEN}$BAR${NC}"
        fi
    fi
    
    # Get validator information
    VALIDATORS=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"BRDPoS_getSigners","params":[null],"id":1}' \
        -H "Content-Type: application/json" "$NODE_ENDPOINT" | \
        grep -o '"result":\[[^]]*\]' | grep -o '"0x[^"]*"' | tr -d '"')
        
    if [ -n "$VALIDATORS" ]; then
        echo -e "\n${BOLD}Validator Information:${NC}"
        echo -e "${CYAN}Current Validator:${NC} $VALIDATORS"
    fi
    
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

get_network_info() {
    print_header
    echo -e "${BOLD}🔍 BRDPoS Network Information${NC}\n"
    
    # Get network info
    NET_VERSION=$(curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
        -H "Content-Type: application/json" "http://localhost:8651" | \
        grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        
    if [ -n "$NET_VERSION" ]; then
        echo -e "${CYAN}Network ID:${NC} ${YELLOW}$NET_VERSION${NC}"
        
        if [ "$NET_VERSION" != "3669" ]; then
            echo -e "${RED}⚠️  Warning: Expected network ID 3669!${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to get network ID.${NC}"
    fi
    
    # ... existing code ...
}

# Main program logic
while true; do
    show_menu
    
    case $choice in
        1) start_node ;;
        2) restart_node ;;
        3) stop_node ;;
        4) monitor_node ;;
        5) cleanup ;;
        6) node_status ;;
        7) view_logs ;;
        8) show_chain_info ;;
        9) create_new_account ;;
        0) 
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option!${NC}"
            sleep 1
            ;;
    esac
    
    # If not monitoring (which has its own exit mechanism)
    if [ "$choice" != "4" ]; then
        echo -e "\n${YELLOW}Press Enter to continue...${NC}"
        read -r
    fi
done 