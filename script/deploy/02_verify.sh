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

if [ -f "$network_dir/address.group.chat.params" ] && { \
    [ -z "$groupChatAddress" ] || \
    [ -z "$adminDenySourceAddress" ] || \
    [ -z "$groupChatDenySourceAddress" ] || \
    [ -z "$groupJoinScopeSourceAddress" ] || \
    [ -z "$tokenMainManagerAddress" ] || \
    [ -z "$tokenGovManagerAddress" ] || \
    [ -z "$tokenActionGovManagerAddress" ] || \
    [ -z "$tokenActionMainManagerAddress" ]; \
}; then
    source "$network_dir/address.group.chat.params"
fi

if [ -z "$GROUP_JOIN_ADDRESS" ] && [ -n "$groupJoinAddress" ]; then
    GROUP_JOIN_ADDRESS=$groupJoinAddress
    export GROUP_JOIN_ADDRESS
fi

if [ -z "$GROUP_JOIN_SCOPE_SOURCE_ADDRESS" ] && [ -n "$groupJoinScopeSourceAddress" ]; then
    GROUP_JOIN_SCOPE_SOURCE_ADDRESS=$groupJoinScopeSourceAddress
    export GROUP_JOIN_SCOPE_SOURCE_ADDRESS
fi

if [ -z "$GROUP_CHAT_DENY_SOURCE_ADDRESS" ] && [ -n "$groupChatDenySourceAddress" ]; then
    GROUP_CHAT_DENY_SOURCE_ADDRESS=$groupChatDenySourceAddress
    export GROUP_CHAT_DENY_SOURCE_ADDRESS
fi

if [ -z "$ADMIN_DENY_SOURCE_ADDRESS" ] && [ -n "$adminDenySourceAddress" ]; then
    ADMIN_DENY_SOURCE_ADDRESS=$adminDenySourceAddress
    export ADMIN_DENY_SOURCE_ADDRESS
fi

if [ -z "$GROUP_ADDRESS" ]; then
    GROUP_ADDRESS=$(cast call "$GROUP_DEFAULTS_ADDRESS" "GROUP_ADDRESS()(address)" --rpc-url "$RPC_URL")
    export GROUP_ADDRESS
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

group_chat_origin_blocks=$(cast call "$groupChatAddress" "originBlocks()(uint256)" --rpc-url "$RPC_URL")
group_chat_phase_blocks=$(cast call "$groupChatAddress" "phaseBlocks()(uint256)" --rpc-url "$RPC_URL")

constructor_args=$(cast abi-encode "constructor(address,uint256,uint256)" \
    $GROUP_DEFAULTS_ADDRESS \
    $group_chat_origin_blocks \
    $group_chat_phase_blocks)

failed_verifications=0

verify_contract $groupChatAddress "GroupChat" "src/GroupChat.sol" $constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

if [ -z "$GROUP_CHAT_MAX_ADMIN_IDS" ]; then
    GROUP_CHAT_MAX_ADMIN_IDS=20
fi

admin_deny_source_constructor_args=$(cast abi-encode "constructor(address,uint256)" \
    $groupChatAddress \
    $GROUP_CHAT_MAX_ADMIN_IDS)
verify_contract \
    $adminDenySourceAddress \
    "AdminDenySource" \
    "src/sources/deny/AdminDenySource.sol" \
    $admin_deny_source_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

if [ -z "$GROUP_CHAT_DENY_THRESHOLD_RATIO" ]; then
    GROUP_CHAT_DENY_THRESHOLD_RATIO=3000000000000000
fi

gov_deny_source_constructor_args=$(cast abi-encode "constructor(address,uint256)" \
    $GROUP_ADDRESS \
    $GROUP_CHAT_DENY_THRESHOLD_RATIO)
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

token_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address)" \
    $groupChatAddress \
    $GROUP_CHAT_DENY_SOURCE_ADDRESS \
    $GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS \
    $GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS \
    $EXTENSION_CENTER_ADDRESS)

token_gov_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address)" \
    $groupChatAddress \
    $GROUP_CHAT_DENY_SOURCE_ADDRESS \
    $GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS \
    $GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS \
    $EXTENSION_CENTER_ADDRESS)

token_action_gov_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address,uint256)" \
    $groupChatAddress \
    $GROUP_CHAT_DENY_SOURCE_ADDRESS \
    $GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS \
    $GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS \
    $EXTENSION_CENTER_ADDRESS \
    $GROUP_CHAT_ACTION_RECENT_ROUNDS)

token_action_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address,uint256)" \
    $groupChatAddress \
    $GROUP_CHAT_DENY_SOURCE_ADDRESS \
    $GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS \
    $GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS \
    $EXTENSION_CENTER_ADDRESS \
    $GROUP_CHAT_ACTION_RECENT_ROUNDS)

verify_contract \
    $tokenMainManagerAddress \
    "TokenMainManager" \
    "src/managers/TokenMainManager.sol" \
    $token_manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    $tokenGovManagerAddress \
    "TokenGovManager" \
    "src/managers/TokenGovManager.sol" \
    $token_gov_manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    $tokenActionGovManagerAddress \
    "TokenActionGovManager" \
    "src/managers/TokenActionGovManager.sol" \
    $token_action_gov_manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    $tokenActionMainManagerAddress \
    "TokenActionMainManager" \
    "src/managers/TokenActionMainManager.sol" \
    $token_action_manager_constructor_args
[ $? -ne 0 ] && ((failed_verifications++))

if [ $failed_verifications -gt 0 ]; then
    return 1
fi
