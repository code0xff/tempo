#!/bin/bash

# test_transactions.sh - Send transactions to reth nodes and verify they can be queried
# Usage: ./test_transactions.sh [num_nodes]

set -e

# Default values
NUM_NODES=${1:-3}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTNET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Test account with known private key for testing
# This is a well-known test private key - DO NOT use in production
TEST_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
TEST_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# Function to send a test transaction
send_transaction() {
    local port=$1
    local nonce=$2
    local value=$3
    local to_address=$4
    
    # Create transaction data
    local tx_data=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "eth_sendTransaction",
    "params": [{
        "from": "$TEST_ADDRESS",
        "to": "$to_address",
        "value": "$value",
        "gas": "0x5208",
        "gasPrice": "0x3b9aca00",
        "nonce": "$nonce"
    }],
    "id": 1
}
EOF
    )
    
    local response=$(curl -s -X POST http://127.0.0.1:$port \
        -H "Content-Type: application/json" \
        -d "$tx_data" 2>/dev/null || echo "")
    
    if [ -n "$response" ] && echo "$response" | grep -q "result"; then
        echo "$response" | grep -o '"result":"0x[0-9a-fA-F]*"' | cut -d'"' -f4
    else
        error "Failed to send transaction: $response"
        echo ""
    fi
}

# Function to get transaction by hash
get_transaction() {
    local port=$1
    local tx_hash=$2
    
    local response=$(curl -s -X POST http://127.0.0.1:$port \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionByHash\",\"params\":[\"$tx_hash\"],\"id\":1}" 2>/dev/null || echo "")
    
    echo "$response"
}

# Function to get transaction receipt
get_receipt() {
    local port=$1
    local tx_hash=$2
    
    local response=$(curl -s -X POST http://127.0.0.1:$port \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$tx_hash\"],\"id\":1}" 2>/dev/null || echo "")
    
    echo "$response"
}

# Function to import test account
import_account() {
    local port=$1
    
    # First unlock the account if needed
    local unlock_response=$(curl -s -X POST http://127.0.0.1:$port \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"personal_importRawKey\",\"params\":[\"${TEST_PRIVATE_KEY#0x}\",\"password\"],\"id\":1}" 2>/dev/null || echo "")
    
    if echo "$unlock_response" | grep -q "result"; then
        log "Test account imported on port $port"
        return 0
    else
        # Account might already exist, try to unlock it
        local unlock_response=$(curl -s -X POST http://127.0.0.1:$port \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"personal_unlockAccount\",\"params\":[\"$TEST_ADDRESS\",\"password\",300],\"id\":1}" 2>/dev/null || echo "")
        
        if echo "$unlock_response" | grep -q "true"; then
            log "Test account unlocked on port $port"
            return 0
        fi
    fi
    
    # If personal API is not available, we'll need to sign transactions client-side
    log "Note: personal API not available on port $port, will use raw transactions"
    return 1
}

# Function to wait for transaction to be mined
wait_for_transaction() {
    local port=$1
    local tx_hash=$2
    local timeout=$3
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            return 1  # Timeout
        fi
        
        local receipt_response=$(get_receipt $port $tx_hash)
        if echo "$receipt_response" | grep -q "\"transactionHash\":\"$tx_hash\""; then
            # Check if blockNumber exists and is not null
            if echo "$receipt_response" | grep -q "\"blockNumber\":\"0x[0-9a-fA-F]" && \
               ! echo "$receipt_response" | grep -q "\"blockNumber\":null"; then
                return 0  # Transaction mined
            fi
        fi
        
        sleep 1
    done
}

# Main test logic
log "Starting transaction tests on $NUM_NODES nodes..."

# Store transaction hashes
declare -a TX_HASHES

# Generate some test addresses to send to
TEST_TO_ADDRESSES=(
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
)

# Try to import/unlock accounts on all nodes
for i in $(seq 0 $((NUM_NODES - 1))); do
    port=$((8545 + i))
    import_account $port || true
done

# Send transactions from different nodes
log "Sending test transactions..."
tx_count=0

for i in $(seq 0 $((NUM_NODES - 1))); do
    port=$((8545 + i))
    to_address=${TEST_TO_ADDRESSES[$i]}
    value="0x$(printf '%x' $((1000000000000000000 + i * 100000000000000000)))" # 1 + 0.1*i ETH in wei
    nonce="0x$(printf '%x' $tx_count)"
    
    log "Sending transaction from node $i (port $port) to $to_address..."
    tx_hash=$(send_transaction $port $nonce $value $to_address)
    
    if [ -n "$tx_hash" ]; then
        TX_HASHES+=("$tx_hash")
        log "Transaction sent: $tx_hash"
        tx_count=$((tx_count + 1))
    else
        error "Failed to send transaction from node $i"
    fi
    
    # Small delay between transactions
    sleep 1
done

# Wait for transactions to be mined with timeout
log "Waiting for transactions to be mined (timeout: 60s per transaction)..."
for i in "${!TX_HASHES[@]}"; do
    tx_hash="${TX_HASHES[$i]}"
    node_port=$((8545 + i))
    
    log "Waiting for transaction $tx_hash to be mined..."
    if wait_for_transaction $node_port $tx_hash 60; then
        log "  ✓ Transaction $tx_hash has been mined"
    else
        error "  ✗ Transaction $tx_hash was not mined within timeout"
    fi
done

# Verify transactions can be queried from all nodes
log "Verifying transactions can be queried by hash from all nodes..."
success_count=0
total_checks=$((${#TX_HASHES[@]} * NUM_NODES))

for tx_hash in "${TX_HASHES[@]}"; do
    log "Checking transaction $tx_hash..."
    
    for i in $(seq 0 $((NUM_NODES - 1))); do
        port=$((8545 + i))
        
        # Get transaction
        tx_response=$(get_transaction $port $tx_hash)
        if echo "$tx_response" | grep -q "\"hash\":\"$tx_hash\""; then
            log "  ✓ Transaction found on node $i"
            success_count=$((success_count + 1))
            
            # Also check receipt
            receipt_response=$(get_receipt $port $tx_hash)
            if echo "$receipt_response" | grep -q "\"transactionHash\":\"$tx_hash\""; then
                block_num=$(echo "$receipt_response" | grep -o '"blockNumber":"0x[0-9a-fA-F]*"' | cut -d'"' -f4)
                if [ -n "$block_num" ]; then
                    block_dec=$((16#${block_num#0x}))
                    log "  ✓ Receipt found on node $i (block $block_dec)"
                else
                    log "  ✓ Receipt found on node $i"
                fi
            else
                log "  ✗ Receipt not found on node $i"
            fi
        else
            error "  ✗ Transaction NOT found on node $i"
        fi
    done
done

# Report results
log "Transaction test complete!"
log "Successfully verified $success_count out of $total_checks transaction queries"

if [ $success_count -eq $total_checks ]; then
    log "SUCCESS: All transactions can be queried from all nodes"
    exit 0
else
    error "FAILURE: Some transactions could not be queried"
    exit 1
fi