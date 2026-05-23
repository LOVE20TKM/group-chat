#!/bin/bash

source ./lib.sh || return 1

if [ -z "$network" ]; then
  echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
  return 1
fi

if [[ "$network" != thinkium70001* ]]; then
  echo "Network is not thinkium70001 related, skipping verification"
  return 0
fi

if [ -z "$RPC_URL" ]; then
    source 00_init.sh "$network" || return 1
fi

if [ -f "$network_dir/address.group.chat.params" ] && { \
	    [ -z "$groupChatAddress" ] || \
	    [ -z "$groupAdminAddress" ] || \
	    [ -z "$groupBanListAddress" ] || \
	    [ -z "$adminBanSourceAddress" ] || \
    [ -z "$govVotedBanSourceAddress" ] || \
    [ -z "$groupMemberAddress" ] || \
    [ -z "$groupMemberScopeAddress" ] || \
    [ -z "$groupJoinScopeSourceAddress" ] || \
    [ -z "$tokenMainManagerAddress" ] || \
    [ -z "$tokenGovManagerAddress" ] || \
    [ -z "$tokenActionGovManagerAddress" ] || \
    [ -z "$tokenActionMainManagerAddress" ]; \
}; then
    load_env_file "$network_dir/address.group.chat.params" || return 1
fi

if [ -z "$GROUP_JOIN_ADDRESS" ] && [ -n "$groupJoinAddress" ]; then
    GROUP_JOIN_ADDRESS=$groupJoinAddress
    export GROUP_JOIN_ADDRESS
fi

if [ -z "$GROUP_DELEGATE_ADDRESS" ] && [ -n "$groupDelegateAddress" ]; then
    GROUP_DELEGATE_ADDRESS=$groupDelegateAddress
    export GROUP_DELEGATE_ADDRESS
fi

if [ -z "$GROUP_ADMIN_ADDRESS" ] && [ -n "$groupAdminAddress" ]; then
    GROUP_ADMIN_ADDRESS=$groupAdminAddress
    export GROUP_ADMIN_ADDRESS
fi

if [ -z "$GROUP_BAN_LIST_ADDRESS" ] && [ -n "$groupBanListAddress" ]; then
    GROUP_BAN_LIST_ADDRESS=$groupBanListAddress
    export GROUP_BAN_LIST_ADDRESS
fi

if [ -z "$GROUP_MEMBER_ADDRESS" ] && [ -n "$groupMemberAddress" ]; then
    GROUP_MEMBER_ADDRESS=$groupMemberAddress
    export GROUP_MEMBER_ADDRESS
fi

if [ -z "$GROUP_MEMBER_SCOPE_ADDRESS" ] && [ -n "$groupMemberScopeAddress" ]; then
    GROUP_MEMBER_SCOPE_ADDRESS=$groupMemberScopeAddress
    export GROUP_MEMBER_SCOPE_ADDRESS
fi

if [ -z "$GROUP_JOIN_SCOPE_SOURCE_ADDRESS" ] && [ -n "$groupJoinScopeSourceAddress" ]; then
    GROUP_JOIN_SCOPE_SOURCE_ADDRESS=$groupJoinScopeSourceAddress
    export GROUP_JOIN_SCOPE_SOURCE_ADDRESS
fi

if [ -z "$ADMIN_BAN_SOURCE_ADDRESS" ] && [ -n "$adminBanSourceAddress" ]; then
    ADMIN_BAN_SOURCE_ADDRESS=$adminBanSourceAddress
    export ADMIN_BAN_SOURCE_ADDRESS
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
    --chain-id "$CHAIN_ID" \
    --verifier "$VERIFIER" \
    --verifier-url "$VERIFIER_URL" \
    --constructor-args "$ctor_args" \
    "$contract_address" \
    "$contract_path:$contract_name"

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
group_chat_origin_blocks=${group_chat_origin_blocks%% *}
group_chat_phase_blocks=$(cast call "$groupChatAddress" "phaseBlocks()(uint256)" --rpc-url "$RPC_URL")
group_chat_phase_blocks=${group_chat_phase_blocks%% *}

constructor_args=$(cast abi-encode "constructor(address,uint256,uint256)" \
    "$groupAdminAddress" \
    "$group_chat_origin_blocks" \
    "$group_chat_phase_blocks")

failed_verifications=0

verify_contract "$groupChatAddress" "GroupChat" "src/GroupChat.sol" "$constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

if [ -z "$GROUP_CHAT_MAX_ADMIN_IDS" ]; then
    GROUP_CHAT_MAX_ADMIN_IDS=20
fi

group_admin_constructor_args=$(cast abi-encode "constructor(address,address,uint256)" \
    "$GROUP_DEFAULTS_ADDRESS" \
    "$GROUP_DELEGATE_ADDRESS" \
    "$GROUP_CHAT_MAX_ADMIN_IDS")
verify_contract \
    "$groupAdminAddress" \
    "GroupAdmin" \
    "src/GroupAdmin.sol" \
    "$group_admin_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

group_ban_list_constructor_args=$(cast abi-encode "constructor(address)" \
    "$groupAdminAddress")
verify_contract \
    "$groupBanListAddress" \
    "GroupBanList" \
    "src/GroupBanList.sol" \
    "$group_ban_list_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

admin_ban_source_constructor_args=$(cast abi-encode "constructor(address)" \
    "$groupBanListAddress")
verify_contract \
    "$adminBanSourceAddress" \
    "AdminBanSource" \
    "src/sources/ban/AdminBanSource.sol" \
    "$admin_ban_source_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

if [ -z "$GROUP_CHAT_BAN_THRESHOLD_RATIO" ]; then
    GROUP_CHAT_BAN_THRESHOLD_RATIO=3000000000000000
fi

gov_ban_source_constructor_args=$(cast abi-encode "constructor(address,uint256)" \
    "$GROUP_ADDRESS" \
    "$GROUP_CHAT_BAN_THRESHOLD_RATIO")
verify_contract \
    "$govVotedBanSourceAddress" \
    "GovVotedBanSource" \
    "src/sources/ban/GovVotedBanSource.sol" \
    "$gov_ban_source_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

group_member_constructor_args=$(cast abi-encode "constructor(address)" "$groupAdminAddress")
verify_contract \
    "$groupMemberAddress" \
    "GroupMember" \
    "src/GroupMember.sol" \
    "$group_member_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

group_member_scope_constructor_args=$(cast abi-encode "constructor(address)" "$groupMemberAddress")
verify_contract \
    "$groupMemberScopeAddress" \
    "GroupMemberScope" \
    "src/sources/scope/GroupMemberScope.sol" \
    "$group_member_scope_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

group_join_scope_source_constructor_args=$(cast abi-encode "constructor(address,address)" \
    "$groupMemberAddress" \
    "$GROUP_JOIN_ADDRESS")
verify_contract \
    "$groupJoinScopeSourceAddress" \
    "GroupJoinScopeSource" \
    "src/sources/scope/GroupJoinScopeSource.sol" \
    "$group_join_scope_source_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

token_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address)" \
    "$groupChatAddress" \
    "$govVotedBanSourceAddress" \
    "$GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS" \
    "$GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS" \
    "$EXTENSION_CENTER_ADDRESS")

token_gov_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address)" \
    "$groupChatAddress" \
    "$govVotedBanSourceAddress" \
    "$GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS" \
    "$GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS" \
    "$EXTENSION_CENTER_ADDRESS")

token_action_gov_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address,uint256)" \
    "$groupChatAddress" \
    "$govVotedBanSourceAddress" \
    "$GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS" \
    "$GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS" \
    "$EXTENSION_CENTER_ADDRESS" \
    "$GROUP_CHAT_ACTION_RECENT_ROUNDS")

token_action_manager_constructor_args=$(cast abi-encode "constructor(address,address,address,address,address,uint256)" \
    "$groupChatAddress" \
    "$govVotedBanSourceAddress" \
    "$GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS" \
    "$GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS" \
    "$EXTENSION_CENTER_ADDRESS" \
    "$GROUP_CHAT_ACTION_RECENT_ROUNDS")

verify_contract \
    "$tokenMainManagerAddress" \
    "TokenMainManager" \
    "src/managers/TokenMainManager.sol" \
    "$token_manager_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    "$tokenGovManagerAddress" \
    "TokenGovManager" \
    "src/managers/TokenGovManager.sol" \
    "$token_gov_manager_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    "$tokenActionGovManagerAddress" \
    "TokenActionGovManager" \
    "src/managers/TokenActionGovManager.sol" \
    "$token_action_gov_manager_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

verify_contract \
    "$tokenActionMainManagerAddress" \
    "TokenActionMainManager" \
    "src/managers/TokenActionMainManager.sol" \
    "$token_action_manager_constructor_args"
[ $? -ne 0 ] && ((failed_verifications++))

if [ $failed_verifications -gt 0 ]; then
    return 1
fi
