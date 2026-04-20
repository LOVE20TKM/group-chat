# ------ set network ------
export network=$1
if [ -z "$network" ] || [ ! -d "../network/$network" ]; then
    echo -e "\033[31mError:\033[0m Network parameter is required."
    echo -e "\nAvailable networks:"
    for net in $(ls ../network); do
        echo "  - $net"
    done
    return 1
fi

echo -e "Selected network: \033[36m$network\033[0m"

# ------ dont change below ------
network_dir="../network/$network"

if [ ! -f "$network_dir/.account" ]; then
    echo -e "\033[31mError:\033[0m .account file not found"
    echo -e "Please create $network_dir/.account with KEYSTORE_ACCOUNT and ACCOUNT_ADDRESS"
    echo -e "You can start from $network_dir/.account.example"
    return 1
fi
source $network_dir/.account && \
source $network_dir/network.params

if [ -f "$network_dir/address.group.params" ]; then
    source $network_dir/address.group.params
fi

if [ -f "$network_dir/group.chat.params" ]; then
    source $network_dir/group.chat.params

    if [ -n "$groupAddress" ]; then
        export LOVE20_GROUP_ADDRESS=$groupAddress
    fi

    if [ -z "$LOVE20_GROUP_ADDRESS" ]; then
        echo -e "\033[31mError:\033[0m LOVE20_GROUP_ADDRESS not set"
        echo -e "Please provide groupAddress in $network_dir/address.group.params"
        return 1
    fi

    export LOVE20_GROUP_ADDRESS
    export ORIGIN_BLOCKS
    export PHASE_BLOCKS

    echo "GroupChat Configuration loaded:"
    echo "  LOVE20 Group: $LOVE20_GROUP_ADDRESS"
    echo "  ORIGIN_BLOCKS: $ORIGIN_BLOCKS"
    echo "  PHASE_BLOCKS: $PHASE_BLOCKS"
else
    echo -e "\033[31mError:\033[0m group.chat.params not found"
    echo -e "Please create $network_dir/group.chat.params"
    return 1
fi

if [ -z "$KEYSTORE_PASSWORD" ]; then
    echo -e "\nPlease enter keystore password (for $KEYSTORE_ACCOUNT):"
    read -s KEYSTORE_PASSWORD
    export KEYSTORE_PASSWORD
    echo "Password saved, will not be requested again in this session"
else
    echo -e "\nUsing KEYSTORE_PASSWORD from environment"
fi

cast_call() {
    local address=$1
    local function_signature=$2
    shift 2
    local args=("$@")

    cast call "$address" \
        "$function_signature" \
        "${args[@]}" \
        --rpc-url "$RPC_URL"
}
echo "cast_call() loaded"

check_equal() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    expected=$(echo "$expected" | tr '[:upper:]' '[:lower:]')
    actual=$(echo "$actual" | tr '[:upper:]' '[:lower:]')

    if [ "$expected" = "$actual" ]; then
        echo -e "\033[32m✓\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 0
    else
        echo -e "\033[31m✗\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 1
    fi
}
echo "check_equal() loaded"

forge_script() {
  forge script "$@" \
    --rpc-url $RPC_URL \
    --account $KEYSTORE_ACCOUNT \
    --sender $ACCOUNT_ADDRESS \
    --password "$KEYSTORE_PASSWORD" \
    --gas-price 5000000000 \
    --gas-limit 50000000 \
    --broadcast \
    --legacy \
    $([[ "$network" != "anvil" ]] && [[ "$network" != thinkium* ]] && echo "--verify --etherscan-api-key $ETHERSCAN_API_KEY")
}
echo "forge_script() loaded"
