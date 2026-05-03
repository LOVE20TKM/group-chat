#!/bin/bash

if [ -z "$RPC_URL" ]; then
    echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
    return 1
fi

echo "Deploying GroupChat contract..."

forge_script ../DeployGroupChat.s.sol:DeployGroupChat --sig "run()"

if [ $? -eq 0 ]; then
    source $network_dir/address.group.chat.params
    export ADMIN_DENY_SOURCE_ADDRESS=$adminDenySourceAddress
    export GROUP_CHAT_DENY_SOURCE_ADDRESS=$groupChatDenySourceAddress
    export GROUP_JOIN_SCOPE_SOURCE_ADDRESS=$groupJoinScopeSourceAddress
    export GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS=$groupChatBeforePostPluginAddress
    export GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS=$groupChatAfterPostPluginAddress
    export ORIGIN_BLOCKS=$originBlocks
    export PHASE_BLOCKS=$phaseBlocks
    echo -e "\033[32m✓\033[0m GroupChat deployed at: $groupChatAddress"
    echo -e "\033[32m✓\033[0m AdminDenySource deployed at: $adminDenySourceAddress"
    echo -e "\033[32m✓\033[0m GovVotedDenySource deployed at: $groupChatDenySourceAddress"
    echo -e "\033[32m✓\033[0m GroupJoinScopeSource deployed at: $groupJoinScopeSourceAddress"
    echo -e "\033[32m✓\033[0m TokenGroupChatManager deployed at: $tokenGroupChatManagerAddress"
    echo -e "\033[32m✓\033[0m TokenGovGroupChatManager deployed at: $tokenGovGroupChatManagerAddress"
    echo -e "\033[32m✓\033[0m TokenActionGovGroupChatManager deployed at: $tokenActionGovGroupChatManagerAddress"
    echo -e "\033[32m✓\033[0m TokenActionGroupChatManager deployed at: $tokenActionGroupChatManagerAddress"
    return 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy GroupChat"
    return 1
fi
