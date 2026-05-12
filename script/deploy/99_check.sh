#!/bin/bash

echo "========================================="
echo "Verifying GroupChat Configuration"
echo "========================================="

if [ -n "$network_dir" ] && [ -f "$network_dir/address.group.chat.params" ] && { \
    [ -z "$groupChatAddress" ] || \
    [ -z "$adminDenySourceAddress" ] || \
    [ -z "$groupChatDenySourceAddress" ] || \
    [ -z "$groupJoinScopeSourceAddress" ] || \
    [ -z "$tokenGroupChatManagerAddress" ] || \
    [ -z "$tokenGovGroupChatManagerAddress" ] || \
    [ -z "$tokenActionGovGroupChatManagerAddress" ] || \
    [ -z "$tokenActionGroupChatManagerAddress" ]; \
}; then
    source "$network_dir/address.group.chat.params"
fi

if [ -n "$network_dir" ] && [ -f "$network_dir/address.group.params" ]; then
    source "$network_dir/address.group.params"
fi

if [ -n "$network_dir" ] && [ -f "$network_dir/address.group.defaults.params" ]; then
    source "$network_dir/address.group.defaults.params"
fi

if [ -n "$network_dir" ] && [ -f "$network_dir/group.chat.params" ]; then
    source "$network_dir/group.chat.params"
else
    echo -e "\033[31mError:\033[0m group.chat.params not found; run 00_init.sh <network> before 99_check.sh"
    return 1
fi

if [ -n "$groupAddress" ]; then
    LOVE20_GROUP_ADDRESS=$groupAddress
    export LOVE20_GROUP_ADDRESS
fi

if [ -n "$groupDefaultsAddress" ]; then
    GROUP_DEFAULTS_ADDRESS=$groupDefaultsAddress
    export GROUP_DEFAULTS_ADDRESS
fi

if [ -n "$extensionCenterAddress" ]; then
    EXTENSION_CENTER_ADDRESS=$extensionCenterAddress
    export EXTENSION_CENTER_ADDRESS
fi

if [ -n "$groupJoinAddress" ]; then
    GROUP_JOIN_ADDRESS=$groupJoinAddress
    export GROUP_JOIN_ADDRESS
fi

if [ -n "$groupChatDenySourceAddress" ]; then
    GROUP_CHAT_DENY_SOURCE_ADDRESS=$groupChatDenySourceAddress
    export GROUP_CHAT_DENY_SOURCE_ADDRESS
fi

if [ -n "$groupJoinScopeSourceAddress" ]; then
    GROUP_JOIN_SCOPE_SOURCE_ADDRESS=$groupJoinScopeSourceAddress
    export GROUP_JOIN_SCOPE_SOURCE_ADDRESS
fi

if [ -n "$adminDenySourceAddress" ]; then
    ADMIN_DENY_SOURCE_ADDRESS=$adminDenySourceAddress
    export ADMIN_DENY_SOURCE_ADDRESS
fi

if [ -n "$groupChatBeforePostPluginAddress" ]; then
    GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS=$groupChatBeforePostPluginAddress
    export GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS
fi

if [ -n "$groupChatAfterPostPluginAddress" ]; then
    GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS=$groupChatAfterPostPluginAddress
    export GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS
fi

if [ -n "$actionRecentRounds" ]; then
    GROUP_CHAT_ACTION_RECENT_ROUNDS=$actionRecentRounds
    export GROUP_CHAT_ACTION_RECENT_ROUNDS
fi

if [ -n "$denyThresholdBps" ]; then
    GROUP_CHAT_DENY_THRESHOLD_BPS=$denyThresholdBps
    export GROUP_CHAT_DENY_THRESHOLD_BPS
fi

zero_address=0x0000000000000000000000000000000000000000

if [ -z "$GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS" ]; then
    GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS=$zero_address
    export GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS
fi

if [ -z "$GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS" ]; then
    GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS=$zero_address
    export GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS
fi

if [ -z "$GROUP_CHAT_DENY_THRESHOLD_BPS" ]; then
    GROUP_CHAT_DENY_THRESHOLD_BPS=30
    export GROUP_CHAT_DENY_THRESHOLD_BPS
fi

if [ -z "$groupChatAddress" ]; then
    echo -e "\033[31mError:\033[0m GroupChat address not set"
    return 1
fi

echo "Validating initialization parameters..."
missing_params=0

if [ -z "$GROUP_DEFAULTS_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m GROUP_DEFAULTS_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$EXTENSION_CENTER_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m EXTENSION_CENTER_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$GROUP_CHAT_ACTION_RECENT_ROUNDS" ]; then
    echo -e "\033[31m✗\033[0m GROUP_CHAT_ACTION_RECENT_ROUNDS not set"
    ((missing_params++))
fi

if [ -n "$GROUP_CHAT_ACTION_RECENT_ROUNDS" ] && [ "$GROUP_CHAT_ACTION_RECENT_ROUNDS" = "0" ]; then
    echo -e "\033[31m✗\033[0m GROUP_CHAT_ACTION_RECENT_ROUNDS must be greater than zero"
    ((missing_params++))
fi

if [ -z "$GROUP_CHAT_DENY_SOURCE_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m GROUP_CHAT_DENY_SOURCE_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$GROUP_JOIN_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m GROUP_JOIN_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$GROUP_JOIN_SCOPE_SOURCE_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m GROUP_JOIN_SCOPE_SOURCE_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$ADMIN_DENY_SOURCE_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m ADMIN_DENY_SOURCE_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$tokenGroupChatManagerAddress" ]; then
    echo -e "\033[31m✗\033[0m tokenGroupChatManagerAddress not set"
    ((missing_params++))
fi

if [ -z "$tokenGovGroupChatManagerAddress" ]; then
    echo -e "\033[31m✗\033[0m tokenGovGroupChatManagerAddress not set"
    ((missing_params++))
fi

if [ -z "$tokenActionGovGroupChatManagerAddress" ]; then
    echo -e "\033[31m✗\033[0m tokenActionGovGroupChatManagerAddress not set"
    ((missing_params++))
fi

if [ -z "$tokenActionGroupChatManagerAddress" ]; then
    echo -e "\033[31m✗\033[0m tokenActionGroupChatManagerAddress not set"
    ((missing_params++))
fi

if [ $missing_params -gt 0 ]; then
    echo -e "\033[31mError:\033[0m $missing_params initialization parameter(s) missing"
    echo "Please ensure all parameters are loaded from group.chat.params / address.group.params / address.group.defaults.params / address.group.chat.params"
    return 1
fi

echo -e "\033[32m✓\033[0m All initialization parameters are set"
echo ""

echo -e "GroupChat Address: $groupChatAddress\n"
echo -e "AdminDenySource Address: $ADMIN_DENY_SOURCE_ADDRESS"
echo -e "GovVotedDenySource Address: $GROUP_CHAT_DENY_SOURCE_ADDRESS\n"
echo -e "GroupJoinScopeSource Address: $GROUP_JOIN_SCOPE_SOURCE_ADDRESS"
echo -e "GroupJoin Address: $GROUP_JOIN_ADDRESS\n"
echo -e "Deny Threshold Bps: $GROUP_CHAT_DENY_THRESHOLD_BPS\n"
echo -e "TokenGroupChatManager Address: $tokenGroupChatManagerAddress"
echo -e "TokenGovGroupChatManager Address: $tokenGovGroupChatManagerAddress"
echo -e "TokenActionGovGroupChatManager Address: $tokenActionGovGroupChatManagerAddress"
echo -e "TokenActionGroupChatManager Address: $tokenActionGroupChatManagerAddress\n"

failed_checks=0

center_stake_address=$(cast_call $EXTENSION_CENTER_ADDRESS "stakeAddress()(address)")
center_join_address=$(cast_call $EXTENSION_CENTER_ADDRESS "joinAddress()(address)")
center_vote_address=$(cast_call $EXTENSION_CENTER_ADDRESS "voteAddress()(address)")

echo "Verifying initialization parameters match contract values..."

defaults_group_address=$(cast_call $GROUP_DEFAULTS_ADDRESS "GROUP_ADDRESS()(address)")
if [ -n "$LOVE20_GROUP_ADDRESS" ]; then
    check_equal "GroupDefaults: GROUP_ADDRESS" $LOVE20_GROUP_ADDRESS $defaults_group_address
    [ $? -ne 0 ] && ((failed_checks++))
    echo ""
else
    LOVE20_GROUP_ADDRESS=$defaults_group_address
    export LOVE20_GROUP_ADDRESS
fi

check_equal "GroupChat: LOVE20_GROUP_ADDRESS" $defaults_group_address $(cast_call $groupChatAddress "LOVE20_GROUP_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_equal "GroupChat: GROUP_DEFAULTS_ADDRESS" $GROUP_DEFAULTS_ADDRESS $(cast_call $groupChatAddress "GROUP_DEFAULTS_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

group_chat_origin_blocks=$(cast_call $groupChatAddress "originBlocks()(uint256)")
group_chat_phase_blocks=$(cast_call $groupChatAddress "phaseBlocks()(uint256)")
core_join_origin_blocks=$(cast_call $center_join_address "originBlocks()(uint256)")
core_join_phase_blocks=$(cast_call $center_join_address "phaseBlocks()(uint256)")

check_equal "GroupChat: originBlocks matches core Join" $core_join_origin_blocks $group_chat_origin_blocks
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_equal "GroupChat: phaseBlocks matches core Join" $core_join_phase_blocks $group_chat_phase_blocks
[ $? -ne 0 ] && ((failed_checks++))
echo ""

actual_max_content=$(cast_call $groupChatAddress "MAX_CONTENT_LENGTH()(uint256)")
echo -e "\033[32m✓\033[0m GroupChat: MAX_CONTENT_LENGTH"
echo -e "  Actual: $actual_max_content"
echo ""

actual_round=$(cast_call $groupChatAddress "currentRound()(uint256)" 2>/dev/null)
if [ -n "$actual_round" ]; then
    echo -e "\033[32m✓\033[0m GroupChat: currentRound"
    echo -e "  Actual: $actual_round"
    join_round=$(cast_call $center_join_address "currentRound()(uint256)" 2>/dev/null)
    if [ -n "$join_round" ]; then
        check_equal "GroupChat: currentRound matches core Join" $join_round $actual_round
        [ $? -ne 0 ] && ((failed_checks++))
    fi
else
    echo -e "\033[33m!\033[0m GroupChat: currentRound"
    echo -e "  Current block is before originBlocks, skip round value check"
fi
echo ""

echo "Verifying AdminDenySource configuration..."
check_equal "AdminDenySource: GROUP_CHAT_ADDRESS" $groupChatAddress $(cast_call $ADMIN_DENY_SOURCE_ADDRESS "GROUP_CHAT_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "AdminDenySource: GROUP_DEFAULTS_ADDRESS" $GROUP_DEFAULTS_ADDRESS $(cast_call $ADMIN_DENY_SOURCE_ADDRESS "GROUP_DEFAULTS_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "AdminDenySource: LOVE20_GROUP_ADDRESS" $LOVE20_GROUP_ADDRESS $(cast_call $ADMIN_DENY_SOURCE_ADDRESS "LOVE20_GROUP_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

echo "Verifying GovVotedDenySource configuration..."
check_equal "GovVotedDenySource: GROUP_ADDRESS" $LOVE20_GROUP_ADDRESS $(cast_call $GROUP_CHAT_DENY_SOURCE_ADDRESS "GROUP_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "GovVotedDenySource: GROUP_DEFAULTS_ADDRESS" $GROUP_DEFAULTS_ADDRESS $(cast_call $GROUP_CHAT_DENY_SOURCE_ADDRESS "GROUP_DEFAULTS_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "GovVotedDenySource: DENY_THRESHOLD_BPS" $GROUP_CHAT_DENY_THRESHOLD_BPS $(cast_call $GROUP_CHAT_DENY_SOURCE_ADDRESS "DENY_THRESHOLD_BPS()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

echo "Verifying GroupJoinScopeSource configuration..."
check_equal "GroupJoinScopeSource: GROUP_JOIN_ADDRESS" $GROUP_JOIN_ADDRESS $(cast_call $GROUP_JOIN_SCOPE_SOURCE_ADDRESS "GROUP_JOIN_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

echo "Verifying ExtensionCenter values used by managers..."

echo -e "\033[32m✓\033[0m ExtensionCenter: dependency addresses loaded"
echo -e "  STAKE_ADDRESS:  $center_stake_address"
echo -e "  JOIN_ADDRESS:   $center_join_address"
echo -e "  VOTE_ADDRESS:   $center_vote_address"
echo ""

check_manager_common() {
    local manager_name=$1
    local manager_address=$2

    check_equal "$manager_name: GROUP_CHAT_ADDRESS" $groupChatAddress $(cast_call $manager_address "GROUP_CHAT_ADDRESS()(address)")
    [ $? -ne 0 ] && ((failed_checks++))

    check_equal "$manager_name: DENY_SOURCE_ADDRESS" $GROUP_CHAT_DENY_SOURCE_ADDRESS $(cast_call $manager_address "DENY_SOURCE_ADDRESS()(address)")
    [ $? -ne 0 ] && ((failed_checks++))

    check_equal "$manager_name: BEFORE_POST_PLUGIN_ADDRESS" $GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS $(cast_call $manager_address "BEFORE_POST_PLUGIN_ADDRESS()(address)")
    [ $? -ne 0 ] && ((failed_checks++))

    check_equal "$manager_name: AFTER_POST_PLUGIN_ADDRESS" $GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS $(cast_call $manager_address "AFTER_POST_PLUGIN_ADDRESS()(address)")
    [ $? -ne 0 ] && ((failed_checks++))

    check_equal "$manager_name: EXTENSION_CENTER_ADDRESS" $EXTENSION_CENTER_ADDRESS $(cast_call $manager_address "EXTENSION_CENTER_ADDRESS()(address)")
    [ $? -ne 0 ] && ((failed_checks++))
}

echo "Verifying manager immutable configuration..."

check_manager_common "TokenGroupChatManager" $tokenGroupChatManagerAddress
check_equal "TokenGroupChatManager: STAKE_ADDRESS" $center_stake_address $(cast_call $tokenGroupChatManagerAddress "STAKE_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenGroupChatManager: LAUNCH_ADDRESS" $(cast_call $EXTENSION_CENTER_ADDRESS "launchAddress()(address)") $(cast_call $tokenGroupChatManagerAddress "LAUNCH_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenGroupChatManager: JOIN_ADDRESS" $center_join_address $(cast_call $tokenGroupChatManagerAddress "JOIN_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenGroupChatManager: VOTE_ADDRESS" $center_vote_address $(cast_call $tokenGroupChatManagerAddress "VOTE_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_manager_common "TokenGovGroupChatManager" $tokenGovGroupChatManagerAddress
check_equal "TokenGovGroupChatManager: STAKE_ADDRESS" $center_stake_address $(cast_call $tokenGovGroupChatManagerAddress "STAKE_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenGovGroupChatManager: LAUNCH_ADDRESS" $(cast_call $EXTENSION_CENTER_ADDRESS "launchAddress()(address)") $(cast_call $tokenGovGroupChatManagerAddress "LAUNCH_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_manager_common "TokenActionGovGroupChatManager" $tokenActionGovGroupChatManagerAddress
check_equal "TokenActionGovGroupChatManager: STAKE_ADDRESS" $center_stake_address $(cast_call $tokenActionGovGroupChatManagerAddress "STAKE_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenActionGovGroupChatManager: LAUNCH_ADDRESS" $(cast_call $EXTENSION_CENTER_ADDRESS "launchAddress()(address)") $(cast_call $tokenActionGovGroupChatManagerAddress "LAUNCH_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenActionGovGroupChatManager: VOTE_ADDRESS" $center_vote_address $(cast_call $tokenActionGovGroupChatManagerAddress "VOTE_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenActionGovGroupChatManager: RECENT_ROUNDS" $GROUP_CHAT_ACTION_RECENT_ROUNDS $(cast_call $tokenActionGovGroupChatManagerAddress "RECENT_ROUNDS()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_manager_common "TokenActionGroupChatManager" $tokenActionGroupChatManagerAddress
check_equal "TokenActionGroupChatManager: STAKE_ADDRESS" $center_stake_address $(cast_call $tokenActionGroupChatManagerAddress "STAKE_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenActionGroupChatManager: LAUNCH_ADDRESS" $(cast_call $EXTENSION_CENTER_ADDRESS "launchAddress()(address)") $(cast_call $tokenActionGroupChatManagerAddress "LAUNCH_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenActionGroupChatManager: VOTE_ADDRESS" $center_vote_address $(cast_call $tokenActionGroupChatManagerAddress "VOTE_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenActionGroupChatManager: JOIN_ADDRESS" $center_join_address $(cast_call $tokenActionGroupChatManagerAddress "JOIN_ADDRESS()(address)")
[ $? -ne 0 ] && ((failed_checks++))
check_equal "TokenActionGroupChatManager: RECENT_ROUNDS" $GROUP_CHAT_ACTION_RECENT_ROUNDS $(cast_call $tokenActionGroupChatManagerAddress "RECENT_ROUNDS()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All parameter checks passed\033[0m"
    echo "========================================="
    return 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1
fi
