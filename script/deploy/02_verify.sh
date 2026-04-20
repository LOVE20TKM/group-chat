#!/bin/bash

if [[ "$network" != thinkium70001* ]]; then
  echo "Network is not thinkium70001 related, skipping verification"
  return 0
fi

if [ -z "$RPC_URL" ]; then
    source 00_init.sh $network
fi

if [ -z "$groupChatAddress" ]; then
    source $network_dir/address.group.chat.params
fi

verify_contract(){
  local contract_address=$1
  local contract_name=$2
  local contract_path=$3
  shift 3
  local ctor_args="$@"

  echo "Verifying contract: $contract_name at $contract_address"

  forge verify-contract \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL \
    --constructor-args "$ctor_args" \
    $contract_address \
    $contract_path:$contract_name

  if [ $? -eq 0 ]; then
    echo -e "\033[32m✓\033[0m Contract $contract_name verified successfully"
    return 0
  else
    echo -e "\033[31m✗\033[0m Failed to verify contract $contract_name"
    return 1
  fi
}
echo "verify_contract() loaded"

constructor_args=$(cast abi-encode "constructor(address,uint256,uint256)" \
    $LOVE20_GROUP_ADDRESS \
    $ORIGIN_BLOCKS \
    $PHASE_BLOCKS)

verify_contract $groupChatAddress "GroupChat" "src/GroupChat.sol" $constructor_args
