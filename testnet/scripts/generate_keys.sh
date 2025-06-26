#!/bin/bash

# generate_keys.sh - Generate validator keys for test network nodes

set -e

NUM_NODES=${1:-3}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODES_DIR="$SCRIPT_DIR/../nodes"

# Function to generate Ed25519 keypair using OpenSSL
generate_ed25519_key() {
    local node_id=$1
    local node_dir="$NODES_DIR/node$node_id"
    
    mkdir -p "$node_dir/malachite/config"
    
    # Generate private key
    openssl genpkey -algorithm ED25519 -out "$node_dir/malachite/config/priv_key.pem" 2>/dev/null
    
    # Extract raw private key (32 bytes)
    openssl pkey -in "$node_dir/malachite/config/priv_key.pem" -text -noout | \
        grep -A 3 "priv:" | tail -n 3 | tr -d ' \n:' > "$node_dir/malachite/config/priv_key_hex.txt"
    
    # Extract public key
    openssl pkey -in "$node_dir/malachite/config/priv_key.pem" -pubout -out "$node_dir/malachite/config/pub_key.pem"
    
    # Extract raw public key (32 bytes)
    openssl pkey -pubin -in "$node_dir/malachite/config/pub_key.pem" -text -noout | \
        grep -A 3 "pub:" | tail -n 3 | tr -d ' \n:' > "$node_dir/malachite/config/pub_key_hex.txt"
    
    # Generate validator key JSON
    local priv_key_hex=$(cat "$node_dir/malachite/config/priv_key_hex.txt")
    local pub_key_hex=$(cat "$node_dir/malachite/config/pub_key_hex.txt")
    
    # Create priv_validator_key.json
    cat > "$node_dir/malachite/config/priv_validator_key.json" <<EOF
{
  "address": "$(echo -n $pub_key_hex | cut -c1-40)",
  "pub_key": {
    "type": "tendermint/PubKeyEd25519",
    "value": "$(echo -n $pub_key_hex | xxd -r -p | base64 -w 0)"
  },
  "priv_key": {
    "type": "tendermint/PrivKeyEd25519",
    "value": "$(echo -n ${priv_key_hex}${pub_key_hex} | xxd -r -p | base64 -w 0)"
  }
}
EOF
    
    # Generate node ID (first 20 bytes of SHA256 of public key)
    local node_id_hex=$(echo -n $pub_key_hex | xxd -r -p | sha256sum | cut -c1-40)
    echo $node_id_hex > "$node_dir/malachite/config/node_id.txt"
    
    # Clean up temporary files
    rm -f "$node_dir/malachite/config/priv_key.pem" "$node_dir/malachite/config/pub_key.pem"
    rm -f "$node_dir/malachite/config/priv_key_hex.txt" "$node_dir/malachite/config/pub_key_hex.txt"
}

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo "Error: openssl is required but not installed"
    exit 1
fi

# Check if xxd is available
if ! command -v xxd &> /dev/null; then
    echo "Error: xxd is required but not installed"
    exit 1
fi

echo "Generating keys for $NUM_NODES nodes..."

# Create nodes directory
mkdir -p "$NODES_DIR"

# Generate keys for each node
for ((i=0; i<$NUM_NODES; i++)); do
    echo "Generating keys for node$i..."
    generate_ed25519_key $i
done

echo "Key generation complete"