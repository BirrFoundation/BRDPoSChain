#!/bin/bash
set -eo pipefail

if [ ! -d /work/brcchain/BRC/chaindata ]
then
  if test -z "$PRIVATE_KEY"
  then
        echo "PRIVATE_KEY environment variable has not been set."
        exit 1
  fi
  echo $PRIVATE_KEY >> /tmp/key
  wallet=$(BRC account import --password .pwd --datadir /work/brcchain /tmp/key | awk -F '[{}]' '{print $2}')
  BRC --datadir /work/brcchain init /work/genesis.json
else
  wallet=$(BRC account list --datadir /work/brcchain | head -n 1 | awk -F '[{}]' '{print $2}')
fi

input="/work/bootnodes.list"
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

log_level="${LOG_LEVEL:-3}"

port="${PORT:-30303}"

rpc_port="${RPC_PORT:-8545}"

ws_port="${WS_PORT:-8555}"

netstats="${NODE_NAME}-${wallet}:xinfin_BRDPoS_hybrid_network_stats@devnetstats.apothem.network:2000"


echo "Running a node with wallet: ${wallet}"
echo "Starting nodes with $bootnodes ..."

# Note: --gcmode=archive means node will store all historical data. This will lead to high memory usage. But sync mode require archive to sync
# https://BRDPoSChain/issues/268

BRC --ethstats ${netstats} \
--gcmode archive \
--bootnodes ${bootnodes} \
--syncmode full \
--datadir /work/brcchain \
--networkid 551 \
-port $port \
--rpc --rpccorsdomain "*" \
--rpcaddr 0.0.0.0 \
--rpcport $rpc_port \
--rpcapi db,eth,debug,net,shh,txpool,personal,web3,BRDPoS \
--rpcvhosts "*" \
--unlock "${wallet}" \
--password /work/.pwd --mine \
--gasprice "1" --targetgaslimit "420000000" \
--verbosity ${log_level} \
--debugdatadir /work/brcchain \
--ws \
--wsaddr=0.0.0.0 \
--wsport $ws_port \
--wsorigins "*" 2>&1 >>/work/brcchain/brc.log | tee -a /work/brcchain/brc.log
