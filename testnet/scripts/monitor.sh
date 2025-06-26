#!/bin/bash

# monitor.sh - Monitor the health of the test network

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODES_DIR="$SCRIPT_DIR/../nodes"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if nodes directory exists
if [ ! -d "$NODES_DIR" ]; then
    echo -e "${RED}Error: No test network found. Run spawn.sh first.${NC}"
    exit 1
fi

# Function to check node status
check_node() {
    local node_id=$1
    local rpc_port=$((8545 + node_id))
    
    # Check if process is running
    if [ -f "$NODES_DIR/node$node_id/node.pid" ]; then
        PID=$(cat "$NODES_DIR/node$node_id/node.pid")
        if ps -p $PID > /dev/null 2>&1; then
            echo -ne "${GREEN}●${NC} Running (PID: $PID)"
        else
            echo -ne "${RED}●${NC} Stopped"
            return
        fi
    else
        echo -ne "${RED}●${NC} No PID file"
        return
    fi
    
    # Try to get block number via RPC
    BLOCK_RESPONSE=$(curl -s -X POST http://localhost:$rpc_port \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null || echo "")
    
    if [ -n "$BLOCK_RESPONSE" ] && echo "$BLOCK_RESPONSE" | grep -q "result"; then
        BLOCK_HEX=$(echo "$BLOCK_RESPONSE" | grep -o '"result":"0x[0-9a-fA-F]*"' | cut -d'"' -f4)
        BLOCK_NUM=$((16#${BLOCK_HEX#0x}))
        echo -ne " | Block: $BLOCK_NUM"
    else
        echo -ne " | ${YELLOW}RPC not responding${NC}"
    fi
    
    # Get peer count
    PEER_RESPONSE=$(curl -s -X POST http://localhost:$rpc_port \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' 2>/dev/null || echo "")
    
    if [ -n "$PEER_RESPONSE" ] && echo "$PEER_RESPONSE" | grep -q "result"; then
        PEER_HEX=$(echo "$PEER_RESPONSE" | grep -o '"result":"0x[0-9a-fA-F]*"' | cut -d'"' -f4)
        PEER_COUNT=$((16#${PEER_HEX#0x}))
        echo -ne " | Peers: $PEER_COUNT"
    fi
}

# Function to show recent logs
show_recent_logs() {
    local node_id=$1
    local log_file="$NODES_DIR/node$node_id/node.log"
    
    if [ -f "$log_file" ]; then
        echo -e "\n${GREEN}Recent logs from node$node_id:${NC}"
        tail -n 5 "$log_file" | sed 's/^/  /'
    fi
}

# Main monitoring loop
clear
echo -e "${GREEN}Reth-Malachite Test Network Monitor${NC}"
echo "======================================="

while true; do
    # Move cursor to top
    tput cup 2 0
    
    # Display header
    echo -e "\n${GREEN}Node Status:${NC}"
    echo "------------"
    
    # Check each node
    NODE_COUNT=0
    for node_dir in "$NODES_DIR"/node*; do
        if [ -d "$node_dir" ]; then
            NODE_ID=$(basename "$node_dir" | sed 's/node//')
            echo -ne "Node $NODE_ID: "
            check_node $NODE_ID
            echo ""
            NODE_COUNT=$((NODE_COUNT + 1))
        fi
    done
    
    # Display summary
    echo -e "\n${GREEN}Network Summary:${NC}"
    echo "----------------"
    echo "Total nodes: $NODE_COUNT"
    echo "Consensus port base: 26656"
    echo "RPC port base: 8545"
    echo "Metrics port base: 9000"
    
    # Display recent consensus activity
    echo -e "\n${GREEN}Recent Consensus Activity:${NC}"
    echo "-------------------------"
    
    # Get latest consensus messages from all nodes
    for node_dir in "$NODES_DIR"/node*; do
        if [ -d "$node_dir" ]; then
            NODE_ID=$(basename "$node_dir" | sed 's/node//')
            LOG_FILE="$node_dir/node.log"
            if [ -f "$LOG_FILE" ]; then
                LATEST=$(grep -E "(StartedRound|DecidedValue|consensus)" "$LOG_FILE" 2>/dev/null | tail -n 1 || echo "")
                if [ -n "$LATEST" ]; then
                    echo "Node $NODE_ID: $(echo "$LATEST" | cut -c1-80)..."
                fi
            fi
        fi
    done
    
    echo -e "\n${GREEN}Commands:${NC}"
    echo "---------"
    echo "Press Ctrl+C to exit monitor"
    echo "Run './spawn.sh clean' to stop all nodes"
    
    # Sleep before refresh
    sleep 2
done