#!/bin/bash

if [ -z "$network" ]; then
  echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
  return 1
fi

if [[ "$network" != thinkium70001* ]]; then
  echo "Network is not thinkium70001 related, skipping verification"
  return 0
fi

if [ -z "$RPC_URL" ]; then
    source 00_init.sh $network
fi

if [ -z "$groupChatAddress" ] || [ -z "$tokenGroupChatManagerAddress" ]; then
    source $network_dir/address.group.chat.params
fi

if [ -z "$GROUP_JOIN_ADDRESS" ] && [ -n "$groupJoinAddress" ]; then
    GROUP_JOIN_ADDRESS=$groupJoinAddress
    export GROUP_JOIN_ADDRESS
fi

if [ -z "$GROUP_JOIN_SCOPE_SOURCE_ADDRESS" ] && [ -n "$groupJoinScopeSourceAddress" ]; then
    GROUP_JOIN_SCOPE_SOURCE_ADDRESS=$groupJoinScopeSourceAddress
    export GROUP_JOIN_SCOPE_SOURCE_ADDRESS
fi

if [ -z "$LOVE20_GROUP_ADDRESS" ]; then
    LOVE20_GROUP_ADDRESS=$(cast call "$GROUP_DEFAULTS_ADDRESS" "GROUP_ADDRESS()(address)" --rpc-url "$RPC_URL")
    export LOVE20_GROUP_ADDRESS
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
    $GROUP_DEFAULTS_ADDRESS \
    $ORIGIN_BLOCKS \
    $PHASE_BLOCKS)

failed_verifications=0

verify_contract $groupChatAddress "GroupChat" "src/GroupChat.sol" $constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

admin_deny_source_constructor_args=$(cast abi-encode "constructor(address)" $groupChatAddress)
verify_contract \
    $adminDenySourceAddress \
    "AdminDenySource" \
    "src/sources/deny/AdminDenySource.sol" \
    $admin_deny_source_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

gov_deny_source_constructor_args=$(cast abi-encode "constructor(address,address)" \
    $LOVE20_GROUP_ADDRESS \
    $GROUP_DEFAULTS_ADDRESS)
verify_contract \
    $groupChatDenySourceAddress \
    "GovVotedDenySource" \
    "src/sources/deny/GovVotedDenySource.sol" \
    $gov_deny_source_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

group_join_scope_source_constructor_args=$(cast abi-encode "constructor(address)" $GROUP_JOIN_ADDRESS)
verify_contract \
    $groupJoinScopeSourceAddress \
    "GroupJoinScopeSource" \
    "src/sources/scope/GroupJoinScopeSource.sol" \
    $group_join_scope_source_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address)" \
    $groupChatAddress \
    $GROUP_CHAT_DENY_SOURCE_ADDRESS \
    $GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS \
    $GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS \
    $EXTENSION_CENTER_ADDRESS)

verify_contract \
    $tokenGroupChatManagerAddress \
    "TokenGroupChatManager" \
    "src/managers/TokenGroupChatManager.sol" \
    $manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    $tokenGovGroupChatManagerAddress \
    "TokenGovGroupChatManager" \
    "src/managers/TokenGovGroupChatManager.sol" \
    $manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    $tokenActionGovGroupChatManagerAddress \
    "TokenActionGovGroupChatManager" \
    "src/managers/TokenActionGovGroupChatManager.sol" \
    $manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    $tokenActionGroupChatManagerAddress \
    "TokenActionGroupChatManager" \
    "src/managers/TokenActionGroupChatManager.sol" \
    $manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

if [ $failed_verifications -gt 0 ]; then
    return 1
fi
