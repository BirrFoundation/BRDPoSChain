#!/bin/bash

# Check if nodes are running
ps aux | grep BRC | grep -v grep

# Check block progress
for i in $(seq 1 3); do
  BLOCK_NUM=$(../../build/bin/BRC --exec "eth.blockNumber" attach ./tmp/validator$i/BRC.ipc 2>/dev/null || echo "Node not ready")
  echo "Validator $i block number: $BLOCK_NUM"
done
