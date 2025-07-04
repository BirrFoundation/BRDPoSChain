#!/bin/bash

if [ ! -d ./tmp/brcchain ]
then
  echo "Creating a temporary directory for storing the brcchain"
  mkdir tmp
  mkdir -p ./tmp/brcchain
  touch ./tmp/.pwd
  
  # Randomly select a key from environment variable, seperated by ','
  if test -z "$PRIVATE_KEYS" 
  then
        echo "PRIVATE_KEYS environment variable has not been set. Please run again with `export PRIVATE_KEYS={{your key}} && make BRC-devnet-local`"
        exit 1
  fi
  IFS=', ' read -r -a private_keys <<< "$PRIVATE_KEYS"
  private_key=${private_keys[ $RANDOM % ${#private_keys[@]} ]}

  echo "${private_key}" >> ./tmp/key
  echo "Creating a new wallet"
  wallet=$(../../build/bin/BRC account import --password ./tmp/.pwd --datadir ./tmp/brcchain ./tmp/key | sed -n 's/Address: {\(.*\)}/\1/p')
  ../../build/bin/BRC --datadir ./tmp/brcchain init ./genesis.json
else
  echo "Wallet already exist, re-use the same one. If you have changed the private key, please manually inspect the key if matches. Otherwise, delete the 'tmp' directory and start again!"
  wallet=$(../../build/bin/BRC account list --datadir ./tmp/brcchain | head -n 1 | grep -o '{[^}]*}' | tr -d '{}')
fi

input="./bootnodes.list"
bootnodes=""
while IFS= read -r line
do
    if [ -z "${bootnodes}" ]
    then
        bootnodes=$line
    else
        bootnodes="${bootnodes},$line"
    fi
done < "$input"

log_level=3
if test -z "$LOG_LEVEL" 
then
  echo "Log level not set, default to verbosity of 3"
else
  echo "Log level found, set to $LOG_LEVEL"
  log_level=$LOG_LEVEL
fi

netstats="${NODE_NAME}-${wallet}-local:xinfin_BRDPoS_hybrid_network_stats@devnetstats.hashlabs.apothem.network:1999"

echo "Running a node with wallet: ${wallet} at local"

# Set the wallet address as the coinbase (mining reward address)
echo "Setting coinbase address to: ${wallet}"

# Run the node in the foreground and tee output to both console and log file
../../build/bin/BRC --ethstats ${netstats} --gcmode=archive \
--bootnodes ${bootnodes} --syncmode full \
--datadir ./tmp/brcchain --networkid 551 \
--port 30303 --http --http-corsdomain "*" --http-addr 0.0.0.0 \
--http-port 8545 \
--http-api db,eth,debug,miner,net,shh,txpool,personal,web3,BRDPoS \
--http-vhosts "*" --unlock "${wallet}" --password ./tmp/.pwd --mine \
--etherbase "${wallet}" --miner-gasprice "1" --miner-gaslimit "420000000" \
--verbosity ${log_level} --nodiscover=false --maxpeers=50 \
--ws --ws-addr=0.0.0.0 --ws-port 8555 \
--ws-origins "*" 2>&1 | tee ./tmp/brc.log
