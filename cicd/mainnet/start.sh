#!/bin/bash
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
#check last line since it's not included in "read" command https://stackoverflow.com/questions/12916352/shell-script-read-missing-last-line
if [ -z "${bootnodes}" ]
then
    bootnodes=$line
else
    bootnodes="${bootnodes},$line"
fi

log_level=3
if test -z "$LOG_LEVEL"
then
  echo "Log level not set, default to verbosity of $log_level"
else
  echo "Log level found, set to $LOG_LEVEL"
  log_level=$LOG_LEVEL
fi

port=30303
if test -z "$PORT"
then
  echo "PORT not set, default to $port"
else
  echo "PORT found, set to $PORT"
  port=$PORT
fi

rpc_port=8545
if test -z "$RPC_PORT"
then
  echo "RPC_PORT not set, default to $rpc_port"
else
  echo "RPC_PORT found, set to $RPC_PORT"
  rpc_port=$RPC_PORT
fi

ws_port=8555
if test -z "$WS_PORT"
then
  echo "WS_PORT not set, default to  $ws_port"
else
  echo "WS_PORT found, set to $WS_PORT"
  ws_port=$WS_PORT
fi

INSTANCE_IP=$(curl https://checkip.amazonaws.com)
netstats="${NODE_NAME}-${wallet}-${INSTANCE_IP}:xinfin_BRDPoS_hybrid_network_stats@stats.xinfin.network:3000"

echo "Running a node with wallet: ${wallet} at IP: ${INSTANCE_IP}"
echo "Starting nodes with $bootnodes ..."

# Note: --gcmode=archive means node will store all historical data. This will lead to high memory usage. But sync mode require archive to sync
# https://BRDPoSChain/issues/268

BRC --ethstats ${netstats} --gcmode archive \
--nat extip:${INSTANCE_IP} \
--bootnodes ${bootnodes} --syncmode full \
--datadir /work/brcchain --networkid 50 \
--port $port --http --http-corsdomain "*" --http-addr 0.0.0.0 \
--http-port $rpc_port \
--http-api db,eth,debug,net,shh,txpool,personal,web3,BRDPoS \
--http-vhosts "*" --unlock "${wallet}" --password /work/.pwd --mine \
--miner-gasprice "1" --miner-gaslimit "420000000" --verbosity ${log_level} \
--debugdatadir /work/brcchain \
--store-reward \
--ws --ws-addr=0.0.0.0 --ws-port $ws_port \
--ws-origins "*" 2>&1 >>/work/brcchain/brc.log | tee -a /work/brcchain/brc.log
